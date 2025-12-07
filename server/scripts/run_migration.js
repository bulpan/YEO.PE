require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { query, pool } = require('../src/config/database');

const runMigration = async () => {
    try {
        const sqlPath = path.join(__dirname, '../database/migration_advanced_features.sql');
        const sql = fs.readFileSync(sqlPath, 'utf8');

        console.log('Running migration...');
        await query(sql);
        console.log('Migration completed successfully.');
    } catch (error) {
        console.error('Migration failed:', error);
    } finally {
        await pool.end();
    }
};

runMigration();
