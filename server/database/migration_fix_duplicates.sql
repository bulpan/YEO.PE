BEGIN;

-- 1. Cleanup Duplicate Active Memberships (Keep Oldest)
DELETE FROM yeope_schema.room_members
WHERE id IN (
    SELECT id FROM (
        SELECT id,
        ROW_NUMBER() OVER (PARTITION BY room_id, user_id ORDER BY joined_at ASC) as rnum
        FROM yeope_schema.room_members
        WHERE left_at IS NULL
    ) t
    WHERE t.rnum > 1
);

-- 2. Add Unique Index for Active Memberships
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_active_member 
ON yeope_schema.room_members (room_id, user_id) 
WHERE left_at IS NULL;

-- 3. Cleanup Duplicate 1:1 Rooms (Keep Oldest)
DELETE FROM yeope_schema.rooms
WHERE id IN (
    SELECT id FROM (
        SELECT id,
        ROW_NUMBER() OVER (PARTITION BY creator_id, (metadata->>'inviteeId') ORDER BY created_at ASC) as rnum
        FROM yeope_schema.rooms
        WHERE is_active = true 
        AND metadata->>'inviteeId' IS NOT NULL
    ) t
    WHERE t.rnum > 1
);

-- 4. Add Unique Index for 1:1 Rooms
-- Note: Cast inviteeId string to uuid for correct indexing
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_1on1_room 
ON yeope_schema.rooms (creator_id, ((metadata->>'inviteeId')::uuid)) 
WHERE is_active = true 
AND metadata->>'inviteeId' IS NOT NULL;

COMMIT;
