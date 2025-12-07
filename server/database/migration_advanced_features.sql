-- Add status column to rooms table
ALTER TABLE yeope_schema.rooms ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'active';

-- Update existing rooms to have status 'active'
UPDATE yeope_schema.rooms SET status = 'active' WHERE status IS NULL;

-- Add index for status
CREATE INDEX IF NOT EXISTS idx_rooms_status ON yeope_schema.rooms(status);
