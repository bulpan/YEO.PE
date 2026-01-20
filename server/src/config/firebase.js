const admin = require('firebase-admin');
const path = require('path');
const logger = require('../utils/logger');

let initialized = false;

const initializeFirebase = () => {
    if (initialized) return admin;

    try {
        const serviceAccountPath = process.env.FCM_SERVICE_ACCOUNT_PATH;
        const serviceAccountJson = process.env.FCM_SERVICE_ACCOUNT_JSON;

        let serviceAccount;

        if (serviceAccountPath) {
            const resolvedPath = path.isAbsolute(serviceAccountPath)
                ? serviceAccountPath
                : path.resolve(process.cwd(), serviceAccountPath);

            logger.info(`[FirebaseConfig] Loading config from: ${resolvedPath}`);
            serviceAccount = require(resolvedPath);
        } else if (serviceAccountJson) {
            logger.info('[FirebaseConfig] Loading config from JSON string');
            serviceAccount = JSON.parse(serviceAccountJson);
        } else {
            logger.warn('[FirebaseConfig] Service account not configured. Admin SDK not initialized.');
            return null;
        }

        if (admin.apps.length === 0) {
            admin.initializeApp({
                credential: admin.credential.cert(serviceAccount)
            });
            logger.info('[FirebaseConfig] Admin SDK Initialized');
        } else {
            logger.info('[FirebaseConfig] Admin SDK already initialized');
        }

        initialized = true;
        return admin;
    } catch (error) {
        logger.error('[FirebaseConfig] Initialization Failed:', error);
        return null;
    }
};

const adminInstance = initializeFirebase();

module.exports = {
    admin: adminInstance || admin,
    initializeFirebase
};
