require('dotenv').config();
const admin = require('firebase-admin');

try {
    const serviceAccount = require('./config/firebase-service-account.json');
    console.log('Service account loaded.');
    console.log('Project ID:', serviceAccount.project_id);
    console.log('Client Email:', serviceAccount.client_email);

    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });

    console.log('Firebase Admin SDK initialized successfully.');

    // Try a dry-run send to verify Authentication with Google
    const message = {
        tokens: ['fake-token'],
        data: { test: 'value' }
    };

    console.log('Attempting dry-run send to verify credentials...');
    admin.messaging().sendEachForMulticast(message, true)
        .then(response => {
            console.log('✅ Auth connection successful!');
            console.log('Success Count:', response.successCount);
            console.log('Failure Count:', response.failureCount);
            if (response.failureCount > 0) {
                console.log('Sample Error (expected for fake token):', response.responses[0].error.code);
            }
        })
        .catch(error => {
            console.error('❌ FATAL AUTH ERROR:', error);
        });

} catch (error) {
    console.error('Error initializing Firebase:', error);
}
