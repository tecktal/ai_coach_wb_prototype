package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/worldbank/ai-coach/backend/internal/middleware"
	"github.com/worldbank/ai-coach/backend/internal/models"
	"github.com/worldbank/ai-coach/backend/internal/repository"
	"github.com/worldbank/ai-coach/backend/internal/services/exporter"
	"github.com/worldbank/ai-coach/backend/internal/services/gemini"
	"github.com/worldbank/ai-coach/backend/internal/services/googledrive"
	"github.com/worldbank/ai-coach/backend/internal/services/storage"
)

type AnalysisHandler struct {
	repo    *repository.Repository
	gemini  *gemini.GeminiService
	storage *storage.S3Service
	drive   *googledrive.DriveService
}

func NewAnalysisHandler(repo *repository.Repository, geminiSvc *gemini.GeminiService, storage *storage.S3Service, drive *googledrive.DriveService) *AnalysisHandler {
	return &AnalysisHandler{
		repo:    repo,
		gemini:  geminiSvc,
		storage: storage,
		drive:   drive,
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
		"message":      "Analysis started in background",
		"recording_id": recordingID,
		"status":       "processing",
	})

	// Run analysis in background
	go func() {
		// Use a background context as the request context will be cancelled
		ctx := context.Background()
		log.Printf("Background analysis started for recording: %s", recordingID)

		// Download audio file from S3 to temp location
		// Note: We need a fresh check of the file URL in case it changed, or pass it in.
		// Using the 'recording' object from outer scope is safe for values.

		// Download audio file from S3 to temp location
		// Note: We need a fresh check of the file URL in case it changed, or pass it in.
		// Using the 'recording' object from outer scope is safe for values.

		tmpFile, err := os.CreateTemp("", "recording-*."+filepath.Ext(recording.FileURL))
		if err != nil {
			log.Printf("Background: Failed to create temp file for recording %s (user %s): %v", recordingID, userID, err)
			h.repo.UpdateRecordingStatusWithFailure(ctx, recordingID, "failed", "system_error", "Failed to create temporary file for processing")
			return
		}
		defer os.Remove(tmpFile.Name())
		defer tmpFile.Close()

		// Get presigned URL and download
		presignedURL, err := h.storage.GetPresignedURL(ctx, recording.FileURL, 15*time.Minute)
		if err != nil {
			log.Printf("Background: Failed to get presigned URL for recording %s (user %s): %v", recordingID, userID, err)
			h.repo.UpdateRecordingStatusWithFailure(ctx, recordingID, "failed", "storage_error", "Failed to access recording file")
			return
		}

		resp, err := http.Get(presignedURL)
		if err != nil {
			log.Printf("Background: Failed to download file from S3 for recording %s (user %s): %v", recordingID, userID, err)
			h.repo.UpdateRecordingStatusWithFailure(ctx, recordingID, "failed", "network_error", "Failed to download recording file")
			return
		}
		defer resp.Body.Close()

		if _, err := io.Copy(tmpFile, resp.Body); err != nil {
			log.Printf("Background: Failed to save temp file: %v", err)
			h.repo.UpdateRecordingStatusWithFailure(ctx, recordingID, "failed", "system_error", "Failed to save temporary file")
			return
		}

		// Validate audio file before analysis
		fileInfo, err := tmpFile.Stat()
		if err != nil {
			log.Printf("Background: Failed to get file info for recording %s (user %s): %v", recordingID, userID, err)
			h.repo.UpdateRecordingStatusWithFailure(ctx, recordingID, "failed", "system_error", "Failed to validate file")
			return
		}

		// Check minimum file size (1KB) to catch empty/corrupted files
		const minFileSizeBytes = 1024 // 1KB
		if fileInfo.Size() < minFileSizeBytes {
			log.Printf("Background: Audio file empty/corrupted for recording %s: %d bytes",
				recordingID, fileInfo.Size())
			h.repo.UpdateRecordingStatusWithFailure(ctx, recordingID, "failed", "file_too_small",
				"The audio file appears to be empty or corrupted. Please try recording again.")
			return
		}

		// Check minimum duration (5 seconds) to prevent hallucination on extremely short clips
		const minDurationSeconds = 5
		if recording.DurationSeconds != nil && *recording.DurationSeconds < minDurationSeconds {
			log.Printf("Background: Audio too short for recording %s: %d seconds",
				recordingID, *recording.DurationSeconds)
			h.repo.UpdateRecordingStatusWithFailure(ctx, recordingID, "failed", "too_short",
				fmt.Sprintf("Your recording is only %d seconds long. Please record at least 30 seconds of classroom activity for a meaningful analysis.",
					*recording.DurationSeconds))
			return
		}

		// Perform Gemini analysis
		startTime := time.Now()
		
		// Fetch user to get language preference and feedback audience
		userForAnalysis, _ := h.repo.GetUserByID(ctx, userID)
		languagePreference := "en"
		audience := gemini.AudienceTeacher
		// Country selects the programme's coaching areas — see gemini/programme.go.
		country := ""
		if userForAnalysis != nil {
			if userForAnalysis.LanguagePreference != "" {
				languagePreference = userForAnalysis.LanguagePreference
			}
			audience = gemini.NormalizeAudience(userForAnalysis.FeedbackAudience)
			if userForAnalysis.Country != nil {
				country = *userForAnalysis.Country
			}
		}

		result, err := h.gemini.AnalyzeRecording(ctx, tmpFile.Name(), languagePreference, audience, country)
		if err != nil {
			log.Printf("Background: Gemini Analysis Failed for recording %s (user %s): %v", recordingID, userID, err)

			errStr := err.Error()
			if strings.Contains(errStr, "file_too_large") {
				// Extract the human-readable message from the error string
				msg := errStr
				if idx := strings.Index(errStr, "file_too_large:"); idx >= 0 {
					msg = errStr[idx+len("file_too_large:"):]
				}
				h.repo.UpdateRecordingStatusWithFailure(ctx, recordingID, "failed", "file_too_large", strings.TrimSpace(msg))
			} else if strings.Contains(errStr, "file_too_small") {
				h.repo.UpdateRecordingStatusWithFailure(ctx, recordingID, "failed", "file_too_small",
					"The audio file appears to be empty or corrupted. Please try recording again.")
			} else if strings.Contains(errStr, "insufficient_audio") {
				log.Printf("Background: Audio completely inaudible for recording %s", recordingID)
				h.repo.UpdateRecordingStatusWithFailure(ctx, recordingID, "failed", "poor_audio",
					"No classroom audio was detected. The recording appears silent or corrupted. Please ensure the microphone was not blocked and try again.")
			} else if strings.Contains(errStr, "gemini_token_limit") || strings.Contains(errStr, "unexpected end of JSON input") {
				log.Printf("Background: Token limit exceeded for recording %s (user %s)", recordingID, userID)
				h.repo.UpdateRecordingStatusWithFailure(ctx, recordingID, "failed", "token_limit_exceeded",
					"The analysis generated too much detail and exceeded the AI token limit. Please try again with a shorter recording.")
			} else {
				h.repo.UpdateRecordingStatusWithFailure(ctx, recordingID, "failed", "ai_service_error", "AI analysis service failed")
			}
			return
		}
		if result == nil {
			log.Printf("Background: Gemini returned nil result for recording %s (user %s)", recordingID, userID)
			h.repo.UpdateRecordingStatusWithFailure(ctx, recordingID, "failed", "ai_service_error", "AI returned empty result")
			return
		}
		processingTime := int(time.Since(startTime).Milliseconds())

		// Convert time on learning AND confidence factors to JSONB
		// We merge them into one map to persist all data without schema changes
		tolMap := make(map[string]interface{})

		// 1. Marshal TimeOnLearning struct to map
		tolBytes, _ := json.Marshal(result.TimeOnLearning)
		json.Unmarshal(tolBytes, &tolMap)

		// 2. Add confidence factors as a nested object
		confMap := make(map[string]interface{})
		confBytes, _ := json.Marshal(result.ConfidenceFactors)
		json.Unmarshal(confBytes, &confMap)
		tolMap["confidence_factors"] = confMap

		// 3. Persist content_warning so Flutter can show a precise warning banner
		if result.ContentWarning != nil {
			cwMap := make(map[string]interface{})
			cwBytes, _ := json.Marshal(result.ContentWarning)
			json.Unmarshal(cwBytes, &cwMap)
			tolMap["content_warning"] = cwMap
		}

		var tol models.JSONB = tolMap

		// Prepare Science of Learning JSONB
		solJSON, _ := json.Marshal(result.ScienceOfLearning)
		fmt.Printf("DEBUG: ScienceOfLearning JSON: %s\n", string(solJSON))
		var sol models.JSONB = make(models.JSONB)
		json.Unmarshal(solJSON, &sol)
		fmt.Printf("DEBUG: ScienceOfLearning JSONB: %+v\n", sol)
		fmt.Printf("DEBUG: ScienceOfLearning JSONB length: %d\n", len(sol))

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

		// resolveElement looks up one canonical element in the model's response and
		// returns its element JSON plus a score pointer.
		//
		// A nil score means "not scored" — either the model reported N/A (score 0)
		// or it omitted the element. It is never faked: writing a real score for an
		// element the model did not assess is what previously made three of the nine
		// elements read as a hardcoded 1 on every analysis.
		resolveElement := func(key string) (models.JSONB, *int) {
			el, found := gemini.ResolveElement(result.Elements, key)
			if !found {
				// The model drifted from the requested schema, or a new key variant
				// needs adding to gemini.elementAliases. Loud on purpose: the old
				// behaviour failed silently for months.
				log.Printf("WARN: recording %s — AI response omitted TEACH element %q; storing as not scored", recordingID, key)
				return models.JSONB{}, nil
			}

			if el.Behaviors == nil {
				el.Behaviors = make(map[string]gemini.BehaviorRating)
			}
			// Clamp only the upper bound, which protects the DB CHECK constraint.
			// The lower bound is meaningful: <= 0 is the model reporting N/A.
			if el.Score > 5 {
				el.Score = 5
			}

			elementJSON := toElementJSON(el)
			if el.Score < 1 {
				// N/A — keep the element JSON, since its rationale explains why the
				// behaviour could not be observed, but record no score.
				return elementJSON, nil
			}
			score := el.Score
			return elementJSON, &score
		}

		// Create analysis record
		modelUsed := "gemini-2.5-flash"

		supportiveEnvJSON, supportiveEnvScore := resolveElement("supportive_environment")
		positiveExpJSON, positiveExpScore := resolveElement("positive_expectations")
		lessonFacJSON, lessonFacScore := resolveElement("lesson_facilitation")
		checksUndJSON, checksUndScore := resolveElement("checks_understanding")
		feedbackJSON, feedbackScore := resolveElement("feedback")
		criticalThinkJSON, criticalThinkScore := resolveElement("critical_thinking")
		autonomyJSON, autonomyScore := resolveElement("autonomy")
		perseveranceJSON, perseveranceScore := resolveElement("perseverance")
		socialCollabJSON, socialCollabScore := resolveElement("social_collaborative")

		// Overall score is the mean of the elements that were actually scored;
		// nil when none were. averageScores is shared with the manual-scoring path
		// in admin.go so AI and human overalls are computed identically.
		finalOverallScore := averageScores(
			supportiveEnvScore, positiveExpScore, lessonFacScore,
			checksUndScore, feedbackScore, criticalThinkScore,
			autonomyScore, perseveranceScore, socialCollabScore,
		)

		analysis := &models.Analysis{
			RecordingID:     recordingID,
			TranscriptionID: nil, // Transcription removed to save tokens
			TimeOnLearning:  tol,

			SupportiveEnvironmentScore:     supportiveEnvScore,
			SupportiveEnvironmentBehaviors: supportiveEnvJSON,

			PositiveExpectationsScore:     positiveExpScore,
			PositiveExpectationsBehaviors: positiveExpJSON,

			LessonFacilitationScore:     lessonFacScore,
			LessonFacilitationBehaviors: lessonFacJSON,

			ChecksUnderstandingScore:     checksUndScore,
			ChecksUnderstandingBehaviors: checksUndJSON,

			FeedbackScore:     feedbackScore,
			FeedbackBehaviors: feedbackJSON,

			CriticalThinkingScore:     criticalThinkScore,
			CriticalThinkingBehaviors: criticalThinkJSON,

			AutonomyScore:     autonomyScore,
			AutonomyBehaviors: autonomyJSON,

			PerseveranceScore:     perseveranceScore,
			PerseveranceBehaviors: perseveranceJSON,

			SocialCollaborativeScore:     socialCollabScore,
			SocialCollaborativeBehaviors: socialCollabJSON,

			OverallScore:        finalOverallScore,
			Summary:             &result.QualitativeFeedback.Summary,
			Strengths:           strengths,
			AreasForImprovement: areas,
			Recommendations:     recs,

			ScienceOfLearning: sol,

			AIModelUsed:      &modelUsed,
			ConfidenceScore:  &result.Confidence,
			ProcessingTimeMs: &processingTime,
		}

		if err := h.repo.CreateAnalysis(ctx, analysis); err != nil {
			log.Printf("Background: Failed to save analysis: %v", err)
			h.repo.UpdateRecordingStatusWithFailure(ctx, recordingID, "failed", "database_error", "Failed to save analysis results")
			return
		}

		// Update recording status to completed
		if err := h.repo.UpdateRecordingStatus(ctx, recordingID, "completed"); err != nil {
			log.Printf("Background: Failed to set completed status: %v", err)
		}

		log.Printf("Background analysis completed successfully for recording: %s", recordingID)

		// ---------------------------------------------------------------------
		// PERSISTENCE: Upload to Google Drive with Folder Structure
		// ---------------------------------------------------------------------
		if h.drive != nil {
			go func() {
				// Get user details for folder name
				user, err := h.repo.GetUserByID(context.Background(), userID)
				if err != nil {
					log.Printf("Background: Failed to get user details for Drive upload: %v", err)
					return
				}

				// Get recording count to determine sequence number
				recordingCount, err := h.repo.GetRecordingCountByUserID(context.Background(), userID)
				if err != nil {
					log.Printf("Background: Failed to get recording count for Drive upload: %v", err)
					recordingCount = 0 // Fallback to 0 if count fails
				}

				// Construct folder name: "Recording #X - Title by FirstName LastName"
				folderName := fmt.Sprintf("Recording #%d - %s by %s %s",
					recordingCount, *recording.Title, user.FirstName, user.LastName)

				// Create folder in Drive
				folderID, err := h.drive.CreateFolder(context.Background(), folderName, "")
				if err != nil {
					log.Printf("Background: Failed to create Drive folder: %v", err)
					return
				}
				log.Printf("Background: Created Drive folder '%s' with ID: %s", folderName, folderID)

				// Download audio file from S3 for Drive upload
				// We need to download again since the temp file was already deleted
				audioReader, contentType, _, _, err := h.storage.GetFileStream(context.Background(), recording.FileURL, "")
				if err != nil {
					log.Printf("Background: Failed to download audio from S3 for Drive upload: %v", err)
					return
				}
				defer audioReader.Close()

				audioExt := filepath.Ext(recording.FileURL)
				audioFilename := "audio" + audioExt
				// Use content type from S3, fallback to guessing if empty
				audioMimeType := contentType
				if audioMimeType == "" || audioMimeType == "application/octet-stream" {
					audioMimeType = "audio/mpeg" // Default
					if audioExt == ".m4a" {
						audioMimeType = "audio/mp4"
					} else if audioExt == ".wav" {
						audioMimeType = "audio/wav"
					}
				}

				// Upload to the newly created folder
				audioLink, err := h.drive.UploadFile(context.Background(), audioReader, audioFilename, audioMimeType, folderID)
				if err != nil {
					log.Printf("Background: Failed to upload audio to Drive folder: %v", err)
				} else {
					log.Printf("Background: Successfully uploaded audio to Drive: %s", audioLink)
				}

				// Generate Excel report
				excelBuffer, err := exporter.GenerateAnalysisExcel(analysis, user, recording, nil)
				if err != nil {
					log.Printf("Background: Failed to generate Excel report: %v", err)
					return
				}

				// Upload Excel file to the folder
				excelFilename := fmt.Sprintf("analysis of audio %s by teacher %s %s.xlsx",
					*recording.Title, user.FirstName, user.LastName)
				excelLink, err := h.drive.UploadFile(context.Background(), excelBuffer, excelFilename,
					"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", folderID)
				if err != nil {
					log.Printf("Background: Failed to upload Excel to Drive folder: %v", err)
				} else {
					log.Printf("Background: Successfully uploaded Excel report to Drive: %s", excelLink)
				}

				log.Printf("Background: Drive folder structure created successfully for recording: %s", recordingID)
			}()
		}
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
