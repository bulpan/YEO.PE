require('dotenv').config({ path: '../src/.env' }); // Try to load from src/.env if running from scripts dir
require('dotenv').config(); // Fallback to default .env

const { query } = require('../src/config/database');

const checkTokens = async () => {
    const userId = process.argv[2];
    if (!userId) {
        console.error('Usage: node check_tokens.js <userId>');
        process.exit(1);
    }

    try {
        console.log(`Checking tokens for user: ${userId}`);
        const res = await query(
            'SELECT * FROM yeope_schema.push_tokens WHERE user_id = $1',
            [userId]
        );

        if (res.rows.length === 0) {
            console.log('No tokens found for this user.');
        } else {
            console.log('Tokens found:');
            console.table(res.rows);
        }
    } catch (err) {
        console.error('Error querying database:', err);
    } finally {
        process.exit(0);
    }
};

checkTokens();
