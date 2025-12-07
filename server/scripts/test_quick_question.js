/**
 * Quick Question Feature Test Script
 * 
 * Logic derived via Sequential Thinking:
 * 1. Simulate User B getting a valid BLE UID.
 * 2. Simulate User B having a valid FCM Token.
 * 3. User A targets User B's UID directly (bypassing physical BLE scan).
 * 4. Verify Server logic: ID Mapping -> Push Check -> Cooldown.
 */

const axios = require('axios');

const API_URL = 'http://localhost:3000/api';

const userA = {
    email: 'qa_sender_' + Date.now() + '@test.com',
    password: 'password123',
    nickname: 'Sender'
};

const userB = {
    email: 'qa_receiver_' + Date.now() + '@test.com',
    password: 'password123',
    nickname: 'Receiver'
};

const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

async function registerAndLogin(user) {
    try {
        // Register (ignore 409)
        try {
            await axios.post(`${API_URL}/auth/register`, user);
        } catch (e) {
            if (e.response?.status !== 409) throw e;
        }

        // Login
        const res = await axios.post(`${API_URL}/auth/login`, {
            email: user.email,
            password: user.password
        });
        return { token: res.data.token, user: res.data.user };
    } catch (e) {
        console.error(`Login failed for ${user.nickname}:`, e.message);
        process.exit(1);
    }
}

async function runTest() {
    console.log('🧪 Starting Quick Question Test...');

    // 1. Setup Users
    const authA = await registerAndLogin(userA);
    const authB = await registerAndLogin(userB);

    console.log(`✅ Users Logged In: A(${authA.user.nickname}) -> B(${authB.user.nickname})`);

    // 2. User B gets a UID (Simulate BLE Active)
    let targetUid;
    try {
        const res = await axios.post(`${API_URL}/users/ble/uid`, {}, {
            headers: { Authorization: `Bearer ${authB.token}` }
        });
        targetUid = res.data.uid;
        console.log(`✅ User B obtained UID: ${targetUid}`);
    } catch (e) {
        console.error('❌ Failed to get UID:', e.message);
        process.exit(1);
    }

    // 3. User B registers FCM Token (Required for Push)
    try {
        await axios.post(`${API_URL}/push/register`, {
            deviceToken: 'TEST_FCM_TOKEN_' + Date.now(),
            platform: 'ios',
            deviceId: 'TEST_DEVICE_' + Date.now(),
            deviceInfo: { model: 'TestScript' }
        }, {
            headers: { Authorization: `Bearer ${authB.token}` }
        });
        console.log(`✅ User B registered FCM Token`);
    } catch (e) {
        console.error('❌ Failed to register FCM:', e.message);
        process.exit(1);
    }

    await sleep(1000);

    // 4. User A sends Quick Question to User B
    console.log('🚀 User A sending Quick Question...');
    try {
        const res = await axios.post(`${API_URL}/users/quick_question`, {
            uids: [targetUid],
            content: 'Hello, are you nearby?'
        }, {
            headers: { Authorization: `Bearer ${authA.token}` }
        });

        console.log('📥 Response:', res.data);

        if (res.data.sentCount === 1) {
            console.log('✅ PASS: Message sent to 1 user.');
        } else {
            console.error('❌ FAIL: sentCount is not 1. Actual:', res.data.sentCount);
        }

    } catch (e) {
        console.error('❌ Failed to request Quick Question:', e.response?.data || e.message);
    }

    // 5. Test Cooldown (Immediate Retry)
    console.log('⏱ Testing Cooldown...');
    try {
        await axios.post(`${API_URL}/users/quick_question`, {
            uids: [targetUid],
            content: 'Spamming...'
        }, {
            headers: { Authorization: `Bearer ${authA.token}` }
        });
        console.error('❌ FAIL: Cooldown did not trigger.');
    } catch (e) {
        if (e.response?.status === 429) {
            console.log('✅ PASS: Cooldown triggered (429 Too Many Requests).');
        } else {
            console.error('❌ User A Retry failed with unexpected error:', e.message);
        }
    }

}

runTest();
