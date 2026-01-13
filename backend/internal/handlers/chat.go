package handlers

import (
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/worldbank/ai-coach/backend/internal/middleware"
	"github.com/worldbank/ai-coach/backend/internal/models"
	"github.com/worldbank/ai-coach/backend/internal/repository"
	"github.com/worldbank/ai-coach/backend/internal/services/gemini"
)

type ChatHandler struct {
	repo   *repository.Repository
	gemini *gemini.GeminiService
}

func NewChatHandler(repo *repository.Repository, geminiSvc *gemini.GeminiService) *ChatHandler {
	return &ChatHandler{
		repo:   repo,
		gemini: geminiSvc,
	}
}

func (h *ChatHandler) CreateSession(c *gin.Context) {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, models.ErrorResponse{Error: "Unauthorized"})
		return
	}

	var req struct {
		AnalysisID *uuid.UUID `json:"analysis_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: err.Error()})
		return
	}

	// If analysis ID provided, verify ownership
	if req.AnalysisID != nil {
		analysis, err := h.repo.GetAnalysisByID(c.Request.Context(), *req.AnalysisID)
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
	}

	session := &models.ChatSession{
		UserID:     userID,
		AnalysisID: req.AnalysisID,
	}

	if err := h.repo.CreateChatSession(c.Request.Context(), session); err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to create session"})
		return
	}

	c.JSON(http.StatusCreated, session)
}

func (h *ChatHandler) GetSession(c *gin.Context) {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, models.ErrorResponse{Error: "Unauthorized"})
		return
	}

	sessionID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: "Invalid session ID"})
		return
	}

	session, err := h.repo.GetChatSessionByID(c.Request.Context(), sessionID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to get session"})
		return
	}
	if session == nil {
		c.JSON(http.StatusNotFound, models.ErrorResponse{Error: "Session not found"})
		return
	}

	// Verify ownership
	if session.UserID != userID {
		c.JSON(http.StatusForbidden, models.ErrorResponse{Error: "Access denied"})
		return
	}

	// Get messages
	messages, err := h.repo.GetChatMessagesBySessionID(c.Request.Context(), sessionID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to get messages"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"session":  session,
		"messages": messages,
	})
}

func (h *ChatHandler) SendMessage(c *gin.Context) {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, models.ErrorResponse{Error: "Unauthorized"})
		return
	}

	sessionID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: "Invalid session ID"})
		return
	}

	var req models.SendMessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: err.Error()})
		return
	}

	// Get session
	session, err := h.repo.GetChatSessionByID(c.Request.Context(), sessionID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to get session"})
		return
	}
	if session == nil {
		c.JSON(http.StatusNotFound, models.ErrorResponse{Error: "Session not found"})
		return
	}

	// Verify ownership
	if session.UserID != userID {
		c.JSON(http.StatusForbidden, models.ErrorResponse{Error: "Access denied"})
		return
	}

	// Save user message
	userMessage := &models.ChatMessage{
		SessionID: sessionID,
		Role:      "user",
		Content:   req.Content,
	}
	if err := h.repo.CreateChatMessage(c.Request.Context(), userMessage); err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to save message"})
		return
	}

	// Get conversation history
	messages, err := h.repo.GetChatMessagesBySessionID(c.Request.Context(), sessionID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to get history"})
		return
	}

	// Build conversation history for Gemini
	var history []map[string]string
	for _, msg := range messages {
		history = append(history, map[string]string{
			"role":    msg.Role,
			"content": msg.Content,
		})
	}

	// Build analysis context
	analysisContext := "No specific lesson analysis available for this session."
	if session.AnalysisID != nil {
		analysis, err := h.repo.GetAnalysisByID(c.Request.Context(), *session.AnalysisID)
		if err == nil && analysis != nil {
			analysisContext = fmt.Sprintf(`Context from their recent lesson:
- Lesson summary: %s
- Overall score: %.1f/5
- Strengths: %v
- Areas for improvement: %v

Detailed element scores:
- Supportive Environment: %d/5
- Positive Expectations: %d/5
- Lesson Facilitation: %d/5
- Checks Understanding: %d/5
- Feedback: %d/5
- Critical Thinking: %d/5
- Autonomy: %d/5
- Perseverance: %d/5
- Social & Collaborative: %d/5`,
				ptrStr(analysis.Summary),
				ptrFloat(analysis.OverallScore),
				analysis.Strengths,
				analysis.AreasForImprovement,
				ptrInt(analysis.SupportiveEnvironmentScore),
				ptrInt(analysis.PositiveExpectationsScore),
				ptrInt(analysis.LessonFacilitationScore),
				ptrInt(analysis.ChecksUnderstandingScore),
				ptrInt(analysis.FeedbackScore),
				ptrInt(analysis.CriticalThinkingScore),
				ptrInt(analysis.AutonomyScore),
				ptrInt(analysis.PerseveranceScore),
				ptrInt(analysis.SocialCollaborativeScore),
			)
		}
	}

	// Get AI response
	aiResponse, err := h.gemini.GetCoachingResponse(c.Request.Context(), history, analysisContext)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to get AI response"})
		return
	}

	// Save assistant message
	assistantMessage := &models.ChatMessage{
		SessionID: sessionID,
		Role:      "assistant",
		Content:   aiResponse,
	}
	if err := h.repo.CreateChatMessage(c.Request.Context(), assistantMessage); err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to save AI response"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"user_message":      userMessage,
		"assistant_message": assistantMessage,
	})
}

func ptrStr(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

func ptrFloat(f *float64) float64 {
	if f == nil {
		return 0
	}
	return *f
}

func ptrInt(i *int) int {
	if i == nil {
		return 0
	}
	return *i
}
