package handlers

import (
	"fmt"
	"io"
	"math"
	"net/http"
	"path/filepath"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/worldbank/ai-coach/backend/internal/middleware"
	"github.com/worldbank/ai-coach/backend/internal/models"
	"github.com/worldbank/ai-coach/backend/internal/repository"
	"github.com/worldbank/ai-coach/backend/internal/services/exporter"
	"github.com/worldbank/ai-coach/backend/internal/services/storage"
)

// validRoles are the roles an ADMIN may assign through user management:
//   - teacher:     app only, no dashboard access
//   - coordinator: app only, coaching flow; counted separately from teachers
//   - viewer:      dashboard read-only
//   - admin:       dashboard + user management
//
// Not to be confused with models.SelfAssignableRole, which is what a user may
// choose for themselves at registration — that set excludes viewer and admin.
var validRoles = map[string]bool{
	"teacher": true, "coordinator": true, "viewer": true, "admin": true,
}

// AdminHandler serves the World Bank monitoring dashboard endpoints. Routes are
// protected by middleware.RequireRoles (admin|viewer for reads, admin only for
// user management).
type AdminHandler struct {
	repo    *repository.Repository
	storage *storage.S3Service
}

func NewAdminHandler(repo *repository.Repository, s3 *storage.S3Service) *AdminHandler {
	return &AdminHandler{repo: repo, storage: s3}
}

// parseLessonFilters reads the drill-down filters from query params.
func parseLessonFilters(c *gin.Context) models.LessonLogFilters {
	f := models.LessonLogFilters{
		Country:   c.Query("country"),
		School:    c.Query("school"),
		Grade:     c.Query("grade"),
		Subject:   c.Query("subject"),
		Status:    c.Query("status"),
		TeacherID: c.Query("teacher"),
	}
	if s := c.Query("start_date"); s != "" {
		if t, err := time.Parse("2006-01-02", s); err == nil {
			f.StartDate = &t
		}
	}
	if s := c.Query("end_date"); s != "" {
		if t, err := time.Parse("2006-01-02", s); err == nil {
			// Include the entire end day.
			end := t.Add(24*time.Hour - time.Second)
			f.EndDate = &end
		}
	}
	return f
}

func parsePagination(c *gin.Context) models.Pagination {
	p := models.Pagination{
		Page:     1,
		PageSize: 50,
		Sort:     c.Query("sort"),
	}
	if v, err := strconv.Atoi(c.Query("page")); err == nil && v > 0 {
		p.Page = v
	}
	if v, err := strconv.Atoi(c.Query("page_size")); err == nil && v > 0 {
		p.PageSize = v
	}
	return p
}

// Overview returns headline counts for the dashboard.
func (h *AdminHandler) Overview(c *gin.Context) {
	overview, err := h.repo.GetAdminOverview(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to load overview"})
		return
	}
	c.JSON(http.StatusOK, overview)
}

// Lessons returns the consolidated, filterable, paginated lesson log.
func (h *AdminHandler) Lessons(c *gin.Context) {
	result, err := h.repo.GetLessonsLog(c.Request.Context(), parseLessonFilters(c), parsePagination(c))
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to load lessons"})
		return
	}
	c.JSON(http.StatusOK, result)
}

// LessonDetail returns a single recording with its teacher and full analysis
// (analysis is null if not yet analyzed). Admin|viewer.
func (h *AdminHandler) LessonDetail(c *gin.Context) {
	recordingID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: "Invalid lesson ID"})
		return
	}

	recording, err := h.repo.GetRecordingByID(c.Request.Context(), recordingID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to load lesson"})
		return
	}
	if recording == nil {
		c.JSON(http.StatusNotFound, models.ErrorResponse{Error: "Lesson not found"})
		return
	}

	teacher, err := h.repo.GetUserByID(c.Request.Context(), recording.UserID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to load teacher"})
		return
	}

	analysis, err := h.repo.GetAnalysisByRecordingID(c.Request.Context(), recordingID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to load analysis"})
		return
	}
	// Populate transcription if one was stored.
	if analysis != nil && analysis.TranscriptionID != nil {
		if t, err := h.repo.GetTranscriptionByID(c.Request.Context(), *analysis.TranscriptionID); err == nil {
			analysis.Transcription = t
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"recording": recording,
		"teacher":   teacher,
		"analysis":  analysis,
	})
}

