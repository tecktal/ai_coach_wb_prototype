package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/worldbank/ai-coach/backend/internal/middleware"
	"github.com/worldbank/ai-coach/backend/internal/models"
	"github.com/worldbank/ai-coach/backend/internal/repository"
)

type ProgressHandler struct {
	repo *repository.Repository
}

func NewProgressHandler(repo *repository.Repository) *ProgressHandler {
	return &ProgressHandler{
		repo: repo,
	}
}

func (h *ProgressHandler) GetProgress(c *gin.Context) {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, models.ErrorResponse{Error: "Unauthorized"})
		return
	}

	// Get period from query params (default to last 30 days)
	endDate := time.Now()
	startDate := endDate.AddDate(0, 0, -30)

	if start := c.Query("start_date"); start != "" {
		if parsed, err := time.Parse("2006-01-02", start); err == nil {
			startDate = parsed
		}
	}
	if end := c.Query("end_date"); end != "" {
		if parsed, err := time.Parse("2006-01-02", end); err == nil {
			endDate = parsed
		}
	}

	progress, err := h.repo.GetProgressByUserID(c.Request.Context(), userID, startDate, endDate)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to get progress"})
		return
	}

	c.JSON(http.StatusOK, progress)
}

func (h *ProgressHandler) GetTrends(c *gin.Context) {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, models.ErrorResponse{Error: "Unauthorized"})
		return
	}

	// Get all analyses for the user
	analyses, err := h.repo.GetAnalysesByUserID(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to get analyses"})
		return
	}

	// Build trend data
	type TrendPoint struct {
		Date                      time.Time `json:"date"`
		OverallScore              float64   `json:"overall_score"`
		SupportiveEnvironment     int       `json:"supportive_environment"`
		PositiveExpectations      int       `json:"positive_expectations"`
		LessonFacilitation        int       `json:"lesson_facilitation"`
		ChecksUnderstanding       int       `json:"checks_understanding"`
		Feedback                  int       `json:"feedback"`
		CriticalThinking          int       `json:"critical_thinking"`
		Autonomy                  int       `json:"autonomy"`
		Perseverance              int       `json:"perseverance"`
		SocialCollaborative       int       `json:"social_collaborative"`
	}

	var trends []TrendPoint
	for _, analysis := range analyses {
		if analysis.OverallScore != nil {
			trends = append(trends, TrendPoint{
				Date:                  analysis.CreatedAt,
				OverallScore:          *analysis.OverallScore,
				SupportiveEnvironment: derefInt(analysis.SupportiveEnvironmentScore),
				PositiveExpectations:  derefInt(analysis.PositiveExpectationsScore),
				LessonFacilitation:    derefInt(analysis.LessonFacilitationScore),
				ChecksUnderstanding:   derefInt(analysis.ChecksUnderstandingScore),
				Feedback:              derefInt(analysis.FeedbackScore),
				CriticalThinking:      derefInt(analysis.CriticalThinkingScore),
				Autonomy:              derefInt(analysis.AutonomyScore),
				Perseverance:          derefInt(analysis.PerseveranceScore),
				SocialCollaborative:   derefInt(analysis.SocialCollaborativeScore),
			})
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"trends":         trends,
		"total_analyses": len(analyses),
	})
}

func derefInt(i *int) int {
	if i == nil {
		return 0
	}
	return *i
}
