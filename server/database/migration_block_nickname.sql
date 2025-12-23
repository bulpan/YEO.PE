-- Add blocked_nickname column to blocked_users table
ALTER TABLE yeope_schema.blocked_users 
ADD COLUMN IF NOT EXISTS blocked_nickname VARCHAR(100);

-- Update existing records to have a fallback nickname (optional, can be NULL)
-- UPDATE yeope_schema.blocked_users SET blocked_nickname = 'Unknown' WHERE blocked_nickname IS NULL;