// LessonAudio streams a recording's audio from storage, with HTTP Range support
// for seeking. Admin|viewer. No ownership check (dashboard reviewers are not the
// owner). Auth accepts the `token` query param so a native <audio> tag can play.
func (h *AdminHandler) LessonAudio(c *gin.Context) {
	recordingID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: "Invalid lesson ID"})
		return
	}

	recording, err := h.repo.GetRecordingByID(c.Request.Context(), recordingID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to load lesson"})
		return
	}
	if recording == nil {
		c.JSON(http.StatusNotFound, models.ErrorResponse{Error: "Lesson not found"})
		return
	}

	rangeHeader := c.GetHeader("Range")
	reader, contentType, contentLength, contentRange, err := h.storage.GetFileStream(c.Request.Context(), recording.FileURL, rangeHeader)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to stream audio"})
		return
	}
	defer reader.Close()

	c.Header("Content-Type", contentType)
	c.Header("Accept-Ranges", "bytes")
	c.Header("Content-Length", fmt.Sprintf("%d", contentLength))
	c.Header("Content-Disposition", fmt.Sprintf("inline; filename=%q", filepath.Base(recording.FileURL)))
	// A 206 must carry Content-Range or browsers reject it (breaks playback).
	if rangeHeader != "" && contentRange != "" {
		c.Header("Content-Range", contentRange)
		c.Status(http.StatusPartialContent)
	} else {
		c.Status(http.StatusOK)
	}

	if _, err := io.Copy(c.Writer, reader); err != nil {
		fmt.Printf("Error streaming admin lesson audio: %v\n", err)
	}
}

// Usage returns per-school adoption/usage aggregates.
func (h *AdminHandler) Usage(c *gin.Context) {
	usage, err := h.repo.GetSchoolUsage(c.Request.Context(), c.Query("country"))
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to load usage"})
		return
	}
	c.JSON(http.StatusOK, usage)
}

// Teachers returns the teacher roster with activity summaries.
func (h *AdminHandler) Teachers(c *gin.Context) {
	teachers, err := h.repo.GetTeacherRoster(c.Request.Context(), c.Query("country"), c.Query("school"))
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to load teachers"})
		return
	}
	c.JSON(http.StatusOK, teachers)
}

// FilterOptions returns the distinct values for filter dropdowns.
func (h *AdminHandler) FilterOptions(c *gin.Context) {
	opts, err := h.repo.GetAdminFilterOptions(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to load filter options"})
		return
	}
	c.JSON(http.StatusOK, opts)
}

// Users lists all users with their roles, for the admin user-management screen.
// Admin-only.
func (h *AdminHandler) Users(c *gin.Context) {
	users, err := h.repo.GetAllUsers(c.Request.Context(), c.Query("q"))
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to load users"})
		return
	}
	c.JSON(http.StatusOK, users)
}

// UpdateUserRole changes a user's role (teacher/viewer/admin). Admin-only.
// Guards against an admin removing their own access or the last admin's.
func (h *AdminHandler) UpdateUserRole(c *gin.Context) {
	targetID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: "Invalid user ID"})
		return
	}

	var req models.UpdateRoleRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: "Role is required"})
		return
	}
	if !validRoles[req.Role] {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: "Invalid role. Must be teacher, viewer or admin."})
		return
	}

	requesterID, err := middleware.GetUserID(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, models.ErrorResponse{Error: "Unauthorized"})
		return
	}

	target, err := h.repo.GetUserByID(c.Request.Context(), targetID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to load user"})
		return
	}
	if target == nil {
		c.JSON(http.StatusNotFound, models.ErrorResponse{Error: "User not found"})
		return
	}

	// No-op if unchanged.
	if target.Role == req.Role {
		c.JSON(http.StatusOK, gin.H{"id": targetID, "role": req.Role})
		return
	}

	// Guard: an admin cannot remove their own admin access (avoids lock-out).
	if target.ID == requesterID && req.Role != "admin" {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: "You cannot remove your own admin access."})
		return
	}

	// Guard: never demote the last remaining admin.
	if target.Role == "admin" && req.Role != "admin" {
		admins, err := h.repo.CountAdmins(c.Request.Context())
		if err != nil {
			c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to verify admins"})
			return
		}
		if admins <= 1 {
			c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: "Cannot remove the last admin."})
			return
		}
	}

	if _, err := h.repo.UpdateUserRole(c.Request.Context(), targetID, req.Role); err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to update role"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"id": targetID, "role": req.Role})
}

// GetManualScore returns the signed-in coach's manual score for a recording, or
// null if they have not scored it yet. Admin|viewer.
func (h *AdminHandler) GetManualScore(c *gin.Context) {
	recordingID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: "Invalid lesson ID"})
		return
	}
	scorerID, err := middleware.GetUserID(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, models.ErrorResponse{Error: "Unauthorized"})
		return
	}

	score, err := h.repo.GetManualScore(c.Request.Context(), recordingID, scorerID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to load manual score"})
		return
	}
	c.JSON(http.StatusOK, score) // nil marshals to JSON null
}

