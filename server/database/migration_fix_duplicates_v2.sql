BEGIN;

-- 1. Cleanup Duplicate 1:1 Rooms (Broader Scope)
-- Partitions by Creator+Invitee.
-- Orders by:
--   1. is_active DESC (True first, so we keep Active over Inactive)
--   2. created_at ASC (Oldest first, so we keep the original)
-- Deletes anything that is row_number > 1 (i.e. the "Inactive" or "Newer" duplicates)
DELETE FROM yeope_schema.rooms
WHERE id IN (
    SELECT id FROM (
        SELECT id,
        ROW_NUMBER() OVER (
            PARTITION BY creator_id, (metadata->>'inviteeId') 
            ORDER BY is_active DESC, created_at ASC
        ) as rnum
        FROM yeope_schema.rooms
        WHERE metadata->>'inviteeId' IS NOT NULL
    ) t
    WHERE t.rnum > 1
);

-- 2. Drop the weak index (if it exists)
DROP INDEX IF EXISTS yeope_schema.idx_unique_1on1_room;

-- 3. Re-create Stronger Unique Index (No 'is_active' filter)
-- This ensures that for a given Creator+Invitee, only ONE room can exist PERIOD.
-- Even if one is inactive, you cannot create another.
CREATE UNIQUE INDEX idx_unique_1on1_room 
ON yeope_schema.rooms (creator_id, ((metadata->>'inviteeId')::uuid)) 
WHERE metadata->>'inviteeId' IS NOT NULL;

COMMIT;
