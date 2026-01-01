/**
 * 푸시 알림 워커 (Consumer)
 * - Redis Queue에서 작업을 꺼내 pushLogic을 실행함
 */

const { pushQueue } = require('../services/pushService');
const pushLogic = require('../services/pushLogic');
const logger = require('../utils/logger');

const startWorker = () => {
    logger.info('[PushWorker] Starting Worker...');

    // Initialize Firebase in Worker context
    pushLogic.initializeFirebase();

    // 1. Message Notification
    pushQueue.process('MESSAGE', async (job) => {
        logger.info(`[PushWorker] Processing MESSAGE job ${job.id}`);
        try {
            const result = await pushLogic.processSendMessage(job.data);
            return result;
        } catch (error) {
            logger.error(`[PushWorker] Job ${job.id} Failed:`, error);
            throw error; // Bull will retry
        }
    });

    // 2. Nearby User Notification
    pushQueue.process('NEARBY', async (job) => {
        logger.info(`[PushWorker] Processing NEARBY job ${job.id}`);
        try {
            const result = await pushLogic.processNearbyUser(job.data);
            return result;
        } catch (error) {
            logger.error(`[PushWorker] Job ${job.id} Failed:`, error);
            throw error;
        }
    });

    // 3. Room Invite
    pushQueue.process('ROOM_INVITE', async (job) => {
        logger.info(`[PushWorker] Processing ROOM_INVITE job ${job.id}`);
        try {
            const result = await pushLogic.processRoomInvite(job.data);
            return result;
        } catch (error) {
            logger.error(`[PushWorker] Job ${job.id} Failed:`, error);
            throw error;
        }
    });

    // 4. Room Created (Usually triggers nearby notification)
    pushQueue.process('ROOM_CREATED', async (job) => {
        logger.info(`[PushWorker] Processing ROOM_CREATED job ${job.id}`);
        try {
            const result = await pushLogic.processRoomCreated(job.data);
            return result;
        } catch (error) {
            logger.error(`[PushWorker] Job ${job.id} Failed:`, error);
            throw error;
        }
    });

    // 4. Quick Question
    pushQueue.process('QUICK_QUESTION', async (job) => {
        logger.info(`[PushWorker] Processing QUICK_QUESTION job ${job.id}`);
        try {
            const result = await pushLogic.processQuickQuestion(job.data);
            return result;
        } catch (error) {
            logger.error(`[PushWorker] Job ${job.id} Failed:`, error);
            throw error;
        }
    });

    // Event Listeners
    pushQueue.on('completed', (job, result) => {
        logger.info(`[PushWorker] Job ${job.id} Completed. Result:`, result);
    });

    pushQueue.on('failed', (job, err) => {
        logger.warn(`[PushWorker] Job ${job.id} Failed. Attempts: ${job.attemptsMade}. Error: ${err.message}`);
    });

    logger.info('[PushWorker] Worker Ready and Listening');
};

module.exports = { startWorker };