// SaveManualScore upserts the signed-in coach's manual scoring for a recording.
// Admin|viewer: pedagogy coaches (viewers) may write their OWN score — this is
// the one write the dashboard grants viewers (see validRoles above).
func (h *AdminHandler) SaveManualScore(c *gin.Context) {
	recordingID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: "Invalid lesson ID"})
		return
	}
	scorerID, err := middleware.GetUserID(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, models.ErrorResponse{Error: "Unauthorized"})
		return
	}

	var req models.ManualScoreRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: "Invalid manual score. Scores must be between 1 and 5."})
		return
	}

	// Ensure the recording exists before scoring it.
	recording, err := h.repo.GetRecordingByID(c.Request.Context(), recordingID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to load lesson"})
		return
	}
	if recording == nil {
		c.JSON(http.StatusNotFound, models.ErrorResponse{Error: "Lesson not found"})
		return
	}

	score := &models.ManualScore{
		RecordingID:                recordingID,
		ScorerID:                   scorerID,
		SupportiveEnvironmentScore: req.SupportiveEnvironmentScore,
		PositiveExpectationsScore:  req.PositiveExpectationsScore,
		LessonFacilitationScore:    req.LessonFacilitationScore,
		ChecksUnderstandingScore:   req.ChecksUnderstandingScore,
		FeedbackScore:              req.FeedbackScore,
		CriticalThinkingScore:      req.CriticalThinkingScore,
		AutonomyScore:              req.AutonomyScore,
		PerseveranceScore:          req.PerseveranceScore,
		SocialCollaborativeScore:   req.SocialCollaborativeScore,
		Summary:                    req.Summary,
		Strengths:                  req.Strengths,
		AreasForImprovement:        req.AreasForImprovement,
		Recommendations:            req.Recommendations,
		Notes:                      req.Notes,
	}

	// element_rationales: map[string]string -> JSONB
	if len(req.ElementRationales) > 0 {
		rationales := make(models.JSONB, len(req.ElementRationales))
		for k, v := range req.ElementRationales {
			rationales[k] = v
		}
		score.ElementRationales = rationales
	}

	// Overall = mean of the provided element scores (nil when none provided).
	score.OverallScore = averageScores(
		req.SupportiveEnvironmentScore, req.PositiveExpectationsScore, req.LessonFacilitationScore,
		req.ChecksUnderstandingScore, req.FeedbackScore, req.CriticalThinkingScore,
		req.AutonomyScore, req.PerseveranceScore, req.SocialCollaborativeScore,
	)

	if err := h.repo.UpsertManualScore(c.Request.Context(), score); err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to save manual score"})
		return
	}
	c.JSON(http.StatusOK, score)
}

// averageScores returns the mean of the non-nil scores rounded to 2 dp, or nil
// when none are provided.
func averageScores(scores ...*int) *float64 {
	sum, n := 0, 0
	for _, s := range scores {
		if s != nil {
			sum += *s
			n++
		}
	}
	if n == 0 {
		return nil
	}
	avg := math.Round(float64(sum)/float64(n)*100) / 100
	return &avg
}

// ExportLessonAnalysis streams a per-lesson Excel workbook (AI report + the
// signed-in coach's manual scores + comparison). Admin|viewer. Auth accepts the
// `token` query param so a plain <a> download works.
func (h *AdminHandler) ExportLessonAnalysis(c *gin.Context) {
	recordingID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: "Invalid lesson ID"})
		return
	}
	scorerID, err := middleware.GetUserID(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, models.ErrorResponse{Error: "Unauthorized"})
		return
	}

	recording, err := h.repo.GetRecordingByID(c.Request.Context(), recordingID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to load lesson"})
		return
	}
	if recording == nil {
		c.JSON(http.StatusNotFound, models.ErrorResponse{Error: "Lesson not found"})
		return
	}
	teacher, err := h.repo.GetUserByID(c.Request.Context(), recording.UserID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to load teacher"})
		return
	}
	if teacher == nil {
		c.JSON(http.StatusNotFound, models.ErrorResponse{Error: "Teacher not found"})
		return
	}
	analysis, err := h.repo.GetAnalysisByRecordingID(c.Request.Context(), recordingID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to load analysis"})
		return
	}
	if analysis == nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: "This lesson has not been analyzed yet."})
		return
	}
	manual, err := h.repo.GetManualScore(c.Request.Context(), recordingID, scorerID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to load manual score"})
		return
	}

	buf, err := exporter.GenerateAnalysisExcel(analysis, teacher, recording, manual)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to generate export file"})
		return
	}

	filename := fmt.Sprintf("lesson_analysis_%s.xlsx", time.Now().Format("2006-01-02"))
	c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=%q", filename))
	c.Data(http.StatusOK,
		"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
		buf.Bytes())
}

// Export streams an Excel workbook of the filtered lesson log.
func (h *AdminHandler) Export(c *gin.Context) {
	rows, err := h.repo.GetLessonsLogAll(c.Request.Context(), parseLessonFilters(c), c.Query("sort"))
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to export lessons"})
		return
	}

	buf, err := exporter.GenerateLessonsLogExcel(rows)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to generate export file"})
		return
	}

	filename := fmt.Sprintf("lessons_export_%s.xlsx", time.Now().Format("2006-01-02"))
	c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=%q", filename))
	c.Data(http.StatusOK,
		"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
		buf.Bytes())
}
