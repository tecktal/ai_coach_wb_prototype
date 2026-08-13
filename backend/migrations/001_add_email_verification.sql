-- Add email verification and password reset fields to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verification_code VARCHAR(6);
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verification_code_expires_at TIMESTAMP;
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_reset_token VARCHAR(64);
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_reset_token_expires_at TIMESTAMP;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_users_verification_code ON users(email_verification_code);
CREATE INDEX IF NOT EXISTS idx_users_reset_token ON users(password_reset_token);
