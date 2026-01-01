-- Blocked Users Table
CREATE TABLE IF NOT EXISTS yeope_schema.blocked_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_id UUID REFERENCES yeope_schema.users(id) ON DELETE CASCADE,
    blocked_id UUID REFERENCES yeope_schema.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(blocker_id, blocked_id)
);

-- Reports Table
CREATE TABLE IF NOT EXISTS yeope_schema.reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID REFERENCES yeope_schema.users(id) ON DELETE SET NULL,
    reported_id UUID REFERENCES yeope_schema.users(id) ON DELETE SET NULL,
    reason VARCHAR(50) NOT NULL, -- 'spam', 'abusive', 'inappropriate', 'other'
    details TEXT,
    status VARCHAR(50) DEFAULT 'pending', -- 'pending', 'reviewed', 'resolved'
    created_at TIMESTAMP DEFAULT NOW()
);

-- Ensure status column exists (for existing tables)
ALTER TABLE yeope_schema.reports ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'pending';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_blocked_blocker ON yeope_schema.blocked_users(blocker_id);
CREATE INDEX IF NOT EXISTS idx_reports_status ON yeope_schema.reports(status);
