-- Create appeals table
CREATE TABLE IF NOT EXISTS yeope_schema.appeals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES yeope_schema.users(id),
    reason TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'pending', -- pending, approved, rejected
    admin_comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_appeals_user_id ON yeope_schema.appeals(user_id);
CREATE INDEX idx_appeals_status ON yeope_schema.appeals(status);
