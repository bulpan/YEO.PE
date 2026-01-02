
const { Pool } = require('pg');

// Override environment BEFORE requiring anything else
process.env.DB_HOST = 'localhost';
process.env.DB_PORT = '5435';
process.env.DB_USER = 'yeope_user';
process.env.DB_PASSWORD = 'yeope_password_2024';
process.env.DB_NAME = 'yeope';

const pool = new Pool({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
});

async function checkDuplicates() {
    try {
        console.log(`Connecting to DB at ${process.env.DB_HOST}:${process.env.DB_PORT}...`);

        // 1. Find Users with > 1 active tokens
        const res = await pool.query(`
            SELECT user_id, COUNT(*) as token_count
            FROM yeope_schema.push_tokens
            WHERE is_active = true
            GROUP BY user_id
            HAVING COUNT(*) > 1
        `);

        if (res.rows.length === 0) {
            console.log("✅ No users have multiple active tokens.");
        } else {
            console.log(`⚠️  Found ${res.rows.length} user(s) with multiple active tokens:`);

            for (const row of res.rows) {
                console.log(`   User ${row.user_id}: ${row.token_count} tokens`);

                // Detail List
                const details = await pool.query(`
                    SELECT id, device_token, device_id, platform, created_at, updated_at 
                    FROM yeope_schema.push_tokens 
                    WHERE user_id = $1 AND is_active = true
                `, [row.user_id]);

                details.rows.forEach(t => {
                    const mask = t.device_token.substring(0, 15) + '...';
                    console.log(`      - ID: ${t.id} | DevID: ${t.device_id || 'NULL'} | Token: ${mask} | Platform: ${t.platform} | Created: ${t.created_at}`);
                });
            }
        }
    } catch (e) {
        console.error("Error:", e);
    } finally {
        pool.end();
    }
}

checkDuplicates();
