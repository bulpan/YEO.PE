-- Allow NULL for nickname_mask column to support named users (removing mask)
ALTER TABLE yeope_schema.users ALTER COLUMN nickname_mask DROP NOT NULL;
