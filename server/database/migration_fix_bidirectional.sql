BEGIN;

-- Cleanup Bidirectional Duplicates (A->B and B->A)
-- Logic: Pair them up. Count messages only works if correlated subquery.
-- We will delete the one with FEWER messages. If equal, delete the NEWER one (Keep oldest).

WITH Pairs AS (
    SELECT 
        r1.id as r1_id, r1.created_at as r1_created,
        (SELECT COUNT(*) FROM yeope_schema.messages m WHERE m.room_id = r1.id) as r1_msgs,
        r2.id as r2_id, r2.created_at as r2_created,
        (SELECT COUNT(*) FROM yeope_schema.messages m WHERE m.room_id = r2.id) as r2_msgs
    FROM yeope_schema.rooms r1
    JOIN yeope_schema.rooms r2 
      ON r1.creator_id = (r2.metadata->>'inviteeId')::uuid 
      AND (r1.metadata->>'inviteeId')::uuid = r2.creator_id
    WHERE r1.is_active = true AND r2.is_active = true
    AND r1.id < r2.id -- Ensure we only grab the pair once
),
Losers AS (
    SELECT 
        CASE 
            WHEN r1_msgs > r2_msgs THEN r2_id -- R1 has more, kill R2
            WHEN r2_msgs > r1_msgs THEN r1_id -- R2 has more, kill R1
            -- Tie: Keep Oldest (kill newest)
            WHEN r1_created < r2_created THEN r2_id
            ELSE r1_id
        END as loser_id
    FROM Pairs
)
DELETE FROM yeope_schema.rooms
WHERE id IN (SELECT loser_id FROM Losers);

COMMIT;
