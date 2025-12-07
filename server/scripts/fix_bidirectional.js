require('dotenv').config();
const { query, pool } = require('../src/config/database');
const logger = require('../src/utils/logger');

const runMigration = async () => {
    try {
        logger.info('🔧 Starting Bidirectional Duplicate Cleanup...');

        // 1. Find Bidirectional Pairs
        // R1: Creator A, Invitee B
        // R2: Creator B, Invitee A
        // We want to identify them and pick a winner.
        const pairsQuery = `
            SELECT 
                r1.id as r1_id, r1.room_id as r1_resid, r1.creator_id as r1_creator, r1.created_at as r1_created,
                (SELECT COUNT(*) FROM yeope_schema.messages m WHERE m.room_id = r1.id) as r1_msgs,
                r2.id as r2_id, r2.room_id as r2_resid, r2.creator_id as r2_creator, r2.created_at as r2_created,
                (SELECT COUNT(*) FROM yeope_schema.messages m WHERE m.room_id = r2.id) as r2_msgs
            FROM yeope_schema.rooms r1
            JOIN yeope_schema.rooms r2 
              ON r1.creator_id = (r2.metadata->>'inviteeId')::uuid 
              AND (r1.metadata->>'inviteeId')::uuid = r2.creator_id
            WHERE r1.is_active = true AND r2.is_active = true
            AND r1.id < r2.id -- Avoid double counting (A-B vs B-A)
        `;

        const pairs = await query(pairsQuery);
        logger.info(`Found ${pairs.rowCount} bidirectional pairs.`);

        for (const pair of pairs.rows) {
            logger.info(`Checking Pair: ${pair.r1_resid} vs ${pair.r2_resid}`);

            let winnerId, loserId;

            // Decision Logic: Keep the one with MORE messages.
            if (parseInt(pair.r1_msgs) > parseInt(pair.r2_msgs)) {
                winnerId = pair.r1_id;
                loserId = pair.r2_id;
            } else if (parseInt(pair.r2_msgs) > parseInt(pair.r1_msgs)) {
                winnerId = pair.r2_id;
                loserId = pair.r1_id;
            } else {
                // Tie: Keep Oldest
                if (pair.r1_created < pair.r2_created) {
                    winnerId = pair.r1_id;
                    loserId = pair.r2_id;
                } else {
                    winnerId = pair.r2_id;
                    loserId = pair.r1_id;
                }
            }

            logger.info(`   -> Winner: ${winnerId} (Msgs: ${pair.r1_id == winnerId ? pair.r1_msgs : pair.r2_msgs})`);
            logger.info(`   -> Deleting Loser: ${loserId}`);

            // Delete Loser
            await query(`DELETE FROM yeope_schema.rooms WHERE id = $1`, [loserId]);
        }

        logger.info('🎉 Bidirectional Cleanup Completed!');

    } catch (error) {
        logger.error('❌ Migration Failed:', error);
    } finally {
        await pool.end();
    }
};

runMigration();
