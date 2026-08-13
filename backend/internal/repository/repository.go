package repository

import (
	"context"
	"database/sql"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/worldbank/ai-coach/backend/internal/models"
)

type Repository struct {
	db interface {
		QueryRowContext(ctx context.Context, query string, args ...interface{}) *sql.Row
		QueryContext(ctx context.Context, query string, args ...interface{}) (*sql.Rows, error)
		ExecContext(ctx context.Context, query string, args ...interface{}) (sql.Result, error)
	}
}

func NewRepository(db interface {
	QueryRowContext(ctx context.Context, query string, args ...interface{}) *sql.Row
	QueryContext(ctx context.Context, query string, args ...interface{}) (*sql.Rows, error)
	ExecContext(ctx context.Context, query string, args ...interface{}) (sql.Result, error)
}) *Repository {
	return &Repository{db: db}
}

// User operations

func (r *Repository) CreateUser(ctx context.Context, user *models.User) error {
	query := `
		INSERT INTO users (username, email, password_hash, first_name, last_name, school_name, country,
		                   language_preference, role, feedback_audience)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		RETURNING id, created_at, updated_at
	`
	return r.db.QueryRowContext(ctx, query,
		user.Username, user.Email, user.PasswordHash, user.FirstName, user.LastName,
		user.SchoolName, user.Country, user.LanguagePreference,
		user.Role, user.FeedbackAudience,
	).Scan(&user.ID, &user.CreatedAt, &user.UpdatedAt)
}

func (r *Repository) GetUserByUsername(ctx context.Context, username string) (*models.User, error) {
	user := &models.User{}
	query := `
		SELECT id, username, email, password_hash, first_name, last_name, role, school_name, country,
		       language_preference, COALESCE(feedback_audience, 'teacher'), email_verified, created_at, updated_at
		FROM users WHERE username = $1
	`
	err := r.db.QueryRowContext(ctx, query, username).Scan(
		&user.ID, &user.Username, &user.Email, &user.PasswordHash, &user.FirstName, &user.LastName,
		&user.Role, &user.SchoolName, &user.Country, &user.LanguagePreference,
		&user.FeedbackAudience, &user.EmailVerified, &user.CreatedAt, &user.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return user, err
}

func (r *Repository) GetUserByEmail(ctx context.Context, email string) (*models.User, error) {
	user := &models.User{}
	query := `
		SELECT id, username, email, password_hash, first_name, last_name, role, school_name, country,
		       language_preference, COALESCE(feedback_audience, 'teacher'), email_verified, created_at, updated_at
		FROM users WHERE email = $1
	`
	err := r.db.QueryRowContext(ctx, query, email).Scan(
		&user.ID, &user.Username, &user.Email, &user.PasswordHash, &user.FirstName, &user.LastName,
		&user.Role, &user.SchoolName, &user.Country, &user.LanguagePreference,
		&user.FeedbackAudience, &user.EmailVerified, &user.CreatedAt, &user.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return user, err
}

func (r *Repository) GetUserByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
	user := &models.User{}
	query := `
		SELECT id, username, email, password_hash, first_name, last_name, role, school_name, country,
		       language_preference, COALESCE(feedback_audience, 'teacher'), email_verified, created_at, updated_at
		FROM users WHERE id = $1
	`
	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&user.ID, &user.Username, &user.Email, &user.PasswordHash, &user.FirstName, &user.LastName,
		&user.Role, &user.SchoolName, &user.Country, &user.LanguagePreference,
		&user.FeedbackAudience, &user.EmailVerified, &user.CreatedAt, &user.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return user, err
}

func (r *Repository) UpdateUser(ctx context.Context, user *models.User) error {
	query := `
		UPDATE users
		SET first_name = $1, last_name = $2, school_name = $3, country = $4,
		    language_preference = $5, feedback_audience = $6, updated_at = CURRENT_TIMESTAMP
		WHERE id = $7
	`
	_, err := r.db.ExecContext(ctx, query,
		user.FirstName, user.LastName, user.SchoolName, user.Country,
		user.LanguagePreference, user.FeedbackAudience, user.ID,
	)
	return err
}

func (r *Repository) SetEmailVerificationCode(ctx context.Context, email, code string, expiresAt time.Time) error {
	query := `
		UPDATE users 
		SET email_verification_code = $1, email_verification_code_expires_at = $2, updated_at = CURRENT_TIMESTAMP
		WHERE email = $3
	`
	_, err := r.db.ExecContext(ctx, query, code, expiresAt, email)
	return err
}

func (r *Repository) VerifyEmail(ctx context.Context, email, code string) error {
	query := `
		UPDATE users 
		SET email_verified = TRUE, email_verification_code = NULL, email_verification_code_expires_at = NULL, updated_at = CURRENT_TIMESTAMP
		WHERE email = $1 AND email_verification_code = $2 AND email_verification_code_expires_at > NOW()
	`
	result, err := r.db.ExecContext(ctx, query, email, code)
	if err != nil {
		return err
	}

	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}

	if rows == 0 {
		return sql.ErrNoRows // Code invalid or expired
	}

	return nil
}

func (r *Repository) SetPasswordResetToken(ctx context.Context, email, token string, expiresAt time.Time) error {
	query := `
		UPDATE users 
		SET password_reset_token = $1, password_reset_token_expires_at = $2, updated_at = CURRENT_TIMESTAMP
		WHERE email = $3
	`
	_, err := r.db.ExecContext(ctx, query, token, expiresAt, email)
	return err
}

