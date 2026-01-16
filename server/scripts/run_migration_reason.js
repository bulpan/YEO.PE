const { query } = require('../src/config/database');
const fs = require('fs');
const path = require('path');

const run = async () => {
    try {
        const sql = fs.readFileSync(path.join(__dirname, '../database/migration_add_suspension_reason.sql'), 'utf8');
        await query(sql);
        console.log('Migration successful');
        process.exit(0);
    } catch (e) {
        console.error(e);
        process.exit(1);
    }
};

run();
