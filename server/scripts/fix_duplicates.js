require('dotenv').config();
const { query, pool } = require('../src/config/database');
const logger = require('../src/utils/logger');

const runMigration = async () => {
    try {
        logger.info('🔧 Starting Duplicate Fix Migration...');

        // 1. Cleanup Duplicate Memberships (Keep Oldest)
        logger.info('Cleaning up duplicate active memberships...');
        const memberCleanup = await query(`
            DELETE FROM yeope_schema.room_members
            WHERE id IN (
                SELECT id FROM (
                    SELECT id,
                    ROW_NUMBER() OVER (PARTITION BY room_id, user_id ORDER BY joined_at ASC) as rnum
                    FROM yeope_schema.room_members
                    WHERE left_at IS NULL
                ) t
                WHERE t.rnum > 1
            )
        `);
        logger.info(`✅ Removed ${memberCleanup.rowCount} duplicate active memberships.`);

        // 2. Add Unique Index for Memberships
        logger.info('Adding unique index for active memberships...');
        await query(`
            CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_active_member 
            ON yeope_schema.room_members (room_id, user_id) 
            WHERE left_at IS NULL
        `);
        logger.info('✅ Index idx_unique_active_member created.');


        // 3. Cleanup Duplicate 1:1 Rooms (Keep Oldest)
        logger.info('Cleaning up duplicate 1:1 rooms...');
        const roomCleanup = await query(`
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
            )
        `);
        logger.info(`✅ Removed ${roomCleanup.rowCount} duplicate 1:1 rooms.`);


        // 4. Add Unique Index for 1:1 Rooms
        logger.info('Adding unique index for 1:1 rooms...');
        await query(`
            CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_1on1_room 
            ON yeope_schema.rooms (creator_id, ((metadata->>'inviteeId')::uuid)) 
            WHERE is_active = true 
            AND metadata->>'inviteeId' IS NOT NULL
        `);
        logger.info('✅ Index idx_unique_1on1_room created.');

        logger.info('🎉 Migration Completed Successfully!');

    } catch (error) {
        logger.error('❌ Migration Failed:', error);
    } finally {
        await pool.end();
    }
};

runMigration();
