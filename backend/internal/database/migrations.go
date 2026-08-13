package database

import (
	"fmt"

	"github.com/jmoiron/sqlx"
)

func createSchema(db *sqlx.DB) error {
	// 1. Create tables
	tablesSchema := `
	-- Users table
	CREATE TABLE IF NOT EXISTS users (
		id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
		username VARCHAR(50) UNIQUE NOT NULL,
		email VARCHAR(255) UNIQUE,
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
		language VARCHAR(10) NOT NULL DEFAULT 'en',
		status VARCHAR(50) NOT NULL DEFAULT 'pending',
		failure_reason VARCHAR(100),
		error_message TEXT,
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
        
        -- Science of Learning Analysis
        science_of_learning JSONB,
		
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
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
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

	if _, err := db.Exec(tablesSchema); err != nil {
		return fmt.Errorf("failed to create tables: %w", err)
	}

	// 2. Apply migrations (safe updates)
	migrations := []string{
		"ALTER TABLE chat_sessions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;",
		"ALTER TABLE recordings ADD COLUMN IF NOT EXISTS failure_reason VARCHAR(100);",
		"ALTER TABLE recordings ADD COLUMN IF NOT EXISTS error_message TEXT;",
		"ALTER TABLE users ADD COLUMN IF NOT EXISTS username VARCHAR(50);",
		`DO $$ BEGIN
			IF NOT EXISTS (
				SELECT 1 FROM pg_constraint WHERE conname = 'users_username_key'
			) THEN
				ALTER TABLE users ADD CONSTRAINT users_username_key UNIQUE (username);
			END IF;
		END $$;`,
		"ALTER TABLE users ALTER COLUMN email DROP NOT NULL;",
		// Email Verification & Password Reset fields
		"ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT FALSE;",
		"ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verification_code VARCHAR(6);",
		"ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verification_code_expires_at TIMESTAMP;",
		"ALTER TABLE users ADD COLUMN IF NOT EXISTS password_reset_token VARCHAR(64);",
		"ALTER TABLE users ADD COLUMN IF NOT EXISTS password_reset_token_expires_at TIMESTAMP;",
		// Who the AI writes its feedback for: 'teacher' (addressed to the teacher,
		// the original and default behaviour) or 'coordinator' (written about the
		// teacher, for a coach to lead a conversation from). Requested by the
		// Mato Grosso TEACH coordinators, who read the feedback to the teacher
		// rather than being its subject.
		"ALTER TABLE users ADD COLUMN IF NOT EXISTS feedback_audience VARCHAR(20) DEFAULT 'teacher';",
		// Indexes
		"CREATE INDEX IF NOT EXISTS idx_users_verification_code ON users(email_verification_code);",
		"CREATE INDEX IF NOT EXISTS idx_users_reset_token ON users(password_reset_token);",
		// Admin/monitoring: index role for fast admin lookups and teacher filtering
		"CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);",
		"CREATE INDEX IF NOT EXISTS idx_recordings_created_at ON recordings(created_at);",
		// Manual scoring: pedagogy coaches score a recording against the same
		// TEACH framework as the AI. One score per (recording, coach) — upserted.
		`CREATE TABLE IF NOT EXISTS manual_scores (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			recording_id UUID NOT NULL REFERENCES recordings(id) ON DELETE CASCADE,
			scorer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

			-- TEACH Framework Scores (1-5, nullable = not scored / N/A)
			supportive_environment_score INTEGER CHECK (supportive_environment_score BETWEEN 1 AND 5),
			positive_expectations_score INTEGER CHECK (positive_expectations_score BETWEEN 1 AND 5),
			lesson_facilitation_score INTEGER CHECK (lesson_facilitation_score BETWEEN 1 AND 5),
			checks_understanding_score INTEGER CHECK (checks_understanding_score BETWEEN 1 AND 5),
			feedback_score INTEGER CHECK (feedback_score BETWEEN 1 AND 5),
			critical_thinking_score INTEGER CHECK (critical_thinking_score BETWEEN 1 AND 5),
			autonomy_score INTEGER CHECK (autonomy_score BETWEEN 1 AND 5),
			perseverance_score INTEGER CHECK (perseverance_score BETWEEN 1 AND 5),
			social_collaborative_score INTEGER CHECK (social_collaborative_score BETWEEN 1 AND 5),

			-- Per-element rationale text, keyed by element key
			element_rationales JSONB,

			-- Overall (computed average of provided element scores) + qualitative feedback
			overall_score DECIMAL(3,2),
			summary TEXT,
			strengths TEXT,
			areas_for_improvement TEXT,
			recommendations TEXT,
			notes TEXT,

			created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
			updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
			UNIQUE (recording_id, scorer_id)
		);`,
		"CREATE INDEX IF NOT EXISTS idx_manual_scores_recording_id ON manual_scores(recording_id);",
		// Coordinator flow: when a pedagogy coordinator records a lesson they
		// observed, the recording belongs to them, so the teacher who taught it
		// is not otherwise captured anywhere. Free text for now; becomes a
		// foreign key when W3 introduces coordinator→teacher links.
		"ALTER TABLE recordings ADD COLUMN IF NOT EXISTS observed_teacher_name VARCHAR(255);",
		// Coaching scripts: one per (recording, coordinator, TEACH element).
		// Generated on demand from the stored analysis, then kept — a coordinator
		// reopening the screen must see the same questions they read earlier,
		// not a freshly reworded set.
		`CREATE TABLE IF NOT EXISTS coach_scripts (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			recording_id UUID NOT NULL REFERENCES recordings(id) ON DELETE CASCADE,
			coordinator_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
			element_key VARCHAR(50) NOT NULL,
			language VARCHAR(10) NOT NULL DEFAULT 'en',

			-- The seven blocks requested by the Mato Grosso coordinators.
			observed_evidence JSONB,
			what_it_means TEXT,
			coach_question TEXT,
			follow_up_questions JSONB,
			possible_model TEXT,
			practice TEXT,
			next_step TEXT,

			ai_model_used VARCHAR(100),
			created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
			updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
			UNIQUE (recording_id, coordinator_id, element_key)
		);`,
		"CREATE INDEX IF NOT EXISTS idx_coach_scripts_recording_id ON coach_scripts(recording_id);",
	}

	for _, migration := range migrations {
		if _, err := db.Exec(migration); err != nil {
			// Log error but continue if it's just a duplicate column error or similar (though IF NOT EXISTS handles that)
			// But for debugging, let's return it
			return fmt.Errorf("failed to apply migration: %s, error: %w", migration, err)
		}
	}

	return nil
}
