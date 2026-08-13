package handlers

import (
	"context"
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
			c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: fmt.Sprintf("Failed to get analysis: %v", err)})
			return
		}
		if analysis == nil {
			c.JSON(http.StatusNotFound, models.ErrorResponse{Error: "Analysis not found"})
			return
		}

		// Verify ownership through recording
		recording, err := h.repo.GetRecordingByID(c.Request.Context(), analysis.RecordingID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: fmt.Sprintf("Failed to check recording ownership: %v", err)})
			return
		}
		if recording == nil || recording.UserID != userID {
			c.JSON(http.StatusForbidden, models.ErrorResponse{Error: "Access denied to this analysis"})
			return
		}
	}

	session := &models.ChatSession{
		UserID:     userID,
		AnalysisID: req.AnalysisID,
	}

	if err := h.repo.CreateChatSession(c.Request.Context(), session); err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: fmt.Sprintf("Failed to create chat session: %v", err)})
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

func (h *ChatHandler) ListSessions(c *gin.Context) {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, models.ErrorResponse{Error: "Unauthorized"})
		return
	}

	fmt.Printf("DEBUG: ListSessions called by user: %s\n", userID)

	sessions, err := h.repo.GetChatSessionsByUserID(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: fmt.Sprintf("Failed to list sessions: %v", err)})
		return
	}

	fmt.Printf("DEBUG: Found %d sessions for user %s\n", len(sessions), userID)
	for i, s := range sessions {
		fmt.Printf("DEBUG: Session %d: ID=%s, UserID=%s, LessonTitle=%v\n", i, s.ID, s.UserID, s.LessonTitle)
	}

	c.JSON(http.StatusOK, sessions)
}

// DeleteSession deletes a chat session
func (h *ChatHandler) DeleteSession(c *gin.Context) {
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

	// Verify ownership
	session, err := h.repo.GetChatSessionByID(c.Request.Context(), sessionID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to get session"})
		return
	}
	if session == nil {
		c.JSON(http.StatusNotFound, models.ErrorResponse{Error: "Session not found"})
		return
	}
	if session.UserID != userID {
		c.JSON(http.StatusForbidden, models.ErrorResponse{Error: "Access denied"})
		return
	}

	// Delete the session
	fmt.Printf("Deleting chat session: %s\n", sessionID)
	if err := h.repo.DeleteChatSession(c.Request.Context(), sessionID); err != nil {
		fmt.Printf("Failed to delete session: %v\n", err)
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to delete session"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Session deleted successfully"})
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

	userForChat, _ := h.repo.GetUserByID(c.Request.Context(), userID)
	languagePreference := "en"
	audience := gemini.AudienceTeacher
	if userForChat != nil {
		if userForChat.LanguagePreference != "" {
			languagePreference = userForChat.LanguagePreference
		}
		audience = gemini.NormalizeAudience(userForChat.FeedbackAudience)
	}

	// Build analysis context (current lesson + prior lessons for cross-lesson memory)
	analysisContext := h.buildAnalysisContext(c.Request.Context(), session, userID, audience)

	// Generate response
	response, err := h.gemini.GetCoachingResponse(c.Request.Context(), history, analysisContext, languagePreference, audience)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to generate response"})
		return
	}

	// Save assistant message
	assistantMessage := &models.ChatMessage{
		SessionID: sessionID,
		Role:      "assistant",
		Content:   response,
	}
	if err := h.repo.CreateChatMessage(c.Request.Context(), assistantMessage); err != nil {
		// Log error but return success since the user got the answer
		fmt.Printf("Failed to save assistant message: %v\n", err)
	}

	c.JSON(http.StatusOK, gin.H{
		"response": response,
		"message":  assistantMessage,
	})
}

// StreamMessage handles streaming chat responses via SSE
func (h *ChatHandler) StreamMessage(c *gin.Context) {
	// 1. Setup SSE headers
	c.Writer.Header().Set("Content-Type", "text/event-stream")
	c.Writer.Header().Set("Cache-Control", "no-cache")
	c.Writer.Header().Set("Connection", "keep-alive")
	c.Writer.Header().Set("Transfer-Encoding", "chunked")

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
	if err != nil || session == nil {
		c.JSON(http.StatusNotFound, models.ErrorResponse{Error: "Session not found"})
		return
	}

	if session.UserID != userID {
		c.JSON(http.StatusForbidden, models.ErrorResponse{Error: "Access denied"})
		return
	}

	// Save user message first
	userMessage := &models.ChatMessage{
		SessionID: sessionID,
		Role:      "user",
		Content:   req.Content,
	}
	if err := h.repo.CreateChatMessage(c.Request.Context(), userMessage); err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to save message"})
		return
	}

	// Get history
	messages, _ := h.repo.GetChatMessagesBySessionID(c.Request.Context(), sessionID)
	var history []map[string]string
	for _, msg := range messages {
		history = append(history, map[string]string{
			"role":    msg.Role,
			"content": msg.Content,
		})
	}

	userForChat, _ := h.repo.GetUserByID(c.Request.Context(), userID)
	languagePreference := "en"
	audience := gemini.AudienceTeacher
	if userForChat != nil {
		if userForChat.LanguagePreference != "" {
			languagePreference = userForChat.LanguagePreference
		}
		audience = gemini.NormalizeAudience(userForChat.FeedbackAudience)
	}

	// Build context (current lesson + prior lessons)
	analysisContext := h.buildAnalysisContext(c.Request.Context(), session, userID, audience)

	// Start stream
	fullResponse := ""

	err = h.gemini.GetCoachingResponseStream(c.Request.Context(), history, analysisContext, languagePreference, audience, func(chunk string) error {
		fullResponse += chunk
		c.SSEvent("message", chunk)
		c.Writer.Flush()
		return nil
	})

	if err != nil {
		fmt.Printf("Streaming error: %v\n", err)
		c.SSEvent("error", "Failed to generate response")
		return
	}

	// Save assistant message when done
	assistantMessage := &models.ChatMessage{
		SessionID: sessionID,
		Role:      "assistant",
		Content:   fullResponse,
	}
	h.repo.CreateChatMessage(context.Background(), assistantMessage)

	// Log what we actually sent so we can compare with client
	fmt.Printf("[SSE] StreamMessage done. fullResponse len=%d\n", len(fullResponse))
	if len(fullResponse) > 0 {
		first := fullResponse
		if len(first) > 100 { first = first[:100] }
		last := fullResponse
		if len(last) > 100 { last = last[len(last)-100:] }
		fmt.Printf("[SSE] FIRST 100: %s\n", first)
		fmt.Printf("[SSE]  LAST 100: %s\n", last)
	}

	// Send done event
	c.SSEvent("done", "Stream finished")
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

