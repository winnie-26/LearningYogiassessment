const notificationService = require('./src/services/notification.service');
require('dotenv').config();

async function testNotification() {
  if (!notificationService.messaging) {
    console.error('Notification service not properly initialized');
    return;
  }

  try {
    // Test sending a notification to a specific device token
    // Replace 'test-device-token' with an actual FCM token from your app
    const message = {
      notification: {
        title: 'Test Notification',
        body: 'This is a test notification from the server'
      },
      token: 'test-device-token' // Replace with actual token
    };

    const response = await notificationService.messaging.send(message);
    console.log('Successfully sent message:', response);
  } catch (error) {
    console.error('Error sending test notification:', error);
  }
}

testNotification();
