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
	ID                             uuid.UUID  `json:"id" db:"id"`
	Username                       string     `json:"username" db:"username"`
	Email                          *string    `json:"email,omitempty" db:"email"`
	PasswordHash                   string     `json:"-" db:"password_hash"`
	FirstName                      string     `json:"first_name" db:"first_name"`
	LastName                       string     `json:"last_name" db:"last_name"`
	Role                           string     `json:"role" db:"role"`
	SchoolName                     *string    `json:"school_name,omitempty" db:"school_name"`
	Country                        *string    `json:"country,omitempty" db:"country"`
	LanguagePreference             string     `json:"language_preference" db:"language_preference"`
	FeedbackAudience               string     `json:"feedback_audience" db:"feedback_audience"`
	EmailVerified                  bool       `json:"email_verified" db:"email_verified"`
	EmailVerificationCode          *string    `json:"-" db:"email_verification_code"`
	EmailVerificationCodeExpiresAt *time.Time `json:"-" db:"email_verification_code_expires_at"`
	PasswordResetToken             *string    `json:"-" db:"password_reset_token"`
	PasswordResetTokenExpiresAt    *time.Time `json:"-" db:"password_reset_token_expires_at"`
	CreatedAt                      time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt                      time.Time  `json:"updated_at" db:"updated_at"`
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
	// ObservedTeacherName is set when a coordinator records a lesson taught by
	// someone else. Nil for a teacher recording their own lesson.
	ObservedTeacherName *string `json:"observed_teacher_name,omitempty" db:"observed_teacher_name"`
	Status          string     `json:"status" db:"status"`                           // pending, processing, completed, failed, insufficient_audio
	FailureReason   *string    `json:"failure_reason,omitempty" db:"failure_reason"` // too_short, insufficient_content, service_error, etc.
	ErrorMessage    *string    `json:"error_message,omitempty" db:"error_message"`   // Human-readable error message
	RecordedAt      *time.Time `json:"recorded_at,omitempty" db:"recorded_at"`
	CreatedAt       *time.Time `json:"created_at" db:"created_at"`
	UpdatedAt       *time.Time `json:"updated_at" db:"updated_at"`
}

// Transcription represents the transcribed text from a recording
type Transcription struct {
	ID               uuid.UUID  `json:"id" db:"id"`
	RecordingID      uuid.UUID  `json:"recording_id" db:"recording_id"`
	FullText         string     `json:"full_text" db:"full_text"`
	Segments         JSONBArray `json:"segments" db:"segments"`
	WordCount        *int       `json:"word_count,omitempty" db:"word_count"`
	ConfidenceScore  *float64   `json:"confidence_score,omitempty" db:"confidence_score"`
	LanguageDetected *string    `json:"language_detected,omitempty" db:"language_detected"`
	CreatedAt        time.Time  `json:"created_at" db:"created_at"`
}

