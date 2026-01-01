const pushService = require('./src/services/pushService');
const logger = require('./src/utils/logger');

// Mock IO
const mockIo = {
    sockets: {
        adapter: {
            rooms: {
                get: (name) => {
                    console.log('Checking room:', name);
                    return new Set(['socket1']); // Mock Set
                }
            }
        },
        sockets: {
            get: (id) => {
                console.log('Get socket:', id);
                return { userId: 'user1' };
            }
        }
    }
};

async function test() {
    console.log('Testing sendMessageNotification...');
    try {
        const res = await pushService.sendMessageNotification(
            'room1',
            'sender1',
            'Nick',
            'Hello',
            'text',
            mockIo
        );
        console.log('Result:', res);
    } catch (e) {
        console.error('CRASH:', e);
    }
    process.exit(0);
}

test();
