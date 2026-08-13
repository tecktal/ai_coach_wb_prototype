-- Add missing columns to recordings table
ALTER TABLE recordings ADD COLUMN IF NOT EXISTS failure_reason VARCHAR(100);
ALTER TABLE recordings ADD COLUMN IF NOT EXISTS error_message TEXT;
