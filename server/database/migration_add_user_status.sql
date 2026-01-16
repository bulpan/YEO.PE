-- Add status and suspended_until columns to users table
ALTER TABLE yeope_schema.users ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'active';
ALTER TABLE yeope_schema.users ADD COLUMN IF NOT EXISTS suspended_until TIMESTAMP;

-- Create status index for performance
CREATE INDEX IF NOT EXISTS idx_users_status ON yeope_schema.users(status);
