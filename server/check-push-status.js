require('dotenv').config();
const { query } = require('./src/config/database');

async function checkPushStatus() {
    try {
        const dbPort = 5432; // Force 5432 as docker-compose exposes this, .env has 5433 (wrong)
        process.env.DB_PORT = dbPort;
        console.log(`🔍 Checking Push Notification Status (DB: ${process.env.DB_HOST}:${dbPort})...`);

        // 1. Check if there are ANY tokens
        const tokensRes = await query(`
      SELECT COUNT(*) as total, 
             COUNT(*) FILTER (WHERE is_active = true) as active 
      FROM yeope_schema.push_tokens
    `);
        console.log(`📊 Total Tokens: ${tokensRes.rows[0].total} (Active: ${tokensRes.rows[0].active})`);

        // 2. List recent active tokens with user info
        const recentTokens = await query(`
      SELECT pt.user_id, u.nickname, pt.device_token, pt.is_active, pt.platform, pt.updated_at
      FROM yeope_schema.push_tokens pt
      JOIN yeope_schema.users u ON pt.user_id = u.id
      WHERE pt.is_active = true
      ORDER BY pt.updated_at DESC
      LIMIT 10
    `);

        console.log('\n📱 Recent Active Tokens:');
        if (recentTokens.rows.length === 0) {
            console.log('   (No active tokens found)');
        } else {
            recentTokens.rows.forEach(row => {
                const tokenMask = row.device_token ? `${row.device_token.substring(0, 10)}...` : 'null';
                console.log(`   - User: ${row.nickname} (ID: ${row.user_id}) | Token: ${tokenMask} | Platform: ${row.platform} | Updated: ${row.updated_at}`);
            });
        }

        // 3. Check User Settings (Push Enabled) on Recent Active Users
        const settingsRes = await query(`
        SELECT id, nickname, settings 
        FROM yeope_schema.users 
        WHERE id IN (SELECT user_id FROM yeope_schema.push_tokens WHERE is_active = true)
        ORDER BY updated_at DESC 
        LIMIT 5
    `);

        console.log('\n⚙️  User Settings (Users with Active Tokens):');
        if (settingsRes.rows.length === 0) {
            console.log('   (No users with active tokens found)');
        } else {
            settingsRes.rows.forEach(row => {
                let settings = row.settings;
                if (typeof settings === 'string') {
                    try { settings = JSON.parse(settings); } catch (e) { }
                }
                const pushEnabled = settings?.pushEnabled !== false; // Default true
                console.log(`   - User: ${row.nickname} | Push Enabled: ${pushEnabled} (Raw: ${JSON.stringify(settings)})`);
            });
        }

        process.exit(0);
    } catch (error) {
        console.error('❌ Error checking status:', error);
        process.exit(1);
    }
}

checkPushStatus();
