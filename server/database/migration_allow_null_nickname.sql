-- Allow NULL for nickname column to support anonymous-only users (New Mask)
ALTER TABLE yeope_schema.users ALTER COLUMN nickname DROP NOT NULL;
