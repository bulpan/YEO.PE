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
} catch (error) {
    console.error('Error initializing Firebase:', error);
}
