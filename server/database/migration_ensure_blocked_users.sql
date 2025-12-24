-- Ensure blocked_users table exists
CREATE TABLE IF NOT EXISTS yeope_schema.blocked_users (
    id SERIAL PRIMARY KEY,
    blocker_id UUID NOT NULL REFERENCES yeope_schema.users(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES yeope_schema.users(id) ON DELETE CASCADE,
    blocked_nickname VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_block UNIQUE(blocker_id, blocked_id)
);

-- Index for faster blocked users lookup
CREATE INDEX IF NOT EXISTS idx_blocked_users_blocker ON yeope_schema.blocked_users(blocker_id);
