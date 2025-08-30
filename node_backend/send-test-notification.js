const admin = require('firebase-admin');
const serviceAccount = require('./firebase-service-account.json');

// Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://chat-app-b52e2-default-rtdb.europe-west1.firebasedatabase.app/'
});

// FCM token from the app logs - make sure this matches the token shown in your Flutter app logs
const token = 'cRGGLcN7RU-SBzX5QDjL-s:APA91bEDoaAp5QNkCYPf6N5B1l6kguaqz29fWDAoe3rgPrtKAvPQO75L8BvNzD4zZ20Q9FLai4Ngo-cI7oG9psEB6-BY3RoUMu5jmoJuRSYTst3yQPdw7vMI';

const message = {
  notification: {
    title: 'Test Notification',
    body: 'This is a test notification from the server!',
  },
  token: token,
  data: {
    type: 'test',
    timestamp: new Date().toISOString(),
  },
};

// Send the message
admin.messaging().send(message)
  .then((response) => {
    console.log('Successfully sent message:', response);
    process.exit(0);
  })
  .catch((error) => {
    console.error('Error sending message:', error);
    process.exit(1);
  });
