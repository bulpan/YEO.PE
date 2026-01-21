-- Migration: Add Inquiries Table
-- Description: Stores 1:1 user inquiries and admin answers

CREATE TABLE IF NOT EXISTS yeope_schema.inquiries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES yeope_schema.users(id) ON DELETE CASCADE,
    category VARCHAR(50) NOT NULL, -- 'bug', 'complaint', 'suggestion', 'other'
    content TEXT NOT NULL,
    answer TEXT, -- Nullable, filled when admin replies
    status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'answered'
    is_read_by_user BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    answered_at TIMESTAMP WITH TIME ZONE
);

-- Index for faster lookup by user
CREATE INDEX IF NOT EXISTS idx_inquiries_user_id ON yeope_schema.inquiries(user_id);
-- Index for admin to filter by status
CREATE INDEX IF NOT EXISTS idx_inquiries_status ON yeope_schema.inquiries(status);
