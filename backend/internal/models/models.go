package models

import (
	"database/sql/driver"
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

// JSONB is a custom type for PostgreSQL JSONB fields
type JSONB map[string]interface{}

func (j JSONB) Value() (driver.Value, error) {
	return json.Marshal(j)
}

func (j *JSONB) Scan(value interface{}) error {
	if value == nil {
		*j = make(JSONB)
		return nil
	}
	bytes, ok := value.([]byte)
	if !ok {
		return nil
	}
	return json.Unmarshal(bytes, j)
}

// JSONBArray is a custom type for PostgreSQL JSONB arrays
type JSONBArray []interface{}

func (j JSONBArray) Value() (driver.Value, error) {
	return json.Marshal(j)
}

func (j *JSONBArray) Scan(value interface{}) error {
	if value == nil {
		*j = make(JSONBArray, 0)
		return nil
	}
	bytes, ok := value.([]byte)
	if !ok {
		return nil
	}
	return json.Unmarshal(bytes, j)
}

// User represents a teacher user
type User struct {
	ID                 uuid.UUID  `json:"id" db:"id"`
	Email              string     `json:"email" db:"email"`
	PasswordHash       string     `json:"-" db:"password_hash"`
	FirstName          string     `json:"first_name" db:"first_name"`
	LastName           string     `json:"last_name" db:"last_name"`
	Role               string     `json:"role" db:"role"`
	SchoolName         *string    `json:"school_name,omitempty" db:"school_name"`
	Country            *string    `json:"country,omitempty" db:"country"`
	LanguagePreference string     `json:"language_preference" db:"language_preference"`
	CreatedAt          time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt          time.Time  `json:"updated_at" db:"updated_at"`
}

// Recording represents an audio recording of a lesson
type Recording struct {
	ID              uuid.UUID  `json:"id" db:"id"`
	UserID          uuid.UUID  `json:"user_id" db:"user_id"`
	Title           *string    `json:"title,omitempty" db:"title"`
	Description     *string    `json:"description,omitempty" db:"description"`
	FileURL         string     `json:"file_url" db:"file_url"`
	FileSizeBytes   *int64     `json:"file_size_bytes,omitempty" db:"file_size_bytes"`
	DurationSeconds *int       `json:"duration_seconds,omitempty" db:"duration_seconds"`
	RecordingType   string     `json:"recording_type" db:"recording_type"`
	Subject         *string    `json:"subject,omitempty" db:"subject"`
	GradeLevel      *string    `json:"grade_level,omitempty" db:"grade_level"`
	Language        string     `json:"language" db:"language"`
	Status          string     `json:"status" db:"status"`
	RecordedAt      *time.Time `json:"recorded_at,omitempty" db:"recorded_at"`
	CreatedAt       time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at" db:"updated_at"`
}

// Transcription represents the transcribed text from a recording
type Transcription struct {
	ID               uuid.UUID   `json:"id" db:"id"`
	RecordingID      uuid.UUID   `json:"recording_id" db:"recording_id"`
	FullText         string      `json:"full_text" db:"full_text"`
	Segments         JSONBArray  `json:"segments" db:"segments"`
	WordCount        *int        `json:"word_count,omitempty" db:"word_count"`
	ConfidenceScore  *float64    `json:"confidence_score,omitempty" db:"confidence_score"`
	LanguageDetected *string     `json:"language_detected,omitempty" db:"language_detected"`
	CreatedAt        time.Time   `json:"created_at" db:"created_at"`
}

// Analysis represents the TEACH framework analysis
type Analysis struct {
	ID                           uuid.UUID   `json:"id" db:"id"`
	RecordingID                  uuid.UUID   `json:"recording_id" db:"recording_id"`
	TranscriptionID              *uuid.UUID  `json:"transcription_id,omitempty" db:"transcription_id"`
	Transcription                *Transcription `json:"transcription,omitempty" db:"-"` // Populated manually
	
	// Time on Learning
	TimeOnLearning               JSONB       `json:"time_on_learning" db:"time_on_learning"`
	
	// Quality of Teaching Practices - 9 Elements
	SupportiveEnvironmentScore   *int        `json:"supportive_environment_score,omitempty" db:"supportive_environment_score"`
	SupportiveEnvironmentBehaviors JSONB     `json:"supportive_environment_behaviors" db:"supportive_environment_behaviors"`
	
	PositiveExpectationsScore    *int        `json:"positive_expectations_score,omitempty" db:"positive_expectations_score"`
	PositiveExpectationsBehaviors JSONB      `json:"positive_expectations_behaviors" db:"positive_expectations_behaviors"`
	
	LessonFacilitationScore      *int        `json:"lesson_facilitation_score,omitempty" db:"lesson_facilitation_score"`
	LessonFacilitationBehaviors  JSONB       `json:"lesson_facilitation_behaviors" db:"lesson_facilitation_behaviors"`
	
	ChecksUnderstandingScore     *int        `json:"checks_understanding_score,omitempty" db:"checks_understanding_score"`
	ChecksUnderstandingBehaviors JSONB       `json:"checks_understanding_behaviors" db:"checks_understanding_behaviors"`
	
	FeedbackScore                *int        `json:"feedback_score,omitempty" db:"feedback_score"`
	FeedbackBehaviors            JSONB       `json:"feedback_behaviors" db:"feedback_behaviors"`
	
	CriticalThinkingScore        *int        `json:"critical_thinking_score,omitempty" db:"critical_thinking_score"`
	CriticalThinkingBehaviors    JSONB       `json:"critical_thinking_behaviors" db:"critical_thinking_behaviors"`
	
	AutonomyScore                *int        `json:"autonomy_score,omitempty" db:"autonomy_score"`
	AutonomyBehaviors            JSONB       `json:"autonomy_behaviors" db:"autonomy_behaviors"`
	
	PerseveranceScore            *int        `json:"perseverance_score,omitempty" db:"perseverance_score"`
	PerseveranceBehaviors        JSONB       `json:"perseverance_behaviors" db:"perseverance_behaviors"`
	
	SocialCollaborativeScore     *int        `json:"social_collaborative_score,omitempty" db:"social_collaborative_score"`
	SocialCollaborativeBehaviors JSONB       `json:"social_collaborative_behaviors" db:"social_collaborative_behaviors"`
	
	// Overall
	OverallScore                 *float64    `json:"overall_score,omitempty" db:"overall_score"`
	
	// Qualitative feedback
	Summary                      *string     `json:"summary,omitempty" db:"summary"`
	Strengths                    JSONBArray  `json:"strengths" db:"strengths"`
	AreasForImprovement          JSONBArray  `json:"areas_for_improvement" db:"areas_for_improvement"`
	Recommendations              JSONBArray  `json:"recommendations" db:"recommendations"`
	
	// Metadata
	AIModelUsed                  *string     `json:"ai_model_used,omitempty" db:"ai_model_used"`
	ConfidenceScore              *float64    `json:"confidence_score,omitempty" db:"confidence_score"`
	ProcessingTimeMs             *int        `json:"processing_time_ms,omitempty" db:"processing_time_ms"`
	CreatedAt                    time.Time   `json:"created_at" db:"created_at"`
}

// ChatSession represents a coaching chat session
type ChatSession struct {
	ID         uuid.UUID  `json:"id" db:"id"`
	UserID     uuid.UUID  `json:"user_id" db:"user_id"`
	AnalysisID *uuid.UUID `json:"analysis_id,omitempty" db:"analysis_id"`
	CreatedAt  time.Time  `json:"created_at" db:"created_at"`
}

// ChatMessage represents a message in a chat session
type ChatMessage struct {
	ID        uuid.UUID `json:"id" db:"id"`
	SessionID uuid.UUID `json:"session_id" db:"session_id"`
	Role      string    `json:"role" db:"role"` // 'user' or 'assistant'
	Content   string    `json:"content" db:"content"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
}

// ProgressSnapshot represents progress tracking over time
type ProgressSnapshot struct {
	ID                     uuid.UUID `json:"id" db:"id"`
	UserID                 uuid.UUID `json:"user_id" db:"user_id"`
	PeriodStart            time.Time `json:"period_start" db:"period_start"`
	PeriodEnd              time.Time `json:"period_end" db:"period_end"`
	TotalRecordings        int       `json:"total_recordings" db:"total_recordings"`
	AverageOverallScore    *float64  `json:"average_overall_score,omitempty" db:"average_overall_score"`
	AverageScoresByElement JSONB     `json:"average_scores_by_element" db:"average_scores_by_element"`
	ImprovementTrend       *float64  `json:"improvement_trend,omitempty" db:"improvement_trend"`
	CreatedAt              time.Time `json:"created_at" db:"created_at"`
}

// Request/Response DTOs

type RegisterRequest struct {
	Email              string  `json:"email" binding:"required,email"`
	Password           string  `json:"password" binding:"required,min=8"`
	FirstName          string  `json:"first_name" binding:"required"`
	LastName           string  `json:"last_name" binding:"required"`
	SchoolName         *string `json:"school_name,omitempty"`
	Country            *string `json:"country,omitempty"`
	LanguagePreference string  `json:"language_preference"`
}

type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

type LoginResponse struct {
	Token string `json:"token"`
	User  User   `json:"user"`
}

type UpdateProfileRequest struct {
	FirstName          *string `json:"first_name,omitempty"`
	LastName           *string `json:"last_name,omitempty"`
	SchoolName         *string `json:"school_name,omitempty"`
	Country            *string `json:"country,omitempty"`
	LanguagePreference *string `json:"language_preference,omitempty"`
}

type AnalyzeRequest struct {
	RecordingID uuid.UUID `json:"recording_id" binding:"required"`
}

type SendMessageRequest struct {
	Content string `json:"content" binding:"required"`
}

type ErrorResponse struct {
	Error string `json:"error"`
}
