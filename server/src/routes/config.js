const express = require('express');
const router = express.Router();
const settingsService = require('../services/settingsService');

/**
 * Get App Configuration
 * GET /api/config
 */
router.get('/', async (req, res, next) => {
    try {
        const active = await settingsService.getValue('notice_active', 'false');
        const version = await settingsService.getValue('notice_version', '0');
        const contentKo = await settingsService.getValue('notice_content_ko', '');
        const contentEn = await settingsService.getValue('notice_content_en', '');

        res.json({
            notice: {
                active: active === 'true',
                version: parseInt(version, 10),
                content: {
                    ko: contentKo,
                    en: contentEn
                }
            }
        });
    } catch (error) {
        next(error);
    }
});

module.exports = router;
