package database

import (
	"github.com/jmoiron/sqlx"
)

func createSchema(db *sqlx.DB) error {
	schema := `
	-- Users table
	CREATE TABLE IF NOT EXISTS users (
		id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
		email VARCHAR(255) UNIQUE NOT NULL,
		password_hash VARCHAR(255) NOT NULL,
		first_name VARCHAR(100) NOT NULL,
		last_name VARCHAR(100) NOT NULL,
		role VARCHAR(50) DEFAULT 'teacher',
		school_name VARCHAR(255),
		country VARCHAR(100),
		language_preference VARCHAR(10) DEFAULT 'en',
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);

	-- Recordings table
	CREATE TABLE IF NOT EXISTS recordings (
		id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
		user_id UUID REFERENCES users(id) ON DELETE CASCADE,
		title VARCHAR(255),
		description TEXT,
		file_url VARCHAR(500) NOT NULL,
		file_size_bytes BIGINT,
		duration_seconds INTEGER,
		recording_type VARCHAR(20) DEFAULT 'audio',
		subject VARCHAR(100),
		grade_level VARCHAR(50),
		language VARCHAR(50) DEFAULT 'en',
		status VARCHAR(50) DEFAULT 'pending',
		recorded_at TIMESTAMP,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);

	-- Transcriptions table
	CREATE TABLE IF NOT EXISTS transcriptions (
		id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
		recording_id UUID REFERENCES recordings(id) ON DELETE CASCADE,
		full_text TEXT NOT NULL,
		segments JSONB,
		word_count INTEGER,
		confidence_score DECIMAL(3,2),
		language_detected VARCHAR(50),
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);

	-- Analyses table (TEACH scores)
	CREATE TABLE IF NOT EXISTS analyses (
		id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
		recording_id UUID REFERENCES recordings(id) ON DELETE CASCADE,
		transcription_id UUID REFERENCES transcriptions(id),
		
		-- Time on Learning (JSONB with 3 snapshots)
		time_on_learning JSONB,
		
		-- Quality of Teaching Practices - 9 Elements (scores 1-5)
		supportive_environment_score INTEGER CHECK (supportive_environment_score BETWEEN 1 AND 5),
		supportive_environment_behaviors JSONB,
		positive_expectations_score INTEGER CHECK (positive_expectations_score BETWEEN 1 AND 5),
		positive_expectations_behaviors JSONB,
		lesson_facilitation_score INTEGER CHECK (lesson_facilitation_score BETWEEN 1 AND 5),
		lesson_facilitation_behaviors JSONB,
		checks_understanding_score INTEGER CHECK (checks_understanding_score BETWEEN 1 AND 5),
		checks_understanding_behaviors JSONB,
		feedback_score INTEGER CHECK (feedback_score BETWEEN 1 AND 5),
		feedback_behaviors JSONB,
		critical_thinking_score INTEGER CHECK (critical_thinking_score BETWEEN 1 AND 5),
		critical_thinking_behaviors JSONB,
		autonomy_score INTEGER CHECK (autonomy_score BETWEEN 1 AND 5),
		autonomy_behaviors JSONB,
		perseverance_score INTEGER CHECK (perseverance_score BETWEEN 1 AND 5),
		perseverance_behaviors JSONB,
		social_collaborative_score INTEGER CHECK (social_collaborative_score BETWEEN 1 AND 5),
		social_collaborative_behaviors JSONB,
		
		-- Overall
		overall_score DECIMAL(3,2),
		
		-- Qualitative feedback
		summary TEXT,
		strengths JSONB,
		areas_for_improvement JSONB,
		recommendations JSONB,
		
		-- Metadata
		ai_model_used VARCHAR(100),
		confidence_score DECIMAL(3,2),
		processing_time_ms INTEGER,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);

	-- Chat sessions for coaching
	CREATE TABLE IF NOT EXISTS chat_sessions (
		id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
		user_id UUID REFERENCES users(id) ON DELETE CASCADE,
		analysis_id UUID REFERENCES analyses(id),
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);

	-- Chat messages
	CREATE TABLE IF NOT EXISTS chat_messages (
		id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
		session_id UUID REFERENCES chat_sessions(id) ON DELETE CASCADE,
		role VARCHAR(20) NOT NULL,
		content TEXT NOT NULL,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);

	-- Progress tracking
	CREATE TABLE IF NOT EXISTS progress_snapshots (
		id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
		user_id UUID REFERENCES users(id) ON DELETE CASCADE,
		period_start DATE,
		period_end DATE,
		total_recordings INTEGER DEFAULT 0,
		average_overall_score DECIMAL(3,2),
		average_scores_by_element JSONB,
		improvement_trend DECIMAL(4,2),
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);

	-- Indexes
	CREATE INDEX IF NOT EXISTS idx_recordings_user_id ON recordings(user_id);
	CREATE INDEX IF NOT EXISTS idx_recordings_status ON recordings(status);
	CREATE INDEX IF NOT EXISTS idx_analyses_recording_id ON analyses(recording_id);
	CREATE INDEX IF NOT EXISTS idx_chat_messages_session_id ON chat_messages(session_id);
	CREATE INDEX IF NOT EXISTS idx_progress_user_id ON progress_snapshots(user_id);
	`

	_, err := db.Exec(schema)
	return err
}
