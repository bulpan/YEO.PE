/**
 * Log Data Sanitizer
 * - Masks sensitive fields (password, token, etc.)
 * - Truncates excessively long arrays/strings
 */
function sanitize(obj) {
    if (!obj) return obj;
    if (typeof obj !== 'object') return obj; // Return primitives as is

    // Deep copy to avoid mutating original
    if (Array.isArray(obj)) {
        if (obj.length > 20) {
            return `[Array(${obj.length})]`;
        }
        return obj.map(item => sanitize(item));
    }

    const result = {};
    Object.keys(obj).forEach(key => {
        const val = obj[key];

        // Mask sensitive keys
        if (key.match(/password|token|secret|key|authorization/i)) {
            result[key] = '***';
        }
        // Handle long arrays
        else if (Array.isArray(val) && val.length > 20) {
            result[key] = `[Array(${val.length})]`;
        }
        // Handle deeply nested objects
        else if (typeof val === 'object' && val !== null) {
            result[key] = sanitize(val);
        }
        // Truncate long strings (e.g. base64 images)
        else if (typeof val === 'string' && val.length > 1000) {
            result[key] = val.substring(0, 100) + '... (truncated)';
        }
        else {
            result[key] = val;
        }
    });

    return result;
}

module.exports = sanitize;
