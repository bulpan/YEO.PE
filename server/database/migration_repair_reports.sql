-- Repair Reports Table
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Re-create table if missing (basic structure)
CREATE TABLE IF NOT EXISTS yeope_schema.reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Ensure all columns exist (Fix for "column does not exist" error)
ALTER TABLE yeope_schema.reports ADD COLUMN IF NOT EXISTS reporter_id UUID REFERENCES yeope_schema.users(id) ON DELETE SET NULL;
ALTER TABLE yeope_schema.reports ADD COLUMN IF NOT EXISTS reported_id UUID REFERENCES yeope_schema.users(id) ON DELETE SET NULL;
ALTER TABLE yeope_schema.reports ADD COLUMN IF NOT EXISTS reason TEXT;
ALTER TABLE yeope_schema.reports ADD COLUMN IF NOT EXISTS details TEXT;
ALTER TABLE yeope_schema.reports ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'pending';

-- Ensure reason column is TEXT to avoid length issues
ALTER TABLE yeope_schema.reports ALTER COLUMN reason TYPE TEXT;
-- Ensure details column is TEXT
ALTER TABLE yeope_schema.reports ALTER COLUMN details TYPE TEXT;

-- FIX for "target_id" constraint violation (Legacy schema support)
-- If target_id exists and is NOT NULL, it blocks our insert. Make it nullable.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='yeope_schema' AND table_name='reports' AND column_name='target_id') THEN
        ALTER TABLE yeope_schema.reports ALTER COLUMN target_id DROP NOT NULL;
    END IF;
END $$;


-- Ensure permissions
GRANT ALL PRIVILEGES ON yeope_schema.reports TO yeope_user;
