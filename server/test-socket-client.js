const io = require('socket.io-client');
const { generateAccessToken } = require('./src/config/auth');

// 1. Generate Token
const token = generateAccessToken({ userId: 'test-user-id', email: 'test@example.com' });
console.log('Generated Token:', token);

// 2. Connect
const socket = io('http://localhost:3000', {
    auth: { token },
    transports: ['websocket']
});

socket.on('connect', () => {
    console.log('Connected! Socket ID:', socket.id);

    // 3. Emit send-message
    console.log('Emitting send-message...');
    socket.emit('send-message', {
        roomId: 'bad7029b-5299-4c34-9699-a338dc3497df', // Use a real or dummy room ID
        type: 'text',
        content: 'Test message from script'
    });
});

socket.on('new-message', (data) => {
    console.log('Received new-message:', data);
    process.exit(0);
});

socket.on('error', (err) => {
    console.error('Socket Error:', err);
    process.exit(1);
});

socket.on('disconnect', () => {
    console.log('Disconnected');
});

setTimeout(() => {
    console.error('Timeout waiting for response');
    process.exit(1);
}, 5000);
