package repository

import (
	"context"
	"database/sql"
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
		INSERT INTO users (email, password_hash, first_name, last_name, school_name, country, language_preference)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, created_at, updated_at
	`
	return r.db.QueryRowContext(ctx, query,
		user.Email, user.PasswordHash, user.FirstName, user.LastName,
		user.SchoolName, user.Country, user.LanguagePreference,
	).Scan(&user.ID, &user.CreatedAt, &user.UpdatedAt)
}

func (r *Repository) GetUserByEmail(ctx context.Context, email string) (*models.User, error) {
	user := &models.User{}
	query := `
		SELECT id, email, password_hash, first_name, last_name, role, school_name, country, 
		       language_preference, created_at, updated_at
		FROM users WHERE email = $1
	`
	err := r.db.QueryRowContext(ctx, query, email).Scan(
		&user.ID, &user.Email, &user.PasswordHash, &user.FirstName, &user.LastName,
		&user.Role, &user.SchoolName, &user.Country, &user.LanguagePreference,
		&user.CreatedAt, &user.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return user, err
}

func (r *Repository) GetUserByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
	user := &models.User{}
	query := `
		SELECT id, email, password_hash, first_name, last_name, role, school_name, country, 
		       language_preference, created_at, updated_at
		FROM users WHERE id = $1
	`
	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&user.ID, &user.Email, &user.PasswordHash, &user.FirstName, &user.LastName,
		&user.Role, &user.SchoolName, &user.Country, &user.LanguagePreference,
		&user.CreatedAt, &user.UpdatedAt,
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
		    language_preference = $5, updated_at = CURRENT_TIMESTAMP
		WHERE id = $6
	`
	_, err := r.db.ExecContext(ctx, query,
		user.FirstName, user.LastName, user.SchoolName, user.Country,
		user.LanguagePreference, user.ID,
	)
	return err
}

// Recording operations

func (r *Repository) CreateRecording(ctx context.Context, recording *models.Recording) error {
	query := `
		INSERT INTO recordings (user_id, title, description, file_url, file_size_bytes, duration_seconds,
		                        recording_type, subject, grade_level, language, status, recorded_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
		RETURNING id, created_at, updated_at
	`
	return r.db.QueryRowContext(ctx, query,
		recording.UserID, recording.Title, recording.Description, recording.FileURL,
		recording.FileSizeBytes, recording.DurationSeconds, recording.RecordingType,
		recording.Subject, recording.GradeLevel, recording.Language, recording.Status,
		recording.RecordedAt,
	).Scan(&recording.ID, &recording.CreatedAt, &recording.UpdatedAt)
}

func (r *Repository) GetRecordingByID(ctx context.Context, id uuid.UUID) (*models.Recording, error) {
	recording := &models.Recording{}
	query := `
		SELECT id, user_id, title, description, file_url, file_size_bytes, duration_seconds,
		       recording_type, subject, grade_level, language, status, recorded_at, created_at, updated_at
		FROM recordings WHERE id = $1
	`
	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&recording.ID, &recording.UserID, &recording.Title, &recording.Description,
		&recording.FileURL, &recording.FileSizeBytes, &recording.DurationSeconds,
		&recording.RecordingType, &recording.Subject, &recording.GradeLevel,
		&recording.Language, &recording.Status, &recording.RecordedAt,
		&recording.CreatedAt, &recording.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return recording, err
}

func (r *Repository) GetRecordingsByUserID(ctx context.Context, userID uuid.UUID) ([]*models.Recording, error) {
	query := `
		SELECT id, user_id, title, description, file_url, file_size_bytes, duration_seconds,
		       recording_type, subject, grade_level, language, status, recorded_at, created_at, updated_at
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
			&recording.Language, &recording.Status, &recording.RecordedAt,
			&recording.CreatedAt, &recording.UpdatedAt,
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

func (r *Repository) DeleteRecording(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM recordings WHERE id = $1`
	_, err := r.db.ExecContext(ctx, query, id)
	return err
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
			recording_id, transcription_id, time_on_learning,
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
			$22, $23, $24, $25, $26, $27, $28, $29
		)
		RETURNING id, created_at
	`
	return r.db.QueryRowContext(ctx, query,
		analysis.RecordingID, analysis.TranscriptionID, analysis.TimeOnLearning,
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
		SELECT id, recording_id, transcription_id, time_on_learning,
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
		&analysis.ID, &analysis.RecordingID, &analysis.TranscriptionID, &analysis.TimeOnLearning,
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
		SELECT id, recording_id, transcription_id, time_on_learning,
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
		&analysis.ID, &analysis.RecordingID, &analysis.TranscriptionID, &analysis.TimeOnLearning,
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

func (r *Repository) GetAnalysesByUserID(ctx context.Context, userID uuid.UUID) ([]*models.Analysis, error) {
	query := `
		SELECT a.id, a.recording_id, a.transcription_id, a.time_on_learning,
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
			&analysis.ID, &analysis.RecordingID, &analysis.TranscriptionID, &analysis.TimeOnLearning,
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
		INSERT INTO chat_sessions (user_id, analysis_id)
		VALUES ($1, $2)
		RETURNING id, created_at
	`
	return r.db.QueryRowContext(ctx, query, session.UserID, session.AnalysisID).Scan(&session.ID, &session.CreatedAt)
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

func (r *Repository) CreateChatMessage(ctx context.Context, message *models.ChatMessage) error {
	query := `
		INSERT INTO chat_messages (session_id, role, content)
		VALUES ($1, $2, $3)
		RETURNING id, created_at
	`
	return r.db.QueryRowContext(ctx, query, message.SessionID, message.Role, message.Content).Scan(&message.ID, &message.CreatedAt)
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
	return messages, rows.Err()
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
