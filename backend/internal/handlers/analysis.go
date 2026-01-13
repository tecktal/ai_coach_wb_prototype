package handlers

import (
	"context"
	"encoding/json"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/worldbank/ai-coach/backend/internal/middleware"
	"github.com/worldbank/ai-coach/backend/internal/models"
	"github.com/worldbank/ai-coach/backend/internal/repository"
	"github.com/worldbank/ai-coach/backend/internal/services/gemini"
	"github.com/worldbank/ai-coach/backend/internal/services/storage"
)

type AnalysisHandler struct {
	repo    *repository.Repository
	gemini  *gemini.GeminiService
	storage *storage.S3Service
}

func NewAnalysisHandler(repo *repository.Repository, geminiSvc *gemini.GeminiService, storage *storage.S3Service) *AnalysisHandler {
	return &AnalysisHandler{
		repo:    repo,
		gemini:  geminiSvc,
		storage: storage,
	}
}

func (h *AnalysisHandler) Analyze(c *gin.Context) {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, models.ErrorResponse{Error: "Unauthorized"})
		return
	}

	recordingID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: "Invalid recording ID"})
		return
	}

	log.Printf("Starting analysis for recording: %s", recordingID)

	// Get recording
	recording, err := h.repo.GetRecordingByID(c.Request.Context(), recordingID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to get recording"})
		return
	}
	if recording == nil {
		c.JSON(http.StatusNotFound, models.ErrorResponse{Error: "Recording not found"})
		return
	}

	// Verify ownership
	if recording.UserID != userID {
		c.JSON(http.StatusForbidden, models.ErrorResponse{Error: "Access denied"})
		return
	}

	// Check if already analyzed
	existingAnalysis, err := h.repo.GetAnalysisByRecordingID(c.Request.Context(), recordingID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to check existing analysis"})
		return
	}
	if existingAnalysis != nil {
		c.JSON(http.StatusOK, existingAnalysis)
		return
	}

	// Update status to processing
	if err := h.repo.UpdateRecordingStatus(c.Request.Context(), recordingID, "processing"); err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to update status"})
		return
	}

	// Respond immediately to client
	c.JSON(http.StatusAccepted, gin.H{
		"message": "Analysis started in background",
		"recording_id": recordingID,
		"status": "processing",
	})

	// Run analysis in background
	go func() {
		// Use a background context as the request context will be cancelled
		ctx := context.Background()
		log.Printf("Background analysis started for recording: %s", recordingID)

		// Download audio file from S3 to temp location
		// Note: We need a fresh check of the file URL in case it changed, or pass it in. 
		// Using the 'recording' object from outer scope is safe for values.
		
		tmpFile, err := os.CreateTemp("", "recording-*."+filepath.Ext(recording.FileURL))
		if err != nil {
			log.Printf("Background: Failed to create temp file: %v", err)
			h.repo.UpdateRecordingStatus(ctx, recordingID, "failed")
			return
		}
		defer os.Remove(tmpFile.Name())
		defer tmpFile.Close()

		// Get presigned URL and download
		presignedURL, err := h.storage.GetPresignedURL(ctx, recording.FileURL, 15*time.Minute)
		if err != nil {
			log.Printf("Background: Failed to get presigned URL: %v", err)
			h.repo.UpdateRecordingStatus(ctx, recordingID, "failed")
			return
		}

		resp, err := http.Get(presignedURL)
		if err != nil {
			log.Printf("Background: Failed to download file from S3: %v", err)
			h.repo.UpdateRecordingStatus(ctx, recordingID, "failed")
			return
		}
		defer resp.Body.Close()

		if _, err := io.Copy(tmpFile, resp.Body); err != nil {
			log.Printf("Background: Failed to save temp file: %v", err)
			h.repo.UpdateRecordingStatus(ctx, recordingID, "failed")
			return
		}

		// Perform Gemini analysis
		startTime := time.Now()
		result, err := h.gemini.AnalyzeRecording(ctx, tmpFile.Name())
		if err != nil {
			log.Printf("Background: Gemini Analysis Failed: %v", err)
			h.repo.UpdateRecordingStatus(ctx, recordingID, "failed")
			return
		}
		if result == nil {
			log.Printf("Background: Gemini returned nil result")
			h.repo.UpdateRecordingStatus(ctx, recordingID, "failed")
			return
		}
		processingTime := int(time.Since(startTime).Milliseconds())

		// Save transcription
		segmentsJSON, _ := json.Marshal(result.Transcription.Segments)
		var segments models.JSONBArray
		json.Unmarshal(segmentsJSON, &segments)

		wordCount := len(result.Transcription.FullText) / 5
		transcription := &models.Transcription{
			RecordingID:      recordingID,
			FullText:         result.Transcription.FullText,
			Segments:         segments,
			WordCount:        &wordCount,
			ConfidenceScore:  &result.Confidence,
			LanguageDetected: &result.Transcription.LanguageDetected,
		}

		if err := h.repo.CreateTranscription(ctx, transcription); err != nil {
			log.Printf("Background: Failed to save transcription: %v", err)
			h.repo.UpdateRecordingStatus(ctx, recordingID, "failed")
			return
		}

		// Convert time on learning AND confidence factors to JSONB
        // We merge them into one map to persist all data without schema changes
        tolMap := make(map[string]interface{})
        
        // 1. Marshaling TimeOnLearning struct to map
        tolBytes, _ := json.Marshal(result.TimeOnLearning)
        json.Unmarshal(tolBytes, &tolMap)
        
        // 2. Add confidence factors as a nested object "confidence_factors"
        // This keeps the root cleaner and avoids collision risks
        confMap := make(map[string]interface{})
        confBytes, _ := json.Marshal(result.ConfidenceFactors)
        json.Unmarshal(confBytes, &confMap)
        
        tolMap["confidence_factors"] = confMap
        
        var tol models.JSONB = tolMap

		// Convert element analysis (full object) to JSONB
		// We store the complete ElementAnalysis (Rationale, Limitations, Behaviors) in the 'behaviors' column
		toElementJSON := func(element gemini.ElementAnalysis) models.JSONB {
			b, _ := json.Marshal(element)
			var jsonb models.JSONB
			json.Unmarshal(b, &jsonb)
			return jsonb
		}

		// Convert recommendations to JSONBArray
		recsJSON, _ := json.Marshal(result.QualitativeFeedback.Recommendations)
		var recs models.JSONBArray
		json.Unmarshal(recsJSON, &recs)

		strengthsJSON, _ := json.Marshal(result.QualitativeFeedback.Strengths)
		var strengths models.JSONBArray
		json.Unmarshal(strengthsJSON, &strengths)

		areasJSON, _ := json.Marshal(result.QualitativeFeedback.AreasForImprovement)
		var areas models.JSONBArray
		json.Unmarshal(areasJSON, &areas)

		// Helper to safely get element and sanitize score
		safelyGetElement := func(key string) gemini.ElementAnalysis {
			el, ok := result.Elements[key]
			if !ok {
				// Try alternatives or just return default
				// Gemini sometimes calls it "checks_for_understanding" etc.
				// For now, strict on key or default to 1 (Low)
				el = gemini.ElementAnalysis{
					Score:     1,
					Rationale: "Analysis not provided by AI model.",
					Behaviors: make(map[string]gemini.BehaviorRating),
				}
			}
			// Sanitize score to be within 1-5 range for DB constraint
			if el.Score < 1 {
				el.Score = 1
			}
			if el.Score > 5 {
				el.Score = 5
			}
			// Safe behaviors map
			if el.Behaviors == nil {
				el.Behaviors = make(map[string]gemini.BehaviorRating)
			}
			return el
		}

		// Create analysis record
		modelUsed := "gemini-2.0-flash"
		
		supportiveEnv := safelyGetElement("supportive_environment")
		positiveExp := safelyGetElement("positive_expectations")
		lessonFac := safelyGetElement("lesson_facilitation")
		checksUnd := safelyGetElement("checks_understanding")
		feedback := safelyGetElement("feedback")
		criticalThink := safelyGetElement("critical_thinking")
		autonomy := safelyGetElement("autonomy")
		perseverance := safelyGetElement("perseverance")
		socialCollab := safelyGetElement("social_collaborative")
		
		supportiveEnvScore := supportiveEnv.Score
		positiveExpScore := positiveExp.Score
		lessonFacScore := lessonFac.Score
		checksUndScore := checksUnd.Score
		feedbackScore := feedback.Score
		criticalThinkScore := criticalThink.Score
		autonomyScore := autonomy.Score
		perseveranceScore := perseverance.Score
		socialCollabScore := socialCollab.Score
		
		analysis := &models.Analysis{
			RecordingID:     recordingID,
			TranscriptionID: &transcription.ID,
			TimeOnLearning:  tol,

			SupportiveEnvironmentScore:     &supportiveEnvScore,
			SupportiveEnvironmentBehaviors: toElementJSON(supportiveEnv),

			PositiveExpectationsScore:     &positiveExpScore,
			PositiveExpectationsBehaviors: toElementJSON(positiveExp),

			LessonFacilitationScore:     &lessonFacScore,
			LessonFacilitationBehaviors: toElementJSON(lessonFac),

			ChecksUnderstandingScore:     &checksUndScore,
			ChecksUnderstandingBehaviors: toElementJSON(checksUnd),

			FeedbackScore:     &feedbackScore,
			FeedbackBehaviors: toElementJSON(feedback),

			CriticalThinkingScore:     &criticalThinkScore,
			CriticalThinkingBehaviors: toElementJSON(criticalThink),

			AutonomyScore:     &autonomyScore,
			AutonomyBehaviors: toElementJSON(autonomy),

			PerseveranceScore:     &perseveranceScore,
			PerseveranceBehaviors: toElementJSON(perseverance),

			SocialCollaborativeScore:     &socialCollabScore,
			SocialCollaborativeBehaviors: toElementJSON(socialCollab),

			OverallScore:        &result.OverallScore,
			Summary:             &result.QualitativeFeedback.Summary,
			Strengths:           strengths,
			AreasForImprovement: areas,
			Recommendations:     recs,

			AIModelUsed:      &modelUsed,
			ConfidenceScore:  &result.Confidence,
			ProcessingTimeMs: &processingTime,
		}

		if err := h.repo.CreateAnalysis(ctx, analysis); err != nil {
			log.Printf("Background: Failed to save analysis: %v", err)
			h.repo.UpdateRecordingStatus(ctx, recordingID, "failed")
			return
		}

		// Update recording status to completed
		if err := h.repo.UpdateRecordingStatus(ctx, recordingID, "completed"); err != nil {
			log.Printf("Background: Failed to set completed status: %v", err)
		}
		
		log.Printf("Background analysis completed successfully for recording: %s", recordingID)
	}()
}

