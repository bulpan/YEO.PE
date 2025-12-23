-- Add profile_image_url column to users table
ALTER TABLE yeope_schema.users ADD COLUMN IF NOT EXISTS profile_image_url TEXT;
