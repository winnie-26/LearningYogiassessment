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
    if (!isInitialized) {
      console.warn('Firebase not initialized, skipping notification');
      return null;
    }

    try {
      // Get the FCM token for the user from database using raw query
      const { getPool } = require('../data/db');
      const pool = getPool();
      
      const { rows } = await pool.query(
        'SELECT fcm_token FROM users WHERE id = $1', 
        [userId]
      );

      const user = rows[0];
      if (!user || !user.fcm_token) {
        console.warn(`No FCM token found for user ${userId}`);
        return null;
      }

      const message = {
        token: user.fcm_token,
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
      // Don't throw error to prevent breaking message flow
      return null;
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
    try {
      const { getPool } = require('../data/db');
      const pool = getPool();
      
      const { rows } = await pool.query(
        'SELECT email FROM users WHERE id = $1', 
        [inviterId]
      );

      const inviter = rows[0];
      const inviterName = inviter?.email?.split('@')[0] || 'Someone';

      return this.sendToUser(inviteeId, {
        title: 'New Group Invitation',
        body: `${inviterName} invited you to join ${groupName}`
      }, {
        type: 'group_invite',
        groupId,
        inviterId,
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      console.error('Error sending group invite notification:', error);
      return null;
    }
  }

  /**
   * Send join request accepted notification
   * @param {string} adminId - User ID of the group admin who accepted
   * @param {string} userId - User ID whose request was accepted
   * @param {string} groupId - ID of the group
   * @param {string} groupName - Name of the group
   */
  async sendRequestAccepted(adminId, userId, groupId, groupName) {
    try {
      const { getPool } = require('../data/db');
      const pool = getPool();
      
      const { rows } = await pool.query(
        'SELECT email FROM users WHERE id = $1', 
        [adminId]
      );

      const adminUser = rows[0];
      const adminName = adminUser?.email?.split('@')[0] || 'Admin';

      return this.sendToUser(userId, {
        title: 'Request Accepted',
        body: `${adminName} accepted your request to join ${groupName}`
      }, {
        type: 'request_accepted',
        groupId,
        adminId,
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      console.error('Error sending request accepted notification:', error);
      return null;
    }
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
    
    try {
      const { getPool } = require('../data/db');
      const pool = getPool();
      
      const { rows } = await pool.query(
        'SELECT email FROM users WHERE id = $1', 
        [senderId]
      );

      const sender = rows[0];
      const senderName = sender?.email?.split('@')[0] || 'Someone';

      const notification = {
        title: `New message in ${groupName}`,
        body: `${senderName}: ${messagePreview.substring(0, 100)}${messagePreview.length > 100 ? '...' : ''}`
      };

      const data = {
        type: 'new_message',
        groupId,
        senderId,
        timestamp: new Date().toISOString()
      };

      return this.sendToUsers(recipientIds, notification, data);
    } catch (error) {
      console.error('Error sending new message notification:', error);
      return [];
    }
  }
}

module.exports = new NotificationService();
