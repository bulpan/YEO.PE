const axios = require('axios');
const io = require('socket.io-client');
const { expect } = require('@jest/globals');

// Configuration
const API_URL = 'http://localhost:3000/api';
const SOCKET_URL = 'http://localhost:3000';

// Test Data
const users = [
    { email: `userA_${Date.now()}@test.com`, password: 'password123', nickname: 'UserA' },
    { email: `userB_${Date.now()}@test.com`, password: 'password123', nickname: 'UserB' },
    { email: `userC_${Date.now()}@test.com`, password: 'password123', nickname: 'UserC' }
];

let tokens = {};
let userIds = {};
let sockets = {};
let roomAlphaId = null;

// Helper to create socket connection
const connectSocket = (token) => {
    return new Promise((resolve, reject) => {
        const socket = io(SOCKET_URL, {
            auth: { token },
            transports: ['websocket'],
            forceNew: true
        });

        socket.on('connect', () => resolve(socket));
        socket.on('connect_error', (err) => reject(err));
    });
};

describe('Full Simulation Scenario: Users A, B, C', () => {
    // 1. User Registration & Login
    test('1. Register and Login 3 Users', async () => {
        for (const user of users) {
            // Register
            try {
                await axios.post(`${API_URL}/auth/register`, user);
            } catch (e) {
                // Ignore if already exists (for re-runs)
            }

            // Login
            const res = await axios.post(`${API_URL}/auth/login`, {
                email: user.email,
                password: user.password
            });

            expect(res.status).toBe(200);
            expect(res.data.token).toBeDefined();

            tokens[user.nickname] = res.data.token;

            // Decode token to get userId (simple way without library)
            const payload = JSON.parse(Buffer.from(res.data.token.split('.')[1], 'base64').toString());
            userIds[user.nickname] = payload.userId;

            console.log(`✅ ${user.nickname} Logged in (ID: ${userIds[user.nickname]})`);
        }
    });

    // 2. Room Creation & Duplicate Check
    test('2. Room Creation with Duplicate Check', async () => {
        const tokenA = tokens['UserA'];
        const tokenB = tokens['UserB'];
        const tokenC = tokens['UserC'];

        // A creates "Room Alpha"
        const resA = await axios.post(`${API_URL}/rooms`, {
            name: 'Room Alpha',
            category: 'general',
            nearbyUserIds: [userIds['UserB'], userIds['UserC']] // Simulate B and C are nearby
        }, { headers: { Authorization: `Bearer ${tokenA}` } });

        expect(resA.status).toBe(201);
        roomAlphaId = resA.data.roomId;
        console.log(`✅ UserA created "Room Alpha" (ID: ${roomAlphaId})`);

        // B creates "Room Beta" (Different name, should succeed)
        const resB = await axios.post(`${API_URL}/rooms`, {
            name: 'Room Beta',
            category: 'general',
            nearbyUserIds: [userIds['UserA'], userIds['UserC']]
        }, { headers: { Authorization: `Bearer ${tokenB}` } });

        expect(resB.status).toBe(201);
        console.log(`✅ UserB created "Room Beta"`);

        // C tries to create "Room Alpha" (Same name as A, and A is nearby/active)
        // We simulate that C sees A as nearby
        try {
            await axios.post(`${API_URL}/rooms`, {
                name: 'Room Alpha',
                category: 'general',
                nearbyUserIds: [userIds['UserA'], userIds['UserB']]
            }, { headers: { Authorization: `Bearer ${tokenC}` } });

            throw new Error('Should have failed with duplicate error');
        } catch (error) {
            expect(error.response.status).toBe(400); // Or whatever validation error code
            expect(error.response.data.error.message).toContain('이미 같은 이름의 방');
            console.log(`✅ UserC blocked from creating duplicate "Room Alpha"`);
        }
    });

    // 3. Room Joining & Socket Connection
    test('3. Join Room and Connect Sockets', async () => {
        // Connect Sockets
        sockets['UserA'] = await connectSocket(tokens['UserA']);
        sockets['UserB'] = await connectSocket(tokens['UserB']);
        sockets['UserC'] = await connectSocket(tokens['UserC']);

        // Join "Room Alpha"
        // A is already creator, but needs to join socket room
        sockets['UserA'].emit('join-room', { roomId: roomAlphaId });

        // B joins via API then Socket
        await axios.post(`${API_URL}/rooms/${roomAlphaId}/join`, {}, {
            headers: { Authorization: `Bearer ${tokens['UserB']}` }
        });
        sockets['UserB'].emit('join-room', { roomId: roomAlphaId });

        // C joins via API then Socket
        await axios.post(`${API_URL}/rooms/${roomAlphaId}/join`, {}, {
            headers: { Authorization: `Bearer ${tokens['UserC']}` }
        });
        sockets['UserC'].emit('join-room', { roomId: roomAlphaId });

        // Wait for joins to propagate
        await new Promise(r => setTimeout(r, 500));
        console.log(`✅ All users joined "Room Alpha"`);
    });

    // 4. Real-time Chat Verification
    test('4. Real-time Chat Verification', async () => {
        const messageFromA = "Hello everyone, this is A!";
        const messageFromB = "Hi A, this is B!";

        // Setup listeners
        const p1 = new Promise(resolve => sockets['UserB'].once('new-message', resolve));
        const p2 = new Promise(resolve => sockets['UserC'].once('new-message', resolve));

        // A sends message
        sockets['UserA'].emit('send-message', {
            roomId: roomAlphaId,
            type: 'text',
            content: messageFromA
        });

        const [msgB, msgC] = await Promise.all([p1, p2]);

        expect(msgB.content).toBe(messageFromA);
        expect(msgB.nicknameMask).toBeDefined(); // Should be masked
        expect(msgC.content).toBe(messageFromA);

        console.log(`✅ UserA sent message, received by B and C`);

        // B sends message
        const p3 = new Promise(resolve => sockets['UserA'].once('new-message', resolve));
        const p4 = new Promise(resolve => sockets['UserC'].once('new-message', resolve));

        sockets['UserB'].emit('send-message', {
            roomId: roomAlphaId,
            type: 'text',
            content: messageFromB
        });

        const [msgA, msgC2] = await Promise.all([p3, p4]);

        expect(msgA.content).toBe(messageFromB);
        expect(msgC2.content).toBe(messageFromB);

        console.log(`✅ UserB sent message, received by A and C`);
    });

    // Cleanup
    afterAll(() => {
        Object.values(sockets).forEach(s => s.disconnect());
    });
});