// Analysis represents the TEACH framework analysis
type Analysis struct {
	ID              uuid.UUID      `json:"id" db:"id"`
	RecordingID     uuid.UUID      `json:"recording_id" db:"recording_id"`
	TranscriptionID *uuid.UUID     `json:"transcription_id,omitempty" db:"transcription_id"`
	Transcription   *Transcription `json:"transcription,omitempty" db:"-"` // Populated manually

	// Time on Learning
	TimeOnLearning JSONB `json:"time_on_learning" db:"time_on_learning"`

	// Quality of Teaching Practices - 9 Elements
	SupportiveEnvironmentScore     *int  `json:"supportive_environment_score,omitempty" db:"supportive_environment_score"`
	SupportiveEnvironmentBehaviors JSONB `json:"supportive_environment_behaviors" db:"supportive_environment_behaviors"`

	PositiveExpectationsScore     *int  `json:"positive_expectations_score,omitempty" db:"positive_expectations_score"`
	PositiveExpectationsBehaviors JSONB `json:"positive_expectations_behaviors" db:"positive_expectations_behaviors"`

	LessonFacilitationScore     *int  `json:"lesson_facilitation_score,omitempty" db:"lesson_facilitation_score"`
	LessonFacilitationBehaviors JSONB `json:"lesson_facilitation_behaviors" db:"lesson_facilitation_behaviors"`

	ChecksUnderstandingScore     *int  `json:"checks_understanding_score,omitempty" db:"checks_understanding_score"`
	ChecksUnderstandingBehaviors JSONB `json:"checks_understanding_behaviors" db:"checks_understanding_behaviors"`

	FeedbackScore     *int  `json:"feedback_score,omitempty" db:"feedback_score"`
	FeedbackBehaviors JSONB `json:"feedback_behaviors" db:"feedback_behaviors"`

	CriticalThinkingScore     *int  `json:"critical_thinking_score,omitempty" db:"critical_thinking_score"`
	CriticalThinkingBehaviors JSONB `json:"critical_thinking_behaviors" db:"critical_thinking_behaviors"`

	AutonomyScore     *int  `json:"autonomy_score,omitempty" db:"autonomy_score"`
	AutonomyBehaviors JSONB `json:"autonomy_behaviors" db:"autonomy_behaviors"`

	PerseveranceScore     *int  `json:"perseverance_score,omitempty" db:"perseverance_score"`
	PerseveranceBehaviors JSONB `json:"perseverance_behaviors" db:"perseverance_behaviors"`

	SocialCollaborativeScore     *int  `json:"social_collaborative_score,omitempty" db:"social_collaborative_score"`
	SocialCollaborativeBehaviors JSONB `json:"social_collaborative_behaviors" db:"social_collaborative_behaviors"`

	// Overall
	OverallScore *float64 `json:"overall_score,omitempty" db:"overall_score"`

	// Qualitative feedback
	Summary             *string    `json:"summary,omitempty" db:"summary"`
	Strengths           JSONBArray `json:"strengths" db:"strengths"`
	AreasForImprovement JSONBArray `json:"areas_for_improvement" db:"areas_for_improvement"`
	Recommendations     JSONBArray `json:"recommendations" db:"recommendations"`

	// Science of Learning
	ScienceOfLearning JSONB `json:"science_of_learning" db:"science_of_learning"`

	// Metadata
	AIModelUsed      *string   `json:"ai_model_used,omitempty" db:"ai_model_used"`
	ConfidenceScore  *float64  `json:"confidence_score,omitempty" db:"confidence_score"`
	ProcessingTimeMs *int      `json:"processing_time_ms,omitempty" db:"processing_time_ms"`
	CreatedAt        time.Time `json:"created_at" db:"created_at"`
}

// ManualScore is a pedagogy coach's manual scoring of a recording against the
// TEACH framework, kept per (recording, coach). The element score columns mirror
// the analyses table so AI-vs-human comparison is a direct field-by-field mapping.
type ManualScore struct {
	ID          uuid.UUID `json:"id" db:"id"`
	RecordingID uuid.UUID `json:"recording_id" db:"recording_id"`
	ScorerID    uuid.UUID `json:"scorer_id" db:"scorer_id"`

	// TEACH Framework Scores (1-5, nil = not scored / N/A)
	SupportiveEnvironmentScore *int `json:"supportive_environment_score,omitempty" db:"supportive_environment_score"`
	PositiveExpectationsScore  *int `json:"positive_expectations_score,omitempty" db:"positive_expectations_score"`
	LessonFacilitationScore    *int `json:"lesson_facilitation_score,omitempty" db:"lesson_facilitation_score"`
	ChecksUnderstandingScore   *int `json:"checks_understanding_score,omitempty" db:"checks_understanding_score"`
	FeedbackScore              *int `json:"feedback_score,omitempty" db:"feedback_score"`
	CriticalThinkingScore      *int `json:"critical_thinking_score,omitempty" db:"critical_thinking_score"`
	AutonomyScore              *int `json:"autonomy_score,omitempty" db:"autonomy_score"`
	PerseveranceScore          *int `json:"perseverance_score,omitempty" db:"perseverance_score"`
	SocialCollaborativeScore   *int `json:"social_collaborative_score,omitempty" db:"social_collaborative_score"`

	// Per-element rationale text, keyed by element key (e.g. "feedback").
	ElementRationales JSONB `json:"element_rationales" db:"element_rationales"`

	// Overall (computed average of provided element scores) + qualitative feedback.
	OverallScore        *float64  `json:"overall_score,omitempty" db:"overall_score"`
	Summary             *string   `json:"summary,omitempty" db:"summary"`
	Strengths           *string   `json:"strengths,omitempty" db:"strengths"`
	AreasForImprovement *string   `json:"areas_for_improvement,omitempty" db:"areas_for_improvement"`
	Recommendations     *string   `json:"recommendations,omitempty" db:"recommendations"`
	Notes               *string   `json:"notes,omitempty" db:"notes"`
	CreatedAt           time.Time `json:"created_at" db:"created_at"`
	UpdatedAt           time.Time `json:"updated_at" db:"updated_at"`
}

