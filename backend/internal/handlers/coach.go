package handlers

import (
	"encoding/json"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/worldbank/ai-coach/backend/internal/middleware"
	"github.com/worldbank/ai-coach/backend/internal/models"
	"github.com/worldbank/ai-coach/backend/internal/repository"
	"github.com/worldbank/ai-coach/backend/internal/services/gemini"
)

// CoachHandler serves the pedagogy-coordinator flow: a seven-block conversation
// guide generated from an existing TEACH analysis, one element at a time.
//
// These routes sit in the recordings group, so the same ownership rule applies
// as everywhere else — a coordinator owns the lessons they recorded.
type CoachHandler struct {
	repo   *repository.Repository
	gemini *gemini.GeminiService
}

func NewCoachHandler(repo *repository.Repository, geminiSvc *gemini.GeminiService) *CoachHandler {
	return &CoachHandler{repo: repo, gemini: geminiSvc}
}

// elementLabels are the English display names used in the prompt. The app shows
// its own localized labels; these only tell the model which skill it is writing
// about. Keys match gemini.CanonicalElements.
var elementLabels = map[string]string{
	"supportive_environment": "Supportive Learning Environment",
	"positive_expectations":  "Positive Behavioral Expectations",
	"lesson_facilitation":    "Lesson Facilitation",
	"checks_understanding":   "Checks for Understanding",
	"feedback":               "Feedback",
	"critical_thinking":      "Critical Thinking",
	"autonomy":               "Autonomy",
	"perseverance":           "Perseverance",
	"social_collaborative":   "Social & Collaborative Skills",
}

// elementBehaviors pulls one element's stored analysis object by canonical key.
func elementBehaviors(a *models.Analysis, key string) models.JSONB {
	switch key {
	case "supportive_environment":
		return a.SupportiveEnvironmentBehaviors
	case "positive_expectations":
		return a.PositiveExpectationsBehaviors
	case "lesson_facilitation":
		return a.LessonFacilitationBehaviors
	case "checks_understanding":
		return a.ChecksUnderstandingBehaviors
	case "feedback":
		return a.FeedbackBehaviors
	case "critical_thinking":
		return a.CriticalThinkingBehaviors
	case "autonomy":
		return a.AutonomyBehaviors
	case "perseverance":
		return a.PerseveranceBehaviors
	case "social_collaborative":
		return a.SocialCollaborativeBehaviors
	default:
		return nil
	}
}

// resolveOwnedRecording loads a recording and verifies the caller owns it.
// Writes the error response and returns nil when it does not.
func (h *CoachHandler) resolveOwnedRecording(c *gin.Context) (*models.Recording, uuid.UUID, bool) {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, models.ErrorResponse{Error: "Unauthorized"})
		return nil, uuid.Nil, false
	}

	recordingID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: "Invalid recording ID"})
		return nil, uuid.Nil, false
	}

	recording, err := h.repo.GetRecordingByID(c.Request.Context(), recordingID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to get recording"})
		return nil, uuid.Nil, false
	}
	if recording == nil {
		c.JSON(http.StatusNotFound, models.ErrorResponse{Error: "Recording not found"})
		return nil, uuid.Nil, false
	}
	if recording.UserID != userID {
		c.JSON(http.StatusForbidden, models.ErrorResponse{Error: "Access denied"})
		return nil, uuid.Nil, false
	}

	return recording, userID, true
}

// GetCoachScript returns the caller's stored script for one element, or null if
// they have not generated it yet.
func (h *CoachHandler) GetCoachScript(c *gin.Context) {
	recording, userID, ok := h.resolveOwnedRecording(c)
	if !ok {
		return
	}

	elementKey := c.Query("element")
	if _, valid := elementLabels[elementKey]; !valid {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: "Unknown TEACH element"})
		return
	}

	script, err := h.repo.GetCoachScript(c.Request.Context(), recording.ID, userID, elementKey)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to load coaching script"})
		return
	}
	c.JSON(http.StatusOK, script) // nil marshals to JSON null
}

// ListCoachScripts returns every element the caller has already prepared for a
// recording, so the picker can mark them.
func (h *CoachHandler) ListCoachScripts(c *gin.Context) {
	recording, userID, ok := h.resolveOwnedRecording(c)
	if !ok {
		return
	}

	scripts, err := h.repo.ListCoachScripts(c.Request.Context(), recording.ID, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to load coaching scripts"})
		return
	}
	c.JSON(http.StatusOK, scripts)
}

// GenerateCoachScript builds (or rebuilds) the seven-block script for one
// element and stores it.
//
// Synchronous: this is a text-only call over an analysis that already exists,
// so it returns in seconds — unlike the audio analysis, which runs in the
// background.
func (h *CoachHandler) GenerateCoachScript(c *gin.Context) {
	recording, userID, ok := h.resolveOwnedRecording(c)
	if !ok {
		return
	}

	var req models.GenerateCoachScriptRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: "element_key is required"})
		return
	}

	elementLabel, valid := elementLabels[req.ElementKey]
	if !valid {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: "Unknown TEACH element"})
		return
	}

	analysis, err := h.repo.GetAnalysisByRecordingID(c.Request.Context(), recording.ID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to load analysis"})
		return
	}
	if analysis == nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{
			Error: "This lesson has not been analysed yet.",
		})
		return
	}

	behaviors := elementBehaviors(analysis, req.ElementKey)
	behaviorsJSON, err := json.Marshal(behaviors)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to read analysis"})
		return
	}

	// The coordinator's language, not the recording's — they are the reader.
	language := "en"
	if user, err := h.repo.GetUserByID(c.Request.Context(), userID); err == nil && user != nil {
		if user.LanguagePreference != "" {
			language = user.LanguagePreference
		}
	}

	result, err := h.gemini.GenerateCoachScript(
		c.Request.Context(),
		elementLabel,
		ptrStr(recording.Subject),
		ptrStr(recording.GradeLevel),
		string(behaviorsJSON),
		language,
	)
	if err != nil {
		log.Printf("Coach script generation failed for recording %s element %s: %v",
			recording.ID, req.ElementKey, err)
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{
			Error: "Could not prepare the coaching conversation. Please try again.",
		})
		return
	}

	modelUsed := "gemini-2.5-flash"
	script := &models.CoachScript{
		RecordingID:       recording.ID,
		CoordinatorID:     userID,
		ElementKey:        req.ElementKey,
		Language:          language,
		ObservedEvidence:  toJSONBArray(result.ObservedEvidence),
		WhatItMeans:       strPtr(result.WhatItMeans),
		CoachQuestion:     strPtr(result.CoachQuestion),
		FollowUpQuestions: toJSONBArray(result.FollowUpQuestions),
		PossibleModel:     strPtr(result.PossibleModel),
		Practice:          strPtr(result.Practice),
		NextStep:          strPtr(result.NextStep),
		AIModelUsed:       &modelUsed,
	}

	if err := h.repo.UpsertCoachScript(c.Request.Context(), script); err != nil {
		log.Printf("Failed to save coach script: %v", err)
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to save coaching script"})
		return
	}

	c.JSON(http.StatusOK, script)
}

// toJSONBArray converts a string slice into the JSONB array the column expects.
func toJSONBArray(items []string) models.JSONBArray {
	arr := make(models.JSONBArray, 0, len(items))
	for _, item := range items {
		arr = append(arr, item)
	}
	return arr
}

// strPtr returns nil for empty strings so absent blocks marshal as JSON null
// rather than "".
func strPtr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}
