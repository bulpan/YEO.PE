/**
 * Delete All Rooms Script
 */
require('dotenv').config();
const { pool } = require('../src/config/database');

async function cleanup() {
    try {
        console.log('🗑️ Deleting all rooms...');

        // CASCADE will remove room_members and messages automatically
        await pool.query('TRUNCATE TABLE yeope_schema.rooms CASCADE');

        console.log('✅ All rooms deleted successfully.');
    } catch (err) {
        console.error('❌ Error deleting rooms:', err);
    } finally {
        pool.end();
    }
}

cleanup();
