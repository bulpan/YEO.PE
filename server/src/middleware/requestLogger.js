const logger = require('../utils/logger');
const sanitize = require('../utils/sanitizer');

const requestLogger = (req, res, next) => {
    const start = Date.now();
    const { method, url, body, query, params } = req;

    // Exclude recursive log endpoints
    if (url.includes('/api/admin/logs')) {
        return next();
    }

    // 1. Log Incoming Request (Existing logic...)
    logger.info(`[API Request] ${method} ${url}`, {
        body: sanitize(body),
        query: query,
        ip: req.ip
    });

    // 2. Capture Response Body (Existing logic...)
    const originalSend = res.send;
    const originalJson = res.json;
    let responseBody;

    res.send = function (data) {
        responseBody = data;
        return originalSend.apply(this, arguments);
    };

    res.json = function (data) {
        responseBody = data;
        return originalJson.apply(this, arguments);
    };

    // 3. Log Response on Finish (Existing logic...)
    res.on('finish', () => {
        const duration = Date.now() - start;
        let logBody = responseBody;

        // Truncate long strings or mask sensitive info if needed
        try {
            if (typeof logBody === 'string') {
                // Attempt to parse JSON string response
                try {
                    const parsed = JSON.parse(logBody);
                    logBody = sanitize(parsed);
                } catch (e) {
                    // Not JSON
                    if (logBody.length > 500) {
                        logBody = logBody.substring(0, 500) + '... (truncated)';
                    }
                }
            } else {
                logBody = sanitize(logBody);
            }
        } catch (e) {
            logBody = '[Log Error]';
        }

        const logLevel = res.statusCode >= 400 ? 'warn' : 'info';

        logger.log(logLevel, `[API Response] ${method} ${url} ${res.statusCode} (${duration}ms)`, {
            status: res.statusCode,
            response: logBody,
            duration: duration
        });
    });

    next();
};

module.exports = requestLogger;
