const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
let isInitialized = false;

try {
  const serviceAccount = require('../../firebase-service-account.json');
  
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: process.env.FIREBASE_DATABASE_URL
  });
  
  console.log('Firebase Admin SDK initialized successfully');
  isInitialized = true;
} catch (error) {
  console.error('Failed to initialize Firebase Admin SDK:', error);
  isInitialized = false;
}

class NotificationService {
  constructor() {
    if (!isInitialized) {
      console.warn('NotificationService: Firebase Admin SDK not initialized');
      return;
    }
    this.messaging = admin.messaging();
  }

  /**
   * Send a notification to a specific user
   * @param {string} userId - The ID of the user to notify
   * @param {Object} notification - Notification content
   * @param {Object} data - Additional data payload
   * @returns {Promise} - Promise that resolves when notification is sent
   */
  async sendToUser(userId, notification, data = {}) {
    try {
      // Get the FCM token for the user from your database
      const user = await db.User.findByPk(userId, {
        attributes: ['fcmToken']
      });

      if (!user || !user.fcmToken) {
        console.warn(`No FCM token found for user ${userId}`);
        return null;
      }

      const message = {
        token: user.fcmToken,
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: {
          ...data,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
      };

      const response = await this.messaging.send(message);
      console.log('Successfully sent notification:', response);
      return response;
    } catch (error) {
      console.error('Error sending notification:', error);
      throw error;
    }
  }

  /**
   * Send a notification to multiple users
   * @param {string[]} userIds - Array of user IDs to notify
   * @param {Object} notification - Notification content
   * @param {Object} data - Additional data payload
   */
  async sendToUsers(userIds, notification, data = {}) {
    const promises = userIds.map(userId => 
      this.sendToUser(userId, notification, data).catch(console.error)
    );
    return Promise.all(promises);
  }

  // Specific notification methods
  
  /**
   * Send group invitation notification
   * @param {string} inviterId - User ID of the person sending the invite
   * @param {string} inviteeId - User ID of the person being invited
   * @param {string} groupId - ID of the group
   * @param {string} groupName - Name of the group
   */
  async sendGroupInvite(inviterId, inviteeId, groupId, groupName) {
    const inviter = await db.User.findByPk(inviterId, {
      attributes: ['username']
    });

    return this.sendToUser(inviteeId, {
      title: 'New Group Invitation',
      body: `${inviter.username} invited you to join ${groupName}`
    }, {
      type: 'group_invite',
      groupId,
      inviterId,
      timestamp: new Date().toISOString()
    });
  }

  /**
   * Send join request accepted notification
   * @param {string} adminId - User ID of the group admin who accepted
   * @param {string} userId - User ID whose request was accepted
   * @param {string} groupId - ID of the group
   * @param {string} groupName - Name of the group
   */
  async sendRequestAccepted(adminId, userId, groupId, groupName) {
    const adminUser = await db.User.findByPk(adminId, {
      attributes: ['username']
    });

    return this.sendToUser(userId, {
      title: 'Request Accepted',
      body: `${adminUser.username} accepted your request to join ${groupName}`
    }, {
      type: 'request_accepted',
      groupId,
      adminId,
      timestamp: new Date().toISOString()
    });
  }

  /**
   * Send new message notification
   * @param {string} senderId - User ID of the message sender
   * @param {string[]} recipientIds - Array of user IDs to notify (excluding sender)
   * @param {string} groupId - ID of the group where the message was sent
   * @param {string} groupName - Name of the group
   * @param {string} messagePreview - Preview of the message
   */
  async sendNewMessage(senderId, recipientIds, groupId, groupName, messagePreview) {
    if (recipientIds.length === 0) return [];
    
    const sender = await db.User.findByPk(senderId, {
      attributes: ['username']
    });

    const notification = {
      title: `New message in ${groupName}`,
      body: `${sender.username}: ${messagePreview.substring(0, 100)}${messagePreview.length > 100 ? '...' : ''}`
    };

    const data = {
      type: 'new_message',
      groupId,
      senderId,
      timestamp: new Date().toISOString()
    };

    return this.sendToUsers(recipientIds, notification, data);
  }
}

module.exports = new NotificationService();
