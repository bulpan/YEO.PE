ALTER TABLE yeope_schema.users ADD COLUMN IF NOT EXISTS phone_number VARCHAR(20);
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_phone_number ON yeope_schema.users(phone_number);
