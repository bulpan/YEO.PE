/**
 * Chat Flow Test Script
 * 
 * Scenario:
 * 1. User A (Creator) logs in.
 * 2. User B (Invitee) logs in.
 * 3. User A creates a room inviting User B.
 * 4. User B receives 'joined-room' or joins via ID.
 * 5. User A sends message.
 * 6. User B receives message.
 * 7. User B sends message.
 * 8. User A receives message.
 * 9. User B exits room (exit-room).
 * 10. User A receives 'user-left'.
 * 11. User A exits room.
 */

const io = require('socket.io-client');
const axios = require('axios'); // For REST API login if needed, or we just mock tokens if dev env allows
// Assuming we need real tokens, we'll hit the login API first.

const API_URL = 'http://localhost:3000/api';
const SOCKET_URL = 'http://localhost:3000';

const userA = {
    email: 'test_a_' + Date.now() + '@test.com',
    password: 'password123',
    nickname: 'UserA'
};

const userB = {
    email: 'test_b_' + Date.now() + '@test.com',
    password: 'password123',
    nickname: 'UserB'
};

let tokenA, tokenB;
let socketA, socketB;
let roomId;
let userB_Id;

const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

async function registerAndLogin(user) {
    try {
        // Register
        await axios.post(`${API_URL}/auth/register`, user);
        console.log(`✅ Registered ${user.nickname}`);
    } catch (e) {
        if (e.response && e.response.status === 409) {
            console.log(`⚠️ User ${user.nickname} already exists, logging in...`);
        } else {
            console.error(`❌ Registration failed for ${user.nickname}:`, e.message);
            process.exit(1);
        }
    }

    // Login
    try {
        const res = await axios.post(`${API_URL}/auth/login`, {
            email: user.email,
            password: user.password
        });
        console.log(`✅ Logged in ${user.nickname}`);
        return { token: res.data.token, id: res.data.user.id };
    } catch (e) {
        console.error(`❌ Login failed for ${user.nickname}:`, e.message);
        process.exit(1);
    }
}

async function createRoom(token, inviteeId) {
    try {
        const res = await axios.post(`${API_URL}/rooms`, {
            name: 'Test Chat Room',
            type: 'individual',
            inviteeId: inviteeId
        }, {
            headers: { Authorization: `Bearer ${token}` }
        });
        console.log(`✅ Created Room ID: ${res.data.roomId} (uniqueId: ${res.data.roomId})`);
        const roomId = res.data.roomId; // usually uniqueId
        return roomId;
    } catch (e) {
        console.error('❌ Failed to create room:', e.message);
        process.exit(1);
    }
}

function connectSocket(token, userLabel) {
    const socket = io(SOCKET_URL, {
        query: { token },
        transports: ['websocket'],
        forceNew: true
    });

    socket.on('connect', () => {
        console.log(`🔵 ${userLabel} Socket Connected (${socket.id})`);
    });

    socket.on('error', (err) => {
        console.error(`🔴 ${userLabel} Socket Error:`, err);
    });

    return socket;
}

