package handlers

import (
	"fmt"
	"net/http"
	"path/filepath"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/worldbank/ai-coach/backend/internal/middleware"
	"github.com/worldbank/ai-coach/backend/internal/models"
	"github.com/worldbank/ai-coach/backend/internal/repository"
	"github.com/worldbank/ai-coach/backend/internal/services/storage"
)

type RecordingHandler struct {
	repo    *repository.Repository
	storage *storage.S3Service
}

func NewRecordingHandler(repo *repository.Repository, storage *storage.S3Service) *RecordingHandler {
	return &RecordingHandler{
		repo:    repo,
		storage: storage,
	}
}

func (h *RecordingHandler) Upload(c *gin.Context) {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, models.ErrorResponse{Error: "Unauthorized"})
		return
	}

	// Parse multipart form
	file, header, err := c.Request.FormFile("audio")
	if err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: "Audio file is required"})
		return
	}
	defer file.Close()

	// Validate file extension
	ext := filepath.Ext(header.Filename)
	validExts := map[string]bool{
		".wav": true, ".mp3": true, ".m4a": true,
		".aac": true, ".ogg": true, ".flac": true,
	}
	if !validExts[ext] {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{
			Error: "Invalid audio format. Supported: WAV, MP3, M4A, AAC, OGG, FLAC",
		})
		return
	}

	// Get content type
	contentType := header.Header.Get("Content-Type")
	if contentType == "" {
		contentType = "audio/mpeg" // Default
	}

	// Upload to S3
	fileURL, err := h.storage.UploadFile(c.Request.Context(), file, header.Filename, contentType)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to upload file"})
		return
	}

	// Get form fields
	title := c.PostForm("title")
	description := c.PostForm("description")
	subject := c.PostForm("subject")
	gradeLevel := c.PostForm("grade_level")
	language := c.PostForm("language")
	if language == "" {
		language = "en"
	}

	// Create recording record
	fileSize := header.Size
	recording := &models.Recording{
		UserID:          userID,
		Title:           &title,
		Description:     &description,
		FileURL:         fileURL,
		FileSizeBytes:   &fileSize,
		RecordingType:   "audio",
		Subject:         &subject,
		GradeLevel:      &gradeLevel,
		Language:        language,
		Status:          "pending",
		RecordedAt:      ptrTime(time.Now()),
	}

	if err := h.repo.CreateRecording(c.Request.Context(), recording); err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to create recording"})
		return
	}

	c.JSON(http.StatusCreated, recording)
}

func (h *RecordingHandler) List(c *gin.Context) {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, models.ErrorResponse{Error: "Unauthorized"})
		return
	}

	recordings, err := h.repo.GetRecordingsByUserID(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to get recordings"})
		return
	}

	if recordings == nil {
		recordings = []*models.Recording{}
	}

	c.JSON(http.StatusOK, recordings)
}

func (h *RecordingHandler) Get(c *gin.Context) {
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

	c.JSON(http.StatusOK, recording)
}

func (h *RecordingHandler) Delete(c *gin.Context) {
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

	// Delete from S3
	if err := h.storage.DeleteFile(c.Request.Context(), recording.FileURL); err != nil {
		// Log error but continue with database deletion
		fmt.Printf("Failed to delete file from S3: %v\n", err)
	}

	// Delete from database (cascades to analyses, transcriptions, etc.)
	if err := h.repo.DeleteRecording(c.Request.Context(), recordingID); err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to delete recording"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Recording deleted successfully"})
}

func ptrTime(t time.Time) *time.Time {
	return &t
}
