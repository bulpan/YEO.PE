/**
 * Leave Room Test Script (Client Mode)
 * Connects to running server at localhost:3000
 */

const io = require('socket.io-client');
const axios = require('axios');

const API_URL = 'http://localhost:3000/api';
const SOCKET_URL = 'http://localhost:3000';

// Use distinct users every run to avoid conflicts
const suffix = Date.now();
const userA = { email: `stay_${suffix}@test.com`, password: 'password123', nickname: 'StayUser' };
const userB = { email: `leave_${suffix}@test.com`, password: 'password123', nickname: 'LeaveUser' };

let tokenA, tokenB, userIdA, userIdB;
let socketA, socketB;
let roomId;

const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

async function registerAndLogin(user) {
    try {
        await axios.post(`${API_URL}/auth/register`, user);
    } catch (e) { /* Ignore if exists */ }

    const res = await axios.post(`${API_URL}/auth/login`, {
        email: user.email,
        password: user.password
    });
    return { token: res.data.token, id: res.data.user.id };
}

function connectSocket(token, label) {
    const socket = io(SOCKET_URL, {
        query: { token },
        transports: ['websocket'],
        forceNew: true
    });
    socket.on('connect', () => console.log(`🔵 ${label} Connected`));
    socket.on('connect_error', (e) => console.log(`🔴 ${label} Connection Error:`, e.message));
    return socket;
}

async function runTest() {
    console.log('🚀 Starting Leave Room Test (Client Mode)...');

    try {
        // 1. Setup Users
        const authA = await registerAndLogin(userA);
        tokenA = authA.token; userIdA = authA.id;
        console.log(`👤 User A: ${userIdA}`);

        const authB = await registerAndLogin(userB);
        tokenB = authB.token; userIdB = authB.id;
        console.log(`👤 User B: ${userIdB}`);

        // 2. Connect Sockets
        socketA = connectSocket(tokenA, 'UserA');
        socketB = connectSocket(tokenB, 'UserB');

        // Wait for connections
        await sleep(1000);

        // 3. Create Room (A creates)
        const roomRes = await axios.post(`${API_URL}/rooms`,
            { name: 'LeaveTest', category: 'general', inviteeId: userIdB }, // Corrected 'private' -> 'general' or check valid types. 
            // Previous code used 'type: individual'? server expects 'category'. Valid: 'general', 'transport', 'event', 'venue', 'private' in logic?
            // "1:1 room" logic triggers if inviteeId is present.
            { headers: { Authorization: `Bearer ${tokenA}` } }
        );
        roomId = roomRes.data.roomId;
        console.log(`✅ Room Created: ${roomId}`);

        // 4. Join Room (Socket logic)
        socketA.emit('join-room', { roomId });

        // B joins via API (triggers member-joined)
        await axios.post(`${API_URL}/rooms/${roomId}/join`, {}, { headers: { Authorization: `Bearer ${tokenB}` } });
        socketB.emit('join-room', { roomId });
        await sleep(1000);

        // 5. Setup Verification
        const verifyPromise = new Promise((resolve, reject) => {
            const received = {
                memberLeft: false,
                evaporate: false
            };

            socketA.on('member-left', (data) => {
                console.log('📩 User A received [member-left]', data);
                if (data.userId === userIdB) received.memberLeft = true;
                check();
            });

            socketA.on('evaporate_messages', (data) => {
                console.log('📩 User A received [evaporate_messages]', data);
                if (data.userId === userIdB) received.evaporate = true;
                check();
            });

            socketA.on('new-message', (data) => {
                // Optional log
                if (data.type === 'system') console.log('📩 System Msg:', data.content);
            });

            function check() {
                if (received.memberLeft && received.evaporate) {
                    console.log('✅ Success: Recived member-left and evaporation.');
                    resolve();
                }
            }

            setTimeout(() => {
                reject(new Error(`Timeout. State: ${JSON.stringify(received)}`));
            }, 8000);
        });

        // 6. User B Leaves via API
        console.log('👋 User B Leaving via API...');
        await axios.post(`${API_URL}/rooms/${roomId}/leave`, {}, { headers: { Authorization: `Bearer ${tokenB}` } });

        await verifyPromise;
        console.log('🎉 TEST PASSED!');

    } catch (e) {
        console.error('❌ TEST FAILED:', e.message);
        if (e.response) console.error('Data:', e.response.data);
    } finally {
        socketA.disconnect();
        socketB.disconnect();
        process.exit(0);
    }
}

runTest();
