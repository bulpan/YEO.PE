// Set mock env before require
process.env.FCM_SERVICE_ACCOUNT_JSON = '{"project_id": "mock-project"}';

const pushService = require('../src/services/pushService');
const { query } = require('../src/config/database');

// Mock dependencies
jest.mock('../src/config/database');
jest.mock('../src/services/tokenService', () => ({
    getActivePushTokensForUsers: jest.fn()
}));
const tokenService = require('../src/services/tokenService');

jest.mock('firebase-admin', () => ({
    credential: {
        cert: jest.fn()
    },
    initializeApp: jest.fn(),
    messaging: () => ({
        send: jest.fn().mockResolvedValue('mock-message-id'),
        sendEachForMulticast: jest.fn().mockResolvedValue({ successCount: 1, failureCount: 0, responses: [] })
    })
}));
jest.mock('../src/utils/logger', () => ({
    info: jest.fn(),
    error: jest.fn(),
    warn: jest.fn()
}));

describe('Push Notification Logic', () => {
    const roomId = 'test-room-id';
    const senderId = 'sender-user-id';
    const receiverId = 'receiver-user-id';
    const senderNickname = 'Sender';

    beforeEach(() => {
        jest.clearAllMocks();
    });

    test('should send push notification to disconnected user', async () => {
        // 1. Mock DB response: Receiver is a member of the room
        query.mockResolvedValueOnce({
            rows: [{ user_id: receiverId }]
        });

        // 2. Mock tokenService response: Receiver has an active push token
        tokenService.getActivePushTokensForUsers.mockResolvedValueOnce({
            [receiverId]: [{ token: 'test-token', platform: 'ios' }]
        });

        // 3. Mock Socket.io: Receiver is NOT connected
        const mockIo = {
            in: jest.fn().mockReturnThis(),
            fetchSockets: jest.fn().mockResolvedValue([
                { userId: senderId } // Only sender is connected
            ])
        };

        // 4. Call the function
        const result = await pushService.sendMessageNotification(
            roomId,
            senderId,
            senderNickname,
            'Hello',
            'text',
            mockIo
        );

        // 5. Verification
        // Should have queried room members
        expect(query).toHaveBeenCalledWith(expect.stringContaining('SELECT DISTINCT rm.user_id'), [roomId, senderId]);

        // Should have called tokenService
        expect(tokenService.getActivePushTokensForUsers).toHaveBeenCalledWith([receiverId]);

        // Should have checked connected sockets
        expect(mockIo.in).toHaveBeenCalledWith(`room:${roomId}`);
        expect(mockIo.fetchSockets).toHaveBeenCalled();

        // Should have sent push notification (because receiver was not in fetchSockets)
        expect(result.success).toBe(true);
        expect(result.successCount).toBe(1);
    });

    test('should NOT send push notification to connected user', async () => {
        // 1. Mock DB response: Receiver is a member
        query.mockResolvedValueOnce({
            rows: [{ user_id: receiverId }]
        });

        // 2. Mock tokenService response
        tokenService.getActivePushTokensForUsers.mockResolvedValueOnce({
            [receiverId]: [{ token: 'test-token', platform: 'ios' }]
        });

        // 3. Mock Socket.io: Receiver IS connected
        const mockIo = {
            in: jest.fn().mockReturnThis(),
            fetchSockets: jest.fn().mockResolvedValue([
                { userId: senderId },
                { userId: receiverId } // Receiver is also connected
            ])
        };

        // 4. Call the function
        const result = await pushService.sendMessageNotification(
            roomId,
            senderId,
            senderNickname,
            'Hello',
            'text',
            mockIo
        );

        // 5. Verification
        // Should return success but sent 0 because user is connected
        expect(result.success).toBe(true);
        expect(result.sent).toBe(0);
        expect(result.reason).toBe('All users connected or no tokens');
    });
});