// buildAnalysisContext builds the Gemini system context string for a chat session.
// It includes:
//  1. The current lesson's full analysis (scores, strengths, improvements)
//  2. The teacher's last 2 prior lessons for cross-lesson memory
//
// This allows the AI coach to acknowledge improvement and reference past struggles.
func (h *ChatHandler) buildAnalysisContext(ctx context.Context, session *models.ChatSession, userID uuid.UUID, audience string) string {
	if session.AnalysisID == nil {
		return "No specific lesson analysis available for this session. Answer general teaching questions."
	}

	// ── Current lesson ───────────────────────────────────────────────────────
	analysis, err := h.repo.GetAnalysisByID(ctx, *session.AnalysisID)
	if err != nil || analysis == nil {
		return "No specific lesson analysis available for this session. Answer general teaching questions."
	}

	rec, _ := h.repo.GetRecordingByID(ctx, analysis.RecordingID)
	subject := "Unknown Subject"
	grade := "Unknown Grade"
	if rec != nil {
		if rec.Subject != nil {
			subject = *rec.Subject
		}
		if rec.GradeLevel != nil {
			grade = *rec.GradeLevel
		}
	}

	currentCtx := fmt.Sprintf(
		`CURRENT LESSON CONTEXT:
Lesson: %s — %s
Summary: %s
Strengths: %v
Areas for Improvement: %v
Recommendations: %v`,
		subject, grade,
		ptrStr(analysis.Summary),
		analysis.Strengths,
		analysis.AreasForImprovement,
		analysis.Recommendations,
	)

	// ── Prior lessons (cross-lesson memory) ──────────────────────────────────
	allAnalyses, err := h.repo.GetAnalysesByUserID(ctx, userID)
	if err != nil || len(allAnalyses) <= 1 {
		// Only 1 (or none) — no prior context to add
		return currentCtx
	}

	priorCtx := ""
	count := 0
	for _, prior := range allAnalyses {
		if prior.ID == analysis.ID {
			continue // Skip the current lesson
		}
		if count >= 2 {
			break
		}
		priorCtx += fmt.Sprintf(
			"  • %s — focus areas: %v\n",
			prior.CreatedAt.Format("Jan 2"),
			prior.AreasForImprovement,
		)
		count++
	}

	if priorCtx == "" {
		return currentCtx
	}

	coachingInstructions := `IMPORTANT COACHING INSTRUCTIONS:
- If the teacher improved on a previously noted weakness, acknowledge and celebrate it.
- If a weakness from a prior lesson recurs, gently note the pattern and offer a specific strategy.
- Reference dates naturally ("since your Jan 2 lesson...") to make feedback feel personal.
- Do not reference numerical scores or ratings — focus on observable behaviours and patterns only.
- Do not list all prior sessions robotically — weave context in naturally only when relevant.`

	if gemini.NormalizeAudience(audience) == gemini.AudienceCoordinator {
		// The coordinator is reading this to prepare a conversation, so prior
		// lessons are shared history they can raise — not the reader's own past.
		coachingInstructions = `IMPORTANT COACHING INSTRUCTIONS:
- If the teacher improved on a previously noted weakness, point that out so the coordinator can recognise it with her.
- If a weakness recurs across lessons, name the pattern and suggest how the coordinator might raise it.
- Reference dates naturally ("in her Jan 2 lesson...") so the coordinator can ground the conversation in specifics.
- Do not reference numerical scores or ratings — focus on observable behaviours and patterns only.
- Do not list all prior sessions robotically — surface prior context only where it is useful to the conversation.`
	}

	return currentCtx + fmt.Sprintf(`

PREVIOUS LESSONS (last %d):
%s
%s`, count, priorCtx, coachingInstructions)
}