// CoachScript is the seven-block conversation guide a pedagogy coordinator uses
// to discuss one TEACH element with the teacher they observed.
//
// Generated on demand from the stored analysis and then kept, so reopening the
// screen returns the same questions rather than a reworded set. One per
// (recording, coordinator, element).
type CoachScript struct {
	ID            uuid.UUID `json:"id" db:"id"`
	RecordingID   uuid.UUID `json:"recording_id" db:"recording_id"`
	CoordinatorID uuid.UUID `json:"coordinator_id" db:"coordinator_id"`
	ElementKey    string    `json:"element_key" db:"element_key"`
	Language      string    `json:"language" db:"language"`

	// The seven blocks, in the order the coordinator works through them.
	ObservedEvidence  JSONBArray `json:"observed_evidence" db:"observed_evidence"`
	WhatItMeans       *string    `json:"what_it_means,omitempty" db:"what_it_means"`
	CoachQuestion     *string    `json:"coach_question,omitempty" db:"coach_question"`
	FollowUpQuestions JSONBArray `json:"follow_up_questions" db:"follow_up_questions"`
	PossibleModel     *string    `json:"possible_model,omitempty" db:"possible_model"`
	Practice          *string    `json:"practice,omitempty" db:"practice"`
	NextStep          *string    `json:"next_step,omitempty" db:"next_step"`

	AIModelUsed *string   `json:"ai_model_used,omitempty" db:"ai_model_used"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}

// GenerateCoachScriptRequest asks for a script covering one TEACH element.
type GenerateCoachScriptRequest struct {
	ElementKey string `json:"element_key" binding:"required"`
}

// ChatSession represents a coaching chat session
type ChatSession struct {
	ID         uuid.UUID  `json:"id" db:"id"`
	UserID     uuid.UUID  `json:"user_id" db:"user_id"`
	AnalysisID *uuid.UUID `json:"analysis_id,omitempty" db:"analysis_id"`
	CreatedAt  time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt  time.Time  `json:"updated_at" db:"updated_at"`
}

type ChatSessionSummary struct {
	ID         uuid.UUID  `json:"id" db:"id"`
	UserID     uuid.UUID  `json:"user_id" db:"user_id"`
	AnalysisID *uuid.UUID `json:"analysis_id,omitempty" db:"analysis_id"`
	CreatedAt  time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt  time.Time  `json:"updated_at" db:"updated_at"`

	// Computed/Joined fields
	LessonTitle *string `json:"lesson_title,omitempty" db:"lesson_title"`
	Subject     *string `json:"subject,omitempty" db:"subject"`
	GradeLevel  *string `json:"grade_level,omitempty" db:"grade_level"`
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
	Username   string  `json:"username" binding:"required"`
	Email      *string `json:"email,omitempty" binding:"omitempty,email"`
	Password   string  `json:"password" binding:"required,min=8"`
	FirstName  string  `json:"first_name" binding:"required"`
	LastName   string  `json:"last_name" binding:"required"`
	SchoolName *string `json:"school_name,omitempty"`
	Country    *string `json:"country,omitempty"`

	// Role is self-declared at sign-up and accepts ONLY "teacher" or
	// "coordinator" — see SelfAssignableRole. The same column also carries
	// "viewer" and "admin", which grant monitoring-dashboard access, so this
	// value must never be trusted straight through.
	Role string `json:"role,omitempty"`

	LanguagePreference string `json:"language_preference"`
}

// Roles a user may assign themselves at registration.
//
// Deliberately NOT handlers.validRoles: that list is for admin user-management
// and includes "viewer" and "admin", which unlock the World Bank monitoring
// dashboard. Anything outside this set falls back to RoleTeacher.
const (
	RoleTeacher     = "teacher"
	RoleCoordinator = "coordinator"
)

// SelfAssignableRole normalises a self-declared role, defaulting to teacher.
// A caller sending "admin" gets "teacher", not an error — the field is optional
// and unknown values are simply not honoured.
func SelfAssignableRole(role string) string {
	if role == RoleCoordinator {
		return RoleCoordinator
	}
	return RoleTeacher
}

type LoginRequest struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
}

type LoginResponse struct {
	Token string `json:"token"`
	User  User   `json:"user"`
}

type UpdateProfileRequest struct {
	FirstName          *string `json:"first_name,omitempty"`
	LastName           *string `json:"last_name,omitempty"`
	Email              *string `json:"email,omitempty"`
	SchoolName         *string `json:"school_name,omitempty"`
	Country            *string `json:"country,omitempty"`
	LanguagePreference *string `json:"language_preference,omitempty"`
	// FeedbackAudience is "teacher" or "coordinator"; anything else is rejected.
	FeedbackAudience *string `json:"feedback_audience,omitempty"`
}

type AnalyzeRequest struct {
	RecordingID uuid.UUID `json:"recording_id" binding:"required"`
}

// ManualScoreRequest is the payload a coach submits to save a manual scoring.
// Every score is optional; any provided value must be 1-5. overall_score is
// computed server-side, so it is not part of this request.
type ManualScoreRequest struct {
	SupportiveEnvironmentScore *int `json:"supportive_environment_score" binding:"omitempty,min=1,max=5"`
	PositiveExpectationsScore  *int `json:"positive_expectations_score" binding:"omitempty,min=1,max=5"`
	LessonFacilitationScore    *int `json:"lesson_facilitation_score" binding:"omitempty,min=1,max=5"`
	ChecksUnderstandingScore   *int `json:"checks_understanding_score" binding:"omitempty,min=1,max=5"`
	FeedbackScore              *int `json:"feedback_score" binding:"omitempty,min=1,max=5"`
	CriticalThinkingScore      *int `json:"critical_thinking_score" binding:"omitempty,min=1,max=5"`
	AutonomyScore              *int `json:"autonomy_score" binding:"omitempty,min=1,max=5"`
	PerseveranceScore          *int `json:"perseverance_score" binding:"omitempty,min=1,max=5"`
	SocialCollaborativeScore   *int `json:"social_collaborative_score" binding:"omitempty,min=1,max=5"`

	ElementRationales   map[string]string `json:"element_rationales"`
	Summary             *string           `json:"summary"`
	Strengths           *string           `json:"strengths"`
	AreasForImprovement *string           `json:"areas_for_improvement"`
	Recommendations     *string           `json:"recommendations"`
	Notes               *string           `json:"notes"`
}

type SendMessageRequest struct {
	Content string `json:"content" binding:"required"`
}

type VerifyEmailRequest struct {
	Email string `json:"email" binding:"required,email"`
	Code  string `json:"code" binding:"required,len=6"`
}

type ResendVerificationRequest struct {
	Email string `json:"email" binding:"required,email"`
}

type ForgotPasswordRequest struct {
	Email string `json:"email" binding:"required,email"`
}

type ResetPasswordRequest struct {
	Token       string `json:"token" binding:"required"`
	NewPassword string `json:"new_password" binding:"required,min=8"`
}

type ErrorResponse struct {
	Error string `json:"error"`
}

type SuccessResponse struct {
	Message string `json:"message"`
}

// ---------------------------------------------------------------------------
// Admin / monitoring DTOs (World Bank dashboard)
// ---------------------------------------------------------------------------

// LessonLogFilters captures the drill-down filters for the consolidated lesson
// log. Empty string fields mean "no filter".
type LessonLogFilters struct {
	Country   string
	School    string
	Grade     string
	Subject   string
	Status    string
	TeacherID string
	StartDate *time.Time
	EndDate   *time.Time
}

// Pagination controls page/size/sort for paginated admin queries.
type Pagination struct {
	Page     int
	PageSize int
	Sort     string // created_at_desc (default), created_at_asc, duration_desc, score_desc
}

// LessonLogRow is one row of the consolidated lesson log: a recording joined to
// its teacher and (optionally) its analysis.
type LessonLogRow struct {
	RecordingID     uuid.UUID  `json:"recording_id"`
	Title           *string    `json:"title,omitempty"`
	Subject         *string    `json:"subject,omitempty"`
	GradeLevel      *string    `json:"grade_level,omitempty"`
	Language        string     `json:"language"`
	Status          string     `json:"status"`
	DurationSeconds *int       `json:"duration_seconds,omitempty"`
	CreatedAt       *time.Time `json:"created_at"`
	TeacherID uuid.UUID `json:"teacher_id"`

	// TeacherName is whoever TAUGHT the lesson: the observed teacher when a
	// coordinator recorded it, otherwise the account holder.
	TeacherName     string `json:"teacher_name"`
	TeacherUsername string `json:"teacher_username"`

	// ObservedTeacherName is set only when a coordinator recorded the lesson.
	ObservedTeacherName *string `json:"observed_teacher_name,omitempty"`

	// RecordedByName / RecordedByRole identify the account that made the
	// recording, so the dashboard can distinguish a teacher's own lesson from a
	// coordinator's observation of someone else's.
	RecordedByName string `json:"recorded_by_name"`
	RecordedByRole string `json:"recorded_by_role"`
	SchoolName      *string    `json:"school_name,omitempty"`
	Country         *string    `json:"country,omitempty"`
	HasAnalysis     bool       `json:"has_analysis"`
	OverallScore    *float64   `json:"overall_score,omitempty"`
}

// LessonLogResult is a paginated page of the lesson log.
type LessonLogResult struct {
	Rows     []*LessonLogRow `json:"rows"`
	Total    int             `json:"total"`
	Page     int             `json:"page"`
	PageSize int             `json:"page_size"`
}

// AdminOverview holds the headline counts shown on the dashboard overview.
type AdminOverview struct {
	TotalTeachers     int `json:"total_teachers"`
	TotalSchools      int `json:"total_schools"`
	TotalCountries    int `json:"total_countries"`
	TotalRecordings   int `json:"total_recordings"`
	TotalAnalyses     int `json:"total_analyses"`
	ActiveTeachers7d  int `json:"active_teachers_7d"`
	ActiveTeachers30d int `json:"active_teachers_30d"`
}

// SchoolUsageRow aggregates adoption/usage per school (within a country).
type SchoolUsageRow struct {
	Country        *string    `json:"country,omitempty"`
	SchoolName     *string    `json:"school_name,omitempty"`
	TeacherCount   int        `json:"teacher_count"`
	RecordingCount int        `json:"recording_count"`
	LastRecording  *time.Time `json:"last_recording,omitempty"`
}

// TeacherRosterRow is one teacher with their activity summary.
type TeacherRosterRow struct {
	ID             uuid.UUID  `json:"id"`
	FirstName      string     `json:"first_name"`
	LastName       string     `json:"last_name"`
	Username       string     `json:"username"`
	Email          *string    `json:"email,omitempty"`
	SchoolName     *string    `json:"school_name,omitempty"`
	Country        *string    `json:"country,omitempty"`
	RecordingCount int        `json:"recording_count"`
	LastActivity   *time.Time `json:"last_activity,omitempty"`
	CreatedAt      time.Time  `json:"created_at"`
}

// UserAdminRow is one user with their role + activity summary, for the admin
// user-management screen.
type UserAdminRow struct {
	ID             uuid.UUID  `json:"id"`
	FirstName      string     `json:"first_name"`
	LastName       string     `json:"last_name"`
	Username       string     `json:"username"`
	Email          *string    `json:"email,omitempty"`
	Role           string     `json:"role"`
	SchoolName     *string    `json:"school_name,omitempty"`
	Country        *string    `json:"country,omitempty"`
	RecordingCount int        `json:"recording_count"`
	LastActivity   *time.Time `json:"last_activity,omitempty"`
	CreatedAt      time.Time  `json:"created_at"`
}

// UpdateRoleRequest is the body for changing a user's role.
type UpdateRoleRequest struct {
	Role string `json:"role" binding:"required"`
}

// SchoolOption pairs a school with its country for cascading filter dropdowns.
type SchoolOption struct {
	Country string `json:"country"`
	School  string `json:"school"`
}

// AdminFilterOptions provides the distinct values that populate the dashboard
// filter dropdowns.
type AdminFilterOptions struct {
	Countries []string       `json:"countries"`
	Schools   []SchoolOption `json:"schools"`
	Grades    []string       `json:"grades"`
	Subjects  []string       `json:"subjects"`
	Statuses  []string       `json:"statuses"`
}
