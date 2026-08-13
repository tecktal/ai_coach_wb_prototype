package handlers

import (
	"bytes"
	"fmt"
	"io"
	"log"
	"net/http"
	"path/filepath"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/worldbank/ai-coach/backend/internal/middleware"
	"github.com/worldbank/ai-coach/backend/internal/models"
	"github.com/worldbank/ai-coach/backend/internal/repository"
	"github.com/worldbank/ai-coach/backend/internal/services/googledrive"
	"github.com/worldbank/ai-coach/backend/internal/services/storage"
)

type RecordingHandler struct {
	repo    *repository.Repository
	storage *storage.S3Service
	drive   *googledrive.DriveService
}

func NewRecordingHandler(repo *repository.Repository, storage *storage.S3Service, drive *googledrive.DriveService) *RecordingHandler {
	return &RecordingHandler{
		repo:    repo,
		storage: storage,
		drive:   drive,
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
		log.Printf("[Upload] FormFile error for user %s: %v", userID, err)
		c.JSON(http.StatusBadRequest, models.ErrorResponse{Error: "Audio file is required"})
		return
	}
	defer file.Close()

	// Read file into memory for both S3 and Drive uploads
	fileData, err := io.ReadAll(file)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to read file"})
		return
	}

	// Validate file extension
	ext := filepath.Ext(header.Filename)
	validExts := map[string]bool{
		".wav": true, ".mp3": true, ".m4a": true,
		".aac": true, ".ogg": true, ".flac": true,
	}
	if !validExts[ext] {
		log.Printf("[Upload] Invalid extension '%s' from user %s (filename: %s)", ext, userID, header.Filename)
		c.JSON(http.StatusBadRequest, models.ErrorResponse{
			Error: "Invalid audio format. Supported: WAV, MP3, M4A, AAC, OGG, FLAC",
		})
		return
	}
	log.Printf("[Upload] Received file '%s' (%.2f MB) from user %s", header.Filename, float64(header.Size)/(1024*1024), userID)

	// Get content type
	contentType := header.Header.Get("Content-Type")
	if contentType == "" {
		contentType = "audio/mpeg" // Default
	}

	// Upload to S3
	fileURL, err := h.storage.UploadFile(c.Request.Context(), bytes.NewReader(fileData), header.Filename, contentType)
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

	// Set when a coordinator records a lesson someone else taught. Absent for a
	// teacher recording their own, so store NULL rather than an empty string.
	var observedTeacherName *string
	if v := c.PostForm("observed_teacher_name"); v != "" {
		observedTeacherName = &v
	}

	// Get duration if provided
	var duration *int
	durationStr := c.PostForm("duration_seconds")
	if durationStr != "" {
		var d int
		if _, err := fmt.Sscanf(durationStr, "%d", &d); err == nil {
			duration = &d
		}
	}

	// Create recording record
	fileSize := header.Size
	recording := &models.Recording{
		UserID:              userID,
		Title:               &title,
		Description:         &description,
		FileURL:             fileURL,
		FileSizeBytes:       &fileSize,
		DurationSeconds:     duration,
		RecordingType:       "audio",
		Subject:             &subject,
		GradeLevel:          &gradeLevel,
		Language:            language,
		ObservedTeacherName: observedTeacherName,
		Status:              "pending",
		RecordedAt:          ptrTime(time.Now()),
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
		fmt.Printf("Error getting recordings: %v\n", err)
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to get recordings"})
		return
	}

	if recordings == nil {
		recordings = []*models.Recording{}
	}

	for _, r := range recordings {
		h.enrichRecordingURL(c, r)
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

	h.enrichRecordingURL(c, recording)

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

func (h *RecordingHandler) Stream(c *gin.Context) {
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

	// Get range header
	rangeHeader := c.GetHeader("Range")

	// Get stream from S3
	reader, contentType, contentLength, contentRange, err := h.storage.GetFileStream(c.Request.Context(), recording.FileURL, rangeHeader)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{Error: "Failed to stream file"})
		return
	}
	defer reader.Close()

	c.Header("Content-Type", contentType)
	c.Header("Accept-Ranges", "bytes")
	c.Header("Content-Length", fmt.Sprintf("%d", contentLength))

	// A 206 must carry Content-Range or browsers reject it (breaks playback).
	if rangeHeader != "" && contentRange != "" {
		c.Header("Content-Range", contentRange)
		c.Status(http.StatusPartialContent)
	} else {
		c.Status(http.StatusOK)
	}

	c.Header("Content-Disposition", fmt.Sprintf("inline; filename=\"%s\"", filepath.Base(recording.FileURL)))

	_, err = io.Copy(c.Writer, reader)
	if err != nil {
		// Cannot write JSON error here as headers might be sent
		fmt.Printf("Error streaming file: %v\n", err)
	}
}

// subscribeToStreamURL updates the FileURL to point to the proxy stream endpoint
func (h *RecordingHandler) enrichRecordingURL(c *gin.Context, r *models.Recording) {
	if r.FileURL != "" {
		scheme := "http"
		if c.Request.TLS != nil || c.Request.Header.Get("X-Forwarded-Proto") == "https" {
			scheme = "https"
		}
		r.FileURL = fmt.Sprintf("%s://%s/api/v1/recordings/%s/audio", scheme, c.Request.Host, r.ID)
	}
}

func ptrTime(t time.Time) *time.Time {
	return &t
}