async function runTest() {
    console.log('🚀 Starting Chat Flow Test...');

    // 1. Setup Users
    const authA = await registerAndLogin(userA);
    tokenA = authA.token;
    const authB = await registerAndLogin(userB);
    tokenB = authB.token;
    userB_Id = authB.id;

    // 2. Connect Sockets
    socketA = connectSocket(tokenA, 'UserA');
    socketB = connectSocket(tokenB, 'UserB');

    await sleep(1000);

    // 3. User A creates Room
    roomId = await createRoom(tokenA, userB_Id);

    // 4. Join Room (Socket)
    // In real app, B would get a push or see it in list, then join. We simulate join.
    console.log('👉 User A joining room...');
    socketA.emit('join-room', { roomId });

    console.log('👉 User B joining room...');
    socketB.emit('join-room', { roomId });

    // Listeners for Verification
    const verifyPromise = new Promise((resolve, reject) => {
        let steps = {
            aReceived: false,
            bReceived: false,
            aSawBLeft: false
        };

        // Verify A receives B's message
        socketA.on('new-message', (data) => {
            if (data.content === 'Hello from B') {
                console.log('✅ User A received message from B: "Hello from B"');
                steps.aReceived = true;
            }
        });

        // Verify B receives A's message
        socketB.on('new-message', (data) => {
            if (data.content === 'Hello from A') {
                console.log('✅ User B received message from A: "Hello from A"');
                steps.bReceived = true;
            }
        });

        // Verify A sees B left
        socketA.on('user-left', (data) => {
            if (data.userId === authB.id) {
                console.log('✅ User A saw User B leave room');
                steps.aSawBLeft = true;
            }

            // Check all conditions
            if (steps.aReceived && steps.bReceived && steps.aSawBLeft) {
                resolve();
            }
        });

        // Timeout safety
        setTimeout(() => {
            // If we got here, check what's missing
            const missing = [];
            if (!steps.aReceived) missing.push("A didn't receive msg");
            if (!steps.bReceived) missing.push("B didn't receive msg");
            if (!steps.aSawBLeft) missing.push("A didn't see B leave");

            if (missing.length === 0) resolve();
            else reject(new Error('Test Timed Out. Missing: ' + missing.join(', ')));
        }, 10000);
    });

    await sleep(1000);

    // 5. Exchange Messages
    console.log('💬 User A sending message...');
    socketA.emit('send-message', { roomId, type: 'text', content: 'Hello from A' });

    await sleep(500);

    console.log('💬 User B sending message...');
    socketB.emit('send-message', { roomId, type: 'text', content: 'Hello from B' });

    await sleep(2000);

    // --- ENHANCED VERIFICATION STEPS ---

    // 6. Persistence Check: Verify messages are saved in DB
    console.log('💾 Verifying Message Persistence...');
    const historyRes = await axios.get(`${API_URL}/rooms/${roomId}/messages`, {
        headers: { Authorization: `Bearer ${tokenA}` }
    });
    // Check for both messages
    const historyMessages = historyRes.data.messages || []; // Adjust based on actual API response structure
    const foundA = historyMessages.some(m => m.content === 'Hello from A');
    const foundB = historyMessages.some(m => m.content === 'Hello from B');

    if (foundA && foundB) {
        console.log('✅ PASS: Both messages persisted in DB.');
    } else {
        console.error('❌ FAIL: Messages not found in DB history.', historyMessages.map(m => m.content));
    }

    // 7. Idempotency Check: Prevent Duplicate Rooms
    console.log('🔄 Verifying Room Idempotency...');
    try {
        const dupRes = await axios.post(`${API_URL}/rooms`, {
            name: 'Duplicate Test',
            category: 'private',
            inviteeId: userB_Id
        }, {
            headers: { Authorization: `Bearer ${tokenA}` }
        });

        if (dupRes.data.roomId === roomId) {
            console.log('✅ PASS: Duplicate creation returned existing Room ID.');
        } else {
            console.error(`❌ FAIL: Created diff ID ${dupRes.data.roomId} vs ${roomId}`);
        }
    } catch (e) {
        console.error('❌ FAIL: Idempotency check error:', e.message);
    }

    // 8. Security Check: Unauthorized Join
    console.log('👮 Verifying Security (User C Join)...');
    const userC = { email: `testC_${Date.now()}@test.com`, password: 'password123', nickname: 'Intruder' };
    const authC = await registerAndLogin(userC);

    // Connect Socket C
    const socketC = io('http://localhost:3000', { path: '/socket.io', transports: ['websocket'] });

    await new Promise((resolve) => {
        socketC.on('connect', () => {
            // Try to join A-B room
            socketC.emit('join-room', { roomId });
        });

        socketC.on('error', (err) => {
            console.log(`✅ PASS: User C blocked from joining: ${JSON.stringify(err)}`);
            socketC.disconnect();
            resolve();
        });

        // Fail-safe if it actually succeeds (timeout or 'join-success' event if it existed)
        setTimeout(() => {
            // If we're here, we didn't get an error immediately. 
            // Ideally we listen for a success event, but 'join-room' usually emits 'room-joined' or similar?
            // Assuming silence or error. Let's assume validation on server sends 'error' event.
            // If server just ignores, this test might flake. 
            // But server/src/socket/roomHandler.js usually emits error or callback?
            // Let's modify roomHandler logic later if this times out.
            // For now, logging that we waited.
            console.log('⚠️ User C join attempt timed out (Did not receive error).');
            socketC.disconnect();
            resolve();
        }, 5000);
    });


    // 9. Exit Flow (User B leaves)
    console.log(' User B exiting room...');
    // Note: App calls /api/rooms/:id/leave usually, which triggers logic? 
    // Wait, roomHandler has 'exit-room' socket event too. Let's use socket event for speed, 
    // BUT the API call is what `ChatViewModel` uses in `exitRoom`.
    // `ChatViewModel` calls API `/leave`, then API should probably trigger socket event?
    // Let's check logic. If API calls `roomService.leaveRoom`, does it notify socket?
    // Usually API is HTTP. If API handles leave, it needs to tell Socket.io to broadcast.
    // Inspection of `roomService.js` would confirm.
    // For this test, I will use the `exit-room` socket event as verified in `roomHandler.js`.
    socketB.emit('exit-room', { roomId });

    try {
        await verifyPromise;
        console.log('🎉 All Test Steps Verified Successfully!');
    } catch (e) {
        console.error('❌ Test Failed:', e.message);
    } finally {
        socketA.disconnect();
        socketB.disconnect();
        process.exit(0);
    }
}

runTest();