func (r *Repository) GetUserByResetToken(ctx context.Context, token string) (*models.User, error) {
	user := &models.User{}
	query := `
		SELECT id, username, email, password_hash, first_name, last_name, role, school_name, country,
		       language_preference, COALESCE(feedback_audience, 'teacher'), email_verified, created_at, updated_at
		FROM users 
		WHERE password_reset_token = $1 AND password_reset_token_expires_at > NOW()
	`
	err := r.db.QueryRowContext(ctx, query, token).Scan(
		&user.ID, &user.Username, &user.Email, &user.PasswordHash, &user.FirstName, &user.LastName,
		&user.Role, &user.SchoolName, &user.Country, &user.LanguagePreference,
		&user.FeedbackAudience, &user.EmailVerified, &user.CreatedAt, &user.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return user, err
}

func (r *Repository) UpdatePassword(ctx context.Context, userID uuid.UUID, passwordHash string) error {
	query := `
		UPDATE users 
		SET password_hash = $1, password_reset_token = NULL, password_reset_token_expires_at = NULL, updated_at = CURRENT_TIMESTAMP
		WHERE id = $2
	`
	_, err := r.db.ExecContext(ctx, query, passwordHash, userID)
	return err
}

// Recording operations

func (r *Repository) CreateRecording(ctx context.Context, recording *models.Recording) error {
	query := `
		INSERT INTO recordings (user_id, title, description, file_url, file_size_bytes, duration_seconds,
		                        recording_type, subject, grade_level, language, observed_teacher_name,
		                        status, recorded_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
		RETURNING id, created_at, updated_at
	`
	return r.db.QueryRowContext(ctx, query,
		recording.UserID, recording.Title, recording.Description, recording.FileURL,
		recording.FileSizeBytes, recording.DurationSeconds, recording.RecordingType,
		recording.Subject, recording.GradeLevel, recording.Language,
		recording.ObservedTeacherName, recording.Status,
		recording.RecordedAt,
	).Scan(&recording.ID, &recording.CreatedAt, &recording.UpdatedAt)
}

func (r *Repository) GetRecordingByID(ctx context.Context, id uuid.UUID) (*models.Recording, error) {
	recording := &models.Recording{}
	query := `
		SELECT id, user_id, title, description, file_url, file_size_bytes, duration_seconds,
		       recording_type, subject, grade_level, language, observed_teacher_name,
		       status, failure_reason, error_message, 
		       recorded_at, created_at, updated_at
		FROM recordings WHERE id = $1
	`
	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&recording.ID, &recording.UserID, &recording.Title, &recording.Description,
		&recording.FileURL, &recording.FileSizeBytes, &recording.DurationSeconds,
		&recording.RecordingType, &recording.Subject, &recording.GradeLevel,
		&recording.Language, &recording.ObservedTeacherName,
		&recording.Status, &recording.FailureReason, &recording.ErrorMessage,
		&recording.RecordedAt, &recording.CreatedAt, &recording.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return recording, err
}

func (r *Repository) GetRecordingsByUserID(ctx context.Context, userID uuid.UUID) ([]*models.Recording, error) {
	query := `
		SELECT id, user_id, title, description, file_url, file_size_bytes, duration_seconds,
		       recording_type, subject, grade_level, language, observed_teacher_name,
		       status, failure_reason, error_message,
		       recorded_at, created_at, updated_at
		FROM recordings 
		WHERE user_id = $1
		ORDER BY created_at DESC
	`
	rows, err := r.db.QueryContext(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var recordings []*models.Recording
	for rows.Next() {
		recording := &models.Recording{}
		err := rows.Scan(
			&recording.ID, &recording.UserID, &recording.Title, &recording.Description,
			&recording.FileURL, &recording.FileSizeBytes, &recording.DurationSeconds,
			&recording.RecordingType, &recording.Subject, &recording.GradeLevel,
			&recording.Language, &recording.ObservedTeacherName,
			&recording.Status, &recording.FailureReason, &recording.ErrorMessage,
			&recording.RecordedAt, &recording.CreatedAt, &recording.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		recordings = append(recordings, recording)
	}
	return recordings, rows.Err()
}

func (r *Repository) UpdateRecordingStatus(ctx context.Context, id uuid.UUID, status string) error {
	query := `UPDATE recordings SET status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2`
	_, err := r.db.ExecContext(ctx, query, status, id)
	return err
}

func (r *Repository) UpdateRecordingStatusWithFailure(ctx context.Context, id uuid.UUID, status string, failureReason string, errorMessage string) error {
	query := `
		UPDATE recordings 
		SET status = $1, failure_reason = $2, error_message = $3, updated_at = CURRENT_TIMESTAMP 
		WHERE id = $4
	`
	_, err := r.db.ExecContext(ctx, query, status, failureReason, errorMessage, id)
	return err
}

func (r *Repository) DeleteRecording(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM recordings WHERE id = $1`
	_, err := r.db.ExecContext(ctx, query, id)
	return err
}

func (r *Repository) GetRecordingCountByUserID(ctx context.Context, userID uuid.UUID) (int, error) {
	var count int
	query := `SELECT COUNT(*) FROM recordings WHERE user_id = $1`
	err := r.db.QueryRowContext(ctx, query, userID).Scan(&count)
	return count, err
}

// Transcription operations

func (r *Repository) CreateTranscription(ctx context.Context, transcription *models.Transcription) error {
	query := `
		INSERT INTO transcriptions (recording_id, full_text, segments, word_count, confidence_score, language_detected)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, created_at
	`
	return r.db.QueryRowContext(ctx, query,
		transcription.RecordingID, transcription.FullText, transcription.Segments,
		transcription.WordCount, transcription.ConfidenceScore, transcription.LanguageDetected,
	).Scan(&transcription.ID, &transcription.CreatedAt)
}

func (r *Repository) GetTranscriptionByID(ctx context.Context, id uuid.UUID) (*models.Transcription, error) {
	transcription := &models.Transcription{}
	query := `
		SELECT id, recording_id, full_text, segments, word_count, confidence_score, language_detected, created_at
		FROM transcriptions WHERE id = $1
	`
	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&transcription.ID, &transcription.RecordingID, &transcription.FullText, &transcription.Segments,
		&transcription.WordCount, &transcription.ConfidenceScore, &transcription.LanguageDetected,
		&transcription.CreatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return transcription, err
}

// Analysis operations

func (r *Repository) CreateAnalysis(ctx context.Context, analysis *models.Analysis) error {
	query := `
		INSERT INTO analyses (
			recording_id, transcription_id, time_on_learning, science_of_learning,
			supportive_environment_score, supportive_environment_behaviors,
			positive_expectations_score, positive_expectations_behaviors,
			lesson_facilitation_score, lesson_facilitation_behaviors,
			checks_understanding_score, checks_understanding_behaviors,
			feedback_score, feedback_behaviors,
			critical_thinking_score, critical_thinking_behaviors,
			autonomy_score, autonomy_behaviors,
			perseverance_score, perseverance_behaviors,
			social_collaborative_score, social_collaborative_behaviors,
			overall_score, summary, strengths, areas_for_improvement, recommendations,
			ai_model_used, confidence_score, processing_time_ms
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21,
			$22, $23, $24, $25, $26, $27, $28, $29, $30
		)
		RETURNING id, created_at
	`
	return r.db.QueryRowContext(ctx, query,
		analysis.RecordingID, analysis.TranscriptionID, analysis.TimeOnLearning, analysis.ScienceOfLearning,
		analysis.SupportiveEnvironmentScore, analysis.SupportiveEnvironmentBehaviors,
		analysis.PositiveExpectationsScore, analysis.PositiveExpectationsBehaviors,
		analysis.LessonFacilitationScore, analysis.LessonFacilitationBehaviors,
		analysis.ChecksUnderstandingScore, analysis.ChecksUnderstandingBehaviors,
		analysis.FeedbackScore, analysis.FeedbackBehaviors,
		analysis.CriticalThinkingScore, analysis.CriticalThinkingBehaviors,
		analysis.AutonomyScore, analysis.AutonomyBehaviors,
		analysis.PerseveranceScore, analysis.PerseveranceBehaviors,
		analysis.SocialCollaborativeScore, analysis.SocialCollaborativeBehaviors,
		analysis.OverallScore, analysis.Summary, analysis.Strengths,
		analysis.AreasForImprovement, analysis.Recommendations,
		analysis.AIModelUsed, analysis.ConfidenceScore, analysis.ProcessingTimeMs,
	).Scan(&analysis.ID, &analysis.CreatedAt)
}

func (r *Repository) GetAnalysisByID(ctx context.Context, id uuid.UUID) (*models.Analysis, error) {
	analysis := &models.Analysis{}
	query := `
		SELECT id, recording_id, transcription_id, time_on_learning, science_of_learning,
		       supportive_environment_score, supportive_environment_behaviors,
		       positive_expectations_score, positive_expectations_behaviors,
		       lesson_facilitation_score, lesson_facilitation_behaviors,
		       checks_understanding_score, checks_understanding_behaviors,
		       feedback_score, feedback_behaviors,
		       critical_thinking_score, critical_thinking_behaviors,
		       autonomy_score, autonomy_behaviors,
		       perseverance_score, perseverance_behaviors,
		       social_collaborative_score, social_collaborative_behaviors,
		       overall_score, summary, strengths, areas_for_improvement, recommendations,
		       ai_model_used, confidence_score, processing_time_ms, created_at
		FROM analyses WHERE id = $1
	`
	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&analysis.ID, &analysis.RecordingID, &analysis.TranscriptionID, &analysis.TimeOnLearning, &analysis.ScienceOfLearning,
		&analysis.SupportiveEnvironmentScore, &analysis.SupportiveEnvironmentBehaviors,
		&analysis.PositiveExpectationsScore, &analysis.PositiveExpectationsBehaviors,
		&analysis.LessonFacilitationScore, &analysis.LessonFacilitationBehaviors,
		&analysis.ChecksUnderstandingScore, &analysis.ChecksUnderstandingBehaviors,
		&analysis.FeedbackScore, &analysis.FeedbackBehaviors,
		&analysis.CriticalThinkingScore, &analysis.CriticalThinkingBehaviors,
		&analysis.AutonomyScore, &analysis.AutonomyBehaviors,
		&analysis.PerseveranceScore, &analysis.PerseveranceBehaviors,
		&analysis.SocialCollaborativeScore, &analysis.SocialCollaborativeBehaviors,
		&analysis.OverallScore, &analysis.Summary, &analysis.Strengths,
		&analysis.AreasForImprovement, &analysis.Recommendations,
		&analysis.AIModelUsed, &analysis.ConfidenceScore, &analysis.ProcessingTimeMs,
		&analysis.CreatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return analysis, err
}

func (r *Repository) GetAnalysisByRecordingID(ctx context.Context, recordingID uuid.UUID) (*models.Analysis, error) {
	analysis := &models.Analysis{}
	query := `
		SELECT id, recording_id, transcription_id, time_on_learning, science_of_learning,
		       supportive_environment_score, supportive_environment_behaviors,
		       positive_expectations_score, positive_expectations_behaviors,
		       lesson_facilitation_score, lesson_facilitation_behaviors,
		       checks_understanding_score, checks_understanding_behaviors,
		       feedback_score, feedback_behaviors,
		       critical_thinking_score, critical_thinking_behaviors,
		       autonomy_score, autonomy_behaviors,
		       perseverance_score, perseverance_behaviors,
		       social_collaborative_score, social_collaborative_behaviors,
		       overall_score, summary, strengths, areas_for_improvement, recommendations,
		       ai_model_used, confidence_score, processing_time_ms, created_at
		FROM analyses WHERE recording_id = $1
	`
	err := r.db.QueryRowContext(ctx, query, recordingID).Scan(
		&analysis.ID, &analysis.RecordingID, &analysis.TranscriptionID, &analysis.TimeOnLearning, &analysis.ScienceOfLearning,
		&analysis.SupportiveEnvironmentScore, &analysis.SupportiveEnvironmentBehaviors,
		&analysis.PositiveExpectationsScore, &analysis.PositiveExpectationsBehaviors,
		&analysis.LessonFacilitationScore, &analysis.LessonFacilitationBehaviors,
		&analysis.ChecksUnderstandingScore, &analysis.ChecksUnderstandingBehaviors,
		&analysis.FeedbackScore, &analysis.FeedbackBehaviors,
		&analysis.CriticalThinkingScore, &analysis.CriticalThinkingBehaviors,
		&analysis.AutonomyScore, &analysis.AutonomyBehaviors,
		&analysis.PerseveranceScore, &analysis.PerseveranceBehaviors,
		&analysis.SocialCollaborativeScore, &analysis.SocialCollaborativeBehaviors,
		&analysis.OverallScore, &analysis.Summary, &analysis.Strengths,
		&analysis.AreasForImprovement, &analysis.Recommendations,
		&analysis.AIModelUsed, &analysis.ConfidenceScore, &analysis.ProcessingTimeMs,
		&analysis.CreatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return analysis, err
}

// UpsertManualScore inserts or updates a coach's manual score for a recording.
// There is one row per (recording_id, scorer_id); re-saving overwrites it.
func (r *Repository) UpsertManualScore(ctx context.Context, m *models.ManualScore) error {
	query := `
		INSERT INTO manual_scores (
			recording_id, scorer_id,
			supportive_environment_score, positive_expectations_score,
			lesson_facilitation_score, checks_understanding_score,
			feedback_score, critical_thinking_score,
			autonomy_score, perseverance_score, social_collaborative_score,
			element_rationales, overall_score, summary, strengths,
			areas_for_improvement, recommendations, notes, updated_at
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, CURRENT_TIMESTAMP
		)
		ON CONFLICT (recording_id, scorer_id) DO UPDATE SET
			supportive_environment_score = EXCLUDED.supportive_environment_score,
			positive_expectations_score = EXCLUDED.positive_expectations_score,
			lesson_facilitation_score = EXCLUDED.lesson_facilitation_score,
			checks_understanding_score = EXCLUDED.checks_understanding_score,
			feedback_score = EXCLUDED.feedback_score,
			critical_thinking_score = EXCLUDED.critical_thinking_score,
			autonomy_score = EXCLUDED.autonomy_score,
			perseverance_score = EXCLUDED.perseverance_score,
			social_collaborative_score = EXCLUDED.social_collaborative_score,
			element_rationales = EXCLUDED.element_rationales,
			overall_score = EXCLUDED.overall_score,
			summary = EXCLUDED.summary,
			strengths = EXCLUDED.strengths,
			areas_for_improvement = EXCLUDED.areas_for_improvement,
			recommendations = EXCLUDED.recommendations,
			notes = EXCLUDED.notes,
			updated_at = CURRENT_TIMESTAMP
		RETURNING id, created_at, updated_at
	`
	return r.db.QueryRowContext(ctx, query,
		m.RecordingID, m.ScorerID,
		m.SupportiveEnvironmentScore, m.PositiveExpectationsScore,
		m.LessonFacilitationScore, m.ChecksUnderstandingScore,
		m.FeedbackScore, m.CriticalThinkingScore,
		m.AutonomyScore, m.PerseveranceScore, m.SocialCollaborativeScore,
		m.ElementRationales, m.OverallScore, m.Summary, m.Strengths,
		m.AreasForImprovement, m.Recommendations, m.Notes,
	).Scan(&m.ID, &m.CreatedAt, &m.UpdatedAt)
}

// GetManualScore returns a coach's manual score for a recording, or nil if the
// coach has not scored it yet.
func (r *Repository) GetManualScore(ctx context.Context, recordingID, scorerID uuid.UUID) (*models.ManualScore, error) {
	m := &models.ManualScore{}
	query := `
		SELECT id, recording_id, scorer_id,
		       supportive_environment_score, positive_expectations_score,
		       lesson_facilitation_score, checks_understanding_score,
		       feedback_score, critical_thinking_score,
		       autonomy_score, perseverance_score, social_collaborative_score,
		       element_rationales, overall_score, summary, strengths,
		       areas_for_improvement, recommendations, notes, created_at, updated_at
		FROM manual_scores WHERE recording_id = $1 AND scorer_id = $2
	`
	err := r.db.QueryRowContext(ctx, query, recordingID, scorerID).Scan(
		&m.ID, &m.RecordingID, &m.ScorerID,
		&m.SupportiveEnvironmentScore, &m.PositiveExpectationsScore,
		&m.LessonFacilitationScore, &m.ChecksUnderstandingScore,
		&m.FeedbackScore, &m.CriticalThinkingScore,
		&m.AutonomyScore, &m.PerseveranceScore, &m.SocialCollaborativeScore,
		&m.ElementRationales, &m.OverallScore, &m.Summary, &m.Strengths,
		&m.AreasForImprovement, &m.Recommendations, &m.Notes, &m.CreatedAt, &m.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return m, err
}

func (r *Repository) GetAnalysesByUserID(ctx context.Context, userID uuid.UUID) ([]*models.Analysis, error) {
	query := `
		SELECT a.id, a.recording_id, a.transcription_id, a.time_on_learning, a.science_of_learning,
		       a.supportive_environment_score, a.supportive_environment_behaviors,
		       a.positive_expectations_score, a.positive_expectations_behaviors,
		       a.lesson_facilitation_score, a.lesson_facilitation_behaviors,
		       a.checks_understanding_score, a.checks_understanding_behaviors,
		       a.feedback_score, a.feedback_behaviors,
		       a.critical_thinking_score, a.critical_thinking_behaviors,
		       a.autonomy_score, a.autonomy_behaviors,
		       a.perseverance_score, a.perseverance_behaviors,
		       a.social_collaborative_score, a.social_collaborative_behaviors,
		       a.overall_score, a.summary, a.strengths, a.areas_for_improvement, a.recommendations,
		       a.ai_model_used, a.confidence_score, a.processing_time_ms, a.created_at
		FROM analyses a
		JOIN recordings r ON a.recording_id = r.id
		WHERE r.user_id = $1
		ORDER BY a.created_at DESC
	`
	rows, err := r.db.QueryContext(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var analyses []*models.Analysis
	for rows.Next() {
		analysis := &models.Analysis{}
		err := rows.Scan(
			&analysis.ID, &analysis.RecordingID, &analysis.TranscriptionID, &analysis.TimeOnLearning, &analysis.ScienceOfLearning,
			&analysis.SupportiveEnvironmentScore, &analysis.SupportiveEnvironmentBehaviors,
			&analysis.PositiveExpectationsScore, &analysis.PositiveExpectationsBehaviors,
			&analysis.LessonFacilitationScore, &analysis.LessonFacilitationBehaviors,
			&analysis.ChecksUnderstandingScore, &analysis.ChecksUnderstandingBehaviors,
			&analysis.FeedbackScore, &analysis.FeedbackBehaviors,
			&analysis.CriticalThinkingScore, &analysis.CriticalThinkingBehaviors,
			&analysis.AutonomyScore, &analysis.AutonomyBehaviors,
			&analysis.PerseveranceScore, &analysis.PerseveranceBehaviors,
			&analysis.SocialCollaborativeScore, &analysis.SocialCollaborativeBehaviors,
			&analysis.OverallScore, &analysis.Summary, &analysis.Strengths,
			&analysis.AreasForImprovement, &analysis.Recommendations,
			&analysis.AIModelUsed, &analysis.ConfidenceScore, &analysis.ProcessingTimeMs,
			&analysis.CreatedAt,
		)
		if err != nil {
			return nil, err
		}
		analyses = append(analyses, analysis)
	}
	return analyses, rows.Err()
}

// Chat operations

func (r *Repository) CreateChatSession(ctx context.Context, session *models.ChatSession) error {
	query := `
		INSERT INTO chat_sessions (user_id, analysis_id, updated_at)
		VALUES ($1, $2, CURRENT_TIMESTAMP)
		RETURNING id, created_at, updated_at
	`
	return r.db.QueryRowContext(ctx, query, session.UserID, session.AnalysisID).Scan(&session.ID, &session.CreatedAt, &session.UpdatedAt)
}

func (r *Repository) GetChatSessionByID(ctx context.Context, id uuid.UUID) (*models.ChatSession, error) {
	session := &models.ChatSession{}
	query := `SELECT id, user_id, analysis_id, created_at FROM chat_sessions WHERE id = $1`
	err := r.db.QueryRowContext(ctx, query, id).Scan(&session.ID, &session.UserID, &session.AnalysisID, &session.CreatedAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return session, err
}

func (r *Repository) GetChatSessionsByUserID(ctx context.Context, userID uuid.UUID) ([]*models.ChatSessionSummary, error) {
	query := `
		SELECT c.id, c.user_id, c.analysis_id, c.created_at, c.updated_at,
		       r.title as lesson_title, r.subject, r.grade_level
		FROM chat_sessions c
		LEFT JOIN analyses a ON c.analysis_id = a.id
		LEFT JOIN recordings r ON a.recording_id = r.id
		WHERE c.user_id = $1
		ORDER BY c.updated_at DESC
	`
	rows, err := r.db.QueryContext(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var sessions []*models.ChatSessionSummary
	for rows.Next() {
		s := &models.ChatSessionSummary{}
		err := rows.Scan(
			&s.ID, &s.UserID, &s.AnalysisID, &s.CreatedAt, &s.UpdatedAt,
			&s.LessonTitle, &s.Subject, &s.GradeLevel,
		)
		if err != nil {
			return nil, err
		}
		sessions = append(sessions, s)
	}
	return sessions, rows.Err()
}

func (r *Repository) CreateChatMessage(ctx context.Context, message *models.ChatMessage) error {
	// First insert the message
	query := `
		INSERT INTO chat_messages (session_id, role, content)
		VALUES ($1, $2, $3)
		RETURNING id, created_at
	`
	err := r.db.QueryRowContext(ctx, query, message.SessionID, message.Role, message.Content).Scan(&message.ID, &message.CreatedAt)
	if err != nil {
		return err
	}

	// Then update the session's updated_at timestamp
	updateQuery := `UPDATE chat_sessions SET updated_at = $1 WHERE id = $2`
	_, err = r.db.ExecContext(ctx, updateQuery, message.CreatedAt, message.SessionID)
	return err
}

func (r *Repository) GetChatMessagesBySessionID(ctx context.Context, sessionID uuid.UUID) ([]*models.ChatMessage, error) {
	query := `
		SELECT id, session_id, role, content, created_at
		FROM chat_messages
		WHERE session_id = $1
		ORDER BY created_at ASC
	`
	rows, err := r.db.QueryContext(ctx, query, sessionID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var messages []*models.ChatMessage
	for rows.Next() {
		message := &models.ChatMessage{}
		err := rows.Scan(&message.ID, &message.SessionID, &message.Role, &message.Content, &message.CreatedAt)
		if err != nil {
			return nil, err
		}
		messages = append(messages, message)
	}
	return messages, nil
}

func (r *Repository) DeleteChatSession(ctx context.Context, sessionID uuid.UUID) error {
	// Delete messages first (foreign key constraint)
	if _, err := r.db.ExecContext(ctx, `DELETE FROM chat_messages WHERE session_id = $1`, sessionID); err != nil {
		return err
	}

	// Delete session
	result, err := r.db.ExecContext(ctx, `DELETE FROM chat_sessions WHERE id = $1`, sessionID)
	if err != nil {
		return err
	}

	rows, _ := result.RowsAffected()
	if rows == 0 {
		return nil // Already deleted or didn't exist, treat as success
	}

	return nil
}

// Progress operations

func (r *Repository) GetProgressByUserID(ctx context.Context, userID uuid.UUID, startDate, endDate time.Time) (*models.ProgressSnapshot, error) {
	// Calculate progress metrics
	query := `
		SELECT 
			COUNT(DISTINCT r.id) as total_recordings,
			AVG(a.overall_score) as average_overall_score
		FROM recordings r
		LEFT JOIN analyses a ON r.id = a.recording_id
		WHERE r.user_id = $1 
		  AND r.created_at >= $2 
		  AND r.created_at <= $3
	`

	var totalRecordings int
	var avgScore sql.NullFloat64

	err := r.db.QueryRowContext(ctx, query, userID, startDate, endDate).Scan(&totalRecordings, &avgScore)
	if err != nil {
		return nil, err
	}

	progress := &models.ProgressSnapshot{
		ID:              uuid.New(),
		UserID:          userID,
		PeriodStart:     startDate,
		PeriodEnd:       endDate,
		TotalRecordings: totalRecordings,
		CreatedAt:       time.Now(),
	}

	if avgScore.Valid {
		progress.AverageOverallScore = &avgScore.Float64
	}

	return progress, nil
}

// ---------------------------------------------------------------------------
// Admin / monitoring operations (cross-user aggregates for the WB dashboard)
// ---------------------------------------------------------------------------

// PromoteUserToAdminByEmail sets role='admin' for the user with the given email.
// Returns the number of rows affected (0 if no such user exists yet).
func (r *Repository) PromoteUserToAdminByEmail(ctx context.Context, email string) (int64, error) {
	res, err := r.db.ExecContext(ctx,
		`UPDATE users SET role = 'admin', updated_at = CURRENT_TIMESTAMP WHERE email = $1`, email)
	if err != nil {
		return 0, err
	}
	return res.RowsAffected()
}

// GetAllUsers lists every user with role + activity summary, for the admin user
// management screen. An optional search term matches username, email or name.
func (r *Repository) GetAllUsers(ctx context.Context, search string) ([]*models.UserAdminRow, error) {
	query := `
		SELECT u.id, u.first_name, u.last_name, u.username, u.email, u.role,
		       u.school_name, u.country,
		       COUNT(rec.id) AS recording_count, MAX(rec.created_at) AS last_activity,
		       u.created_at
		FROM users u
		LEFT JOIN recordings rec ON rec.user_id = u.id
	`
	args := []interface{}{}
	if search != "" {
		query += ` WHERE (u.username ILIKE $1 OR u.email ILIKE $1
		            OR (u.first_name || ' ' || u.last_name) ILIKE $1)`
		args = append(args, "%"+search+"%")
	}
	query += ` GROUP BY u.id ORDER BY u.created_at DESC`

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []*models.UserAdminRow
	for rows.Next() {
		row := &models.UserAdminRow{}
		if err := rows.Scan(
			&row.ID, &row.FirstName, &row.LastName, &row.Username, &row.Email, &row.Role,
			&row.SchoolName, &row.Country, &row.RecordingCount, &row.LastActivity, &row.CreatedAt,
		); err != nil {
			return nil, err
		}
		result = append(result, row)
	}
	if result == nil {
		result = []*models.UserAdminRow{}
	}
	return result, rows.Err()
}

// UpdateUserRole sets a user's role. Returns the number of rows affected.
func (r *Repository) UpdateUserRole(ctx context.Context, id uuid.UUID, role string) (int64, error) {
	res, err := r.db.ExecContext(ctx,
		`UPDATE users SET role = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2`, role, id)
	if err != nil {
		return 0, err
	}
	return res.RowsAffected()
}

// CountAdmins returns how many users currently have the admin role. Used to
// prevent removing the last admin.
func (r *Repository) CountAdmins(ctx context.Context) (int, error) {
	var count int
	err := r.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM users WHERE role = 'admin'`).Scan(&count)
	return count, err
}

// buildLessonWhere builds the dynamic WHERE clause (and args) shared by the
// lesson-log list, count, and export queries. Placeholders start at startIdx.
func buildLessonWhere(f models.LessonLogFilters, startIdx int) (string, []interface{}) {
	conds := []string{}
	args := []interface{}{}
	idx := startIdx
	add := func(format string, val interface{}) {
		conds = append(conds, fmt.Sprintf(format, idx))
		args = append(args, val)
		idx++
	}

	if f.Country != "" {
		add("u.country = $%d", f.Country)
	}
	if f.School != "" {
		add("u.school_name = $%d", f.School)
	}
	if f.Grade != "" {
		add("r.grade_level = $%d", f.Grade)
	}
	if f.Subject != "" {
		add("r.subject = $%d", f.Subject)
	}
	if f.Status != "" {
		add("r.status = $%d", f.Status)
	}
	if f.TeacherID != "" {
		// Compare as text so an invalid UUID string can't error the query.
		add("u.id::text = $%d", f.TeacherID)
	}
	if f.StartDate != nil {
		add("r.created_at >= $%d", *f.StartDate)
	}
	if f.EndDate != nil {
		add("r.created_at <= $%d", *f.EndDate)
	}

	if len(conds) == 0 {
		return "", args
	}
	return "WHERE " + strings.Join(conds, " AND "), args
}

const lessonLogSelect = `
	SELECT r.id, r.title, r.subject, r.grade_level, r.language, r.status, r.duration_seconds, r.created_at,
	       u.id, u.first_name, u.last_name, u.username, u.school_name, u.country, u.role,
	       r.observed_teacher_name,
	       (a.id IS NOT NULL) AS has_analysis, a.overall_score
	FROM recordings r
	JOIN users u ON r.user_id = u.id
	LEFT JOIN analyses a ON a.recording_id = r.id
`

func scanLessonRows(rows *sql.Rows) ([]*models.LessonLogRow, error) {
	var result []*models.LessonLogRow
	for rows.Next() {
		row := &models.LessonLogRow{}
		var first, last, accountRole string
		err := rows.Scan(
			&row.RecordingID, &row.Title, &row.Subject, &row.GradeLevel, &row.Language,
			&row.Status, &row.DurationSeconds, &row.CreatedAt,
			&row.TeacherID, &first, &last, &row.TeacherUsername, &row.SchoolName, &row.Country,
			&accountRole, &row.ObservedTeacherName,
			&row.HasAnalysis, &row.OverallScore,
		)
		if err != nil {
			return nil, err
		}

		accountName := strings.TrimSpace(first + " " + last)
		row.RecordedByName = accountName
		row.RecordedByRole = accountRole

		// The teacher column must name whoever TAUGHT the lesson. When a
		// coordinator records a lesson they observed, the account holder is the
		// coordinator — so prefer the observed teacher's name where we have it.
		row.TeacherName = accountName
		if row.ObservedTeacherName != nil && strings.TrimSpace(*row.ObservedTeacherName) != "" {
			row.TeacherName = strings.TrimSpace(*row.ObservedTeacherName)
		}

		result = append(result, row)
	}
	return result, rows.Err()
}

func lessonOrderBy(sort string) string {
	switch sort {
	case "created_at_asc":
		return "r.created_at ASC"
	case "duration_desc":
		return "r.duration_seconds DESC NULLS LAST"
	case "score_desc":
		return "a.overall_score DESC NULLS LAST"
	default:
		return "r.created_at DESC"
	}
}

// GetLessonsLog returns a paginated, filtered page of the consolidated lesson log.
func (r *Repository) GetLessonsLog(ctx context.Context, f models.LessonLogFilters, p models.Pagination) (*models.LessonLogResult, error) {
	where, args := buildLessonWhere(f, 1)

	countQuery := `SELECT COUNT(*) FROM recordings r JOIN users u ON r.user_id = u.id ` + where
	var total int
	if err := r.db.QueryRowContext(ctx, countQuery, args...).Scan(&total); err != nil {
		return nil, err
	}

	if p.Page < 1 {
		p.Page = 1
	}
	if p.PageSize < 1 || p.PageSize > 200 {
		p.PageSize = 50
	}
	offset := (p.Page - 1) * p.PageSize

	query := fmt.Sprintf("%s %s ORDER BY %s LIMIT $%d OFFSET $%d",
		lessonLogSelect, where, lessonOrderBy(p.Sort), len(args)+1, len(args)+2)
	args = append(args, p.PageSize, offset)

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	logRows, err := scanLessonRows(rows)
	if err != nil {
		return nil, err
	}
	if logRows == nil {
		logRows = []*models.LessonLogRow{}
	}

	return &models.LessonLogResult{
		Rows:     logRows,
		Total:    total,
		Page:     p.Page,
		PageSize: p.PageSize,
	}, nil
}

// GetLessonsLogAll returns every row matching the filters (no pagination), used
// for the export endpoint. Capped to avoid unbounded result sets.
func (r *Repository) GetLessonsLogAll(ctx context.Context, f models.LessonLogFilters, sort string) ([]*models.LessonLogRow, error) {
	where, args := buildLessonWhere(f, 1)
	query := fmt.Sprintf("%s %s ORDER BY %s LIMIT 100000", lessonLogSelect, where, lessonOrderBy(sort))

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanLessonRows(rows)
}

// GetAdminOverview returns the headline counts for the dashboard overview.
func (r *Repository) GetAdminOverview(ctx context.Context) (*models.AdminOverview, error) {
	query := `
		-- "Teacher" figures count role='teacher' only. Coordinators also record
		-- lessons (they own the ones they observe), so without the role filter
		-- an active coordinator would be reported to the World Bank as an active
		-- teacher. Recording and analysis totals stay unfiltered: a lesson a
		-- coordinator recorded is still a lesson that happened.
		SELECT
			(SELECT COUNT(*) FROM users WHERE role = 'teacher'),
			(SELECT COUNT(DISTINCT school_name) FROM users
			  WHERE role = 'teacher' AND school_name IS NOT NULL AND school_name <> ''),
			(SELECT COUNT(DISTINCT country) FROM users
			  WHERE role = 'teacher' AND country IS NOT NULL AND country <> ''),
			(SELECT COUNT(*) FROM recordings),
			(SELECT COUNT(*) FROM analyses),
			(SELECT COUNT(DISTINCT r.user_id) FROM recordings r
			   JOIN users u ON u.id = r.user_id
			  WHERE u.role = 'teacher' AND r.created_at >= NOW() - INTERVAL '7 days'),
			(SELECT COUNT(DISTINCT r.user_id) FROM recordings r
			   JOIN users u ON u.id = r.user_id
			  WHERE u.role = 'teacher' AND r.created_at >= NOW() - INTERVAL '30 days')
	`
	o := &models.AdminOverview{}
	err := r.db.QueryRowContext(ctx, query).Scan(
		&o.TotalTeachers, &o.TotalSchools, &o.TotalCountries,
		&o.TotalRecordings, &o.TotalAnalyses, &o.ActiveTeachers7d, &o.ActiveTeachers30d,
	)
	if err != nil {
		return nil, err
	}
	return o, nil
}

// GetSchoolUsage aggregates teacher count, recording count and last activity per
// school. Optionally scoped to a single country.
func (r *Repository) GetSchoolUsage(ctx context.Context, country string) ([]*models.SchoolUsageRow, error) {
	query := `
		SELECT u.country, u.school_name,
		       COUNT(DISTINCT u.id) AS teacher_count,
		       COUNT(r.id) AS recording_count,
		       MAX(r.created_at) AS last_recording
		FROM users u
		LEFT JOIN recordings r ON r.user_id = u.id
		WHERE u.role = 'teacher'
	`
	args := []interface{}{}
	if country != "" {
		query += " AND u.country = $1"
		args = append(args, country)
	}
	query += " GROUP BY u.country, u.school_name ORDER BY u.country NULLS LAST, u.school_name NULLS LAST"

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []*models.SchoolUsageRow
	for rows.Next() {
		row := &models.SchoolUsageRow{}
		if err := rows.Scan(&row.Country, &row.SchoolName, &row.TeacherCount, &row.RecordingCount, &row.LastRecording); err != nil {
			return nil, err
		}
		result = append(result, row)
	}
	if result == nil {
		result = []*models.SchoolUsageRow{}
	}
	return result, rows.Err()
}

// GetTeacherRoster lists teachers with their recording counts and last activity,
// optionally filtered by country and/or school.
func (r *Repository) GetTeacherRoster(ctx context.Context, country, school string) ([]*models.TeacherRosterRow, error) {
	query := `
		SELECT u.id, u.first_name, u.last_name, u.username, u.email, u.school_name, u.country,
		       COUNT(r.id) AS recording_count, MAX(r.created_at) AS last_activity, u.created_at
		FROM users u
		LEFT JOIN recordings r ON r.user_id = u.id
		WHERE u.role = 'teacher'
	`
	args := []interface{}{}
	idx := 1
	if country != "" {
		query += fmt.Sprintf(" AND u.country = $%d", idx)
		args = append(args, country)
		idx++
	}
	if school != "" {
		query += fmt.Sprintf(" AND u.school_name = $%d", idx)
		args = append(args, school)
		idx++
	}
	query += ` GROUP BY u.id ORDER BY recording_count DESC, u.created_at DESC`

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []*models.TeacherRosterRow
	for rows.Next() {
		row := &models.TeacherRosterRow{}
		if err := rows.Scan(
			&row.ID, &row.FirstName, &row.LastName, &row.Username, &row.Email,
			&row.SchoolName, &row.Country, &row.RecordingCount, &row.LastActivity, &row.CreatedAt,
		); err != nil {
			return nil, err
		}
		result = append(result, row)
	}
	if result == nil {
		result = []*models.TeacherRosterRow{}
	}
	return result, rows.Err()
}

// GetAdminFilterOptions returns the distinct values that populate the dashboard
// filter dropdowns.
func (r *Repository) GetAdminFilterOptions(ctx context.Context) (*models.AdminFilterOptions, error) {
	opts := &models.AdminFilterOptions{
		Countries: []string{},
		Schools:   []models.SchoolOption{},
		Grades:    []string{},
		Subjects:  []string{},
		Statuses:  []string{},
	}

	scanStrings := func(query string) ([]string, error) {
		rows, err := r.db.QueryContext(ctx, query)
		if err != nil {
			return nil, err
		}
		defer rows.Close()
		out := []string{}
		for rows.Next() {
			var s string
			if err := rows.Scan(&s); err != nil {
				return nil, err
			}
			out = append(out, s)
		}
		return out, rows.Err()
	}

	var err error
	if opts.Countries, err = scanStrings(
		`SELECT DISTINCT country FROM users WHERE role = 'teacher' AND country IS NOT NULL AND country <> '' ORDER BY country`); err != nil {
		return nil, err
	}
	if opts.Grades, err = scanStrings(
		`SELECT DISTINCT grade_level FROM recordings WHERE grade_level IS NOT NULL AND grade_level <> '' ORDER BY grade_level`); err != nil {
		return nil, err
	}
	if opts.Subjects, err = scanStrings(
		`SELECT DISTINCT subject FROM recordings WHERE subject IS NOT NULL AND subject <> '' ORDER BY subject`); err != nil {
		return nil, err
	}
	if opts.Statuses, err = scanStrings(
		`SELECT DISTINCT status FROM recordings WHERE status IS NOT NULL AND status <> '' ORDER BY status`); err != nil {
		return nil, err
	}

	// Schools paired with their country for cascading dropdowns.
	rows, err := r.db.QueryContext(ctx,
		`SELECT DISTINCT COALESCE(country, ''), school_name FROM users
		 WHERE role = 'teacher' AND school_name IS NOT NULL AND school_name <> ''
		 ORDER BY 1, 2`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var so models.SchoolOption
		if err := rows.Scan(&so.Country, &so.School); err != nil {
			return nil, err
		}
		opts.Schools = append(opts.Schools, so)
	}
	return opts, rows.Err()
}

// ---------------------------------------------------------------------------
// Coaching scripts (coordinator flow)
// ---------------------------------------------------------------------------

// UpsertCoachScript stores a generated script, replacing any previous one for
// the same (recording, coordinator, element). Mirrors UpsertManualScore.
func (r *Repository) UpsertCoachScript(ctx context.Context, s *models.CoachScript) error {
	query := `
		INSERT INTO coach_scripts (
			recording_id, coordinator_id, element_key, language,
			observed_evidence, what_it_means, coach_question, follow_up_questions,
			possible_model, practice, next_step, ai_model_used, updated_at
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, CURRENT_TIMESTAMP
		)
		ON CONFLICT (recording_id, coordinator_id, element_key) DO UPDATE SET
			language = EXCLUDED.language,
			observed_evidence = EXCLUDED.observed_evidence,
			what_it_means = EXCLUDED.what_it_means,
			coach_question = EXCLUDED.coach_question,
			follow_up_questions = EXCLUDED.follow_up_questions,
			possible_model = EXCLUDED.possible_model,
			practice = EXCLUDED.practice,
			next_step = EXCLUDED.next_step,
			ai_model_used = EXCLUDED.ai_model_used,
			updated_at = CURRENT_TIMESTAMP
		RETURNING id, created_at, updated_at
	`
	return r.db.QueryRowContext(ctx, query,
		s.RecordingID, s.CoordinatorID, s.ElementKey, s.Language,
		s.ObservedEvidence, s.WhatItMeans, s.CoachQuestion, s.FollowUpQuestions,
		s.PossibleModel, s.Practice, s.NextStep, s.AIModelUsed,
	).Scan(&s.ID, &s.CreatedAt, &s.UpdatedAt)
}

// GetCoachScript returns the coordinator's stored script for one element, or
// (nil, nil) when they have not generated it yet.
func (r *Repository) GetCoachScript(ctx context.Context, recordingID, coordinatorID uuid.UUID, elementKey string) (*models.CoachScript, error) {
	s := &models.CoachScript{}
	query := `
		SELECT id, recording_id, coordinator_id, element_key, language,
		       observed_evidence, what_it_means, coach_question, follow_up_questions,
		       possible_model, practice, next_step, ai_model_used, created_at, updated_at
		FROM coach_scripts
		WHERE recording_id = $1 AND coordinator_id = $2 AND element_key = $3
	`
	err := r.db.QueryRowContext(ctx, query, recordingID, coordinatorID, elementKey).Scan(
		&s.ID, &s.RecordingID, &s.CoordinatorID, &s.ElementKey, &s.Language,
		&s.ObservedEvidence, &s.WhatItMeans, &s.CoachQuestion, &s.FollowUpQuestions,
		&s.PossibleModel, &s.Practice, &s.NextStep, &s.AIModelUsed,
		&s.CreatedAt, &s.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return s, err
}

// ListCoachScripts returns every script the coordinator has generated for a
// recording, so the picker can show which elements are already prepared.
func (r *Repository) ListCoachScripts(ctx context.Context, recordingID, coordinatorID uuid.UUID) ([]*models.CoachScript, error) {
	query := `
		SELECT id, recording_id, coordinator_id, element_key, language,
		       observed_evidence, what_it_means, coach_question, follow_up_questions,
		       possible_model, practice, next_step, ai_model_used, created_at, updated_at
		FROM coach_scripts
		WHERE recording_id = $1 AND coordinator_id = $2
		ORDER BY created_at
	`
	rows, err := r.db.QueryContext(ctx, query, recordingID, coordinatorID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []*models.CoachScript
	for rows.Next() {
		s := &models.CoachScript{}
		if err := rows.Scan(
			&s.ID, &s.RecordingID, &s.CoordinatorID, &s.ElementKey, &s.Language,
			&s.ObservedEvidence, &s.WhatItMeans, &s.CoachQuestion, &s.FollowUpQuestions,
			&s.PossibleModel, &s.Practice, &s.NextStep, &s.AIModelUsed,
			&s.CreatedAt, &s.UpdatedAt,
		); err != nil {
			return nil, err
		}
		result = append(result, s)
	}
	if result == nil {
		result = []*models.CoachScript{}
	}
	return result, rows.Err()
}
