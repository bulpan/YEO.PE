-- Create login_logs table for tracking user traffic
CREATE TABLE IF NOT EXISTS yeope_schema.login_logs (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES yeope_schema.users(id) ON DELETE CASCADE,
    platform VARCHAR(20) DEFAULT 'unknown', -- 'ios', 'android', 'web'
    ip_address VARCHAR(45),
    login_at TIMESTAMP DEFAULT NOW()
);

-- Create index for time-based queries
CREATE INDEX IF NOT EXISTS idx_login_logs_login_at ON yeope_schema.login_logs(login_at);
CREATE INDEX IF NOT EXISTS idx_login_logs_platform ON yeope_schema.login_logs(platform);
