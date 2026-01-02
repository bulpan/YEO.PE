BEGIN;

-- 1. Identiy and Deactivate Duplicate Tokens (Same User, Same Platform)
-- Strategy: If a user has multiple active tokens for the same platform,
-- we might have "zombie" tokens if the previous cleanup failed (e.g. unknown device_id).
-- We will keep only the MOST RECENTLY UPDATED token per (user_id, platform).
-- WARNING: This assumes a user only uses ONE device per platform (e.g. 1 iPhone).
-- If support for Mutiple iOS devices is strictly required, this needs refinement,
-- but for fixing "Double Push" on a single phone, this is the cure.

UPDATE yeope_schema.push_tokens
SET is_active = false, updated_at = NOW()
WHERE id IN (
    SELECT id FROM (
        SELECT id,
        ROW_NUMBER() OVER (PARTITION BY user_id, platform ORDER BY updated_at DESC) as rnum
        FROM yeope_schema.push_tokens
        WHERE is_active = true
    ) t
    WHERE t.rnum > 1
);

COMMIT;
