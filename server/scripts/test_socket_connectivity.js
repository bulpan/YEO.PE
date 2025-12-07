/**
 * Test Socket Connectivity
 * Verifies that messages are delivered via Socket.io when users are in the same room.
 */

const io = require('socket.io-client');
const axios = require('axios');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const API_URL = `http://localhost:${process.env.PORT || 3000}/api`;
const SOCKET_URL = `http://localhost:${process.env.PORT || 3000}`;

// Helper: Register and Login
async function getAuthToken(nickname) {
    try {
        const email = `test_${nickname}_${Date.now()}@example.com`;
        const password = 'password123';
        const deviceId = `device_${nickname}_${Date.now()}`;

        // Register
        await axios.post(`${API_URL}/auth/register`, {
            email, password, nickname, deviceId
        });

        // Login
        const res = await axios.post(`${API_URL}/auth/login`, {
            email, password, deviceId
        });

        return { token: res.data.token, userId: res.data.user.id };
    } catch (error) {
        console.error(`Auth failed for ${nickname}:`, error.response?.data || error.message);
        throw error;
    }
}

// Helper: Create Room
async function createRoom(token, name) {
    try {
        const res = await axios.post(`${API_URL}/rooms`, {
            name, category: 'general'
        }, {
            headers: { Authorization: `Bearer ${token}` }
        });
        return res.data; // { id, roomId, ... }
    } catch (error) {
        console.error('Create Room failed:', error.response?.data || error.message);
        throw error;
    }
}

async function runTest() {
    console.log('--- Starting Socket Connectivity Test ---');

    // 1. Setup Users
    const userA = await getAuthToken('Andi');
    console.log(`User A (Andi) ready: ${userA.userId}`);

    const userB = await getAuthToken('Bulpan');
    console.log(`User B (Bulpan) ready: ${userB.userId}`);

    // 2. Setup Sockets
    const socketA = io(SOCKET_URL, {
        auth: { token: userA.token },
        transports: ['websocket']
    });

    const socketB = io(SOCKET_URL, {
        auth: { token: userB.token },
        transports: ['websocket']
    });

    // Wait for connections
    await new Promise(resolve => {
        let connected = 0;
        const check = () => { if (++connected === 2) resolve(); };
        socketA.on('connect', () => { console.log('Socket A connected'); check(); });
        socketB.on('connect', () => { console.log('Socket B connected'); check(); });
    });

    // 3. User A creates Room "Holo"
    const room = await createRoom(userA.token, 'Holo');
    console.log(`Room "Holo" created: ${room.roomId} (UUID)`);

    // 4. Join Room (Socket)
    // User A joins (implicitly via create usually, but let's explicit socket join)
    socketA.emit('join-room', { roomId: room.roomId });

    // Wait for A to join
    await new Promise(resolve => socketA.once('room-joined', resolve));
    console.log('User A joined socket room');

    // User B joins via API (optional but realistic) and Socket
    // (Skipping API join for B to test pure socket, but API join is usually required for permission)
    // Let's call API join first as Client does
    try {
        await axios.post(`${API_URL}/rooms/${room.roomId}/join`, {}, {
            headers: { Authorization: `Bearer ${userB.token}` }
        });
    } catch (e) {
        console.log('API Join error (ignore if just logging):', e.message);
    }

    socketB.emit('join-room', { roomId: room.roomId });

    // Wait for B to join
    await new Promise(resolve => socketB.once('room-joined', resolve));
    console.log('User B joined socket room');

    // 5. User A sends Message
    console.log('User A sending message...');
    const messageContent = 'Hello Bulpan from Socket!';
    socketA.emit('send-message', {
        roomId: room.roomId,
        type: 'text',
        content: messageContent
    });

    // 6. Verify User B receives it
    console.log('Waiting for message on User B socket...');

    const received = await new Promise((resolve, reject) => {
        const timeout = setTimeout(() => reject(new Error('Timeout waiting for message')), 5000);

        socketB.on('new-message', (data) => {
            clearTimeout(timeout);
            resolve(data);
        });
    });

    console.log('User B Received Message:', received);

    if (received.content === messageContent) {
        console.log('✅ TEST PASSED: Message received via Socket');
    } else {
        console.error('❌ TEST FAILED: Content mismatch');
    }

    // Cleanup
    socketA.disconnect();
    socketB.disconnect();
    console.log('Test Complete');
}

runTest().catch(err => {
    console.error('Test Failed:', err);
    process.exit(1);
});
