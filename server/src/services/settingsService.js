/**
 * 시스템 설정 서비스
 * Global System Settings
 */

const { query } = require('../config/database');
const logger = require('../utils/logger');

/**
 * 설정값 가져오기
 * @param {string} key 
 * @param {string} defaultValue 
 */
const getValue = async (key, defaultValue = null) => {
    try {
        const result = await query(
            'SELECT value FROM yeope_schema.system_settings WHERE key = $1',
            [key]
        );
        if (result.rows.length > 0) {
            return result.rows[0].value;
        }
        return defaultValue;
    } catch (error) {
        logger.error(`Failed to get setting ${key}: ${error.message}`);
        return defaultValue;
    }
};

/**
 * 모든 설정 가져오기
 */
const getAll = async () => {
    const result = await query('SELECT * FROM yeope_schema.system_settings');
    const settings = {};
    result.rows.forEach(row => {
        settings[row.key] = row.value;
    });
    return settings;
};

/**
 * 설정값 저장/업데이트
 * @param {string} key 
 * @param {string} value 
 */
const setValue = async (key, value) => {
    await query(
        `INSERT INTO yeope_schema.system_settings (key, value, updated_at) 
         VALUES ($1, $2, NOW()) 
         ON CONFLICT (key) DO UPDATE 
         SET value = EXCLUDED.value, updated_at = NOW()`,
        [key, value]
    );
    return true;
};

module.exports = {
    getValue,
    getAll,
    setValue
};