func (h *AnalysisHandler) List(c *gin.Context) {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, models.ErrorResponse{Error: "Unauthorized"})
		return
	}

	analyses, err := h.repo.GetAnalysesByUserID(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to get analyses"})
		return
	}

	if analyses == nil {
		analyses = []*models.Analysis{}
	}

	c.JSON(http.StatusOK, analyses)
}

func (h *AnalysisHandler) Get(c *gin.Context) {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, models.ErrorResponse{Error: "Unauthorized"})
		return
	}

	analysisID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: "Invalid analysis ID"})
		return
	}

	analysis, err := h.repo.GetAnalysisByID(c.Request.Context(), analysisID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to get analysis"})
		return
	}
	if analysis == nil {
		c.JSON(http.StatusNotFound, models.ErrorResponse{Error: "Analysis not found"})
		return
	}

	// Verify ownership through recording
	recording, err := h.repo.GetRecordingByID(c.Request.Context(), analysis.RecordingID)
	if err != nil || recording == nil || recording.UserID != userID {
		c.JSON(http.StatusForbidden, models.ErrorResponse{Error: "Access denied"})
		return
	}

	// Populate Transcription if available
	if analysis.TranscriptionID != nil {
		transcription, err := h.repo.GetTranscriptionByID(c.Request.Context(), *analysis.TranscriptionID)
		if err == nil {
			analysis.Transcription = transcription
		} else {
			log.Printf("Failed to fetch transcription details: %v", err)
		}
	}

	c.JSON(http.StatusOK, analysis)
}
