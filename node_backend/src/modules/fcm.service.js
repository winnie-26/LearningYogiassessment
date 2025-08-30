const { withTx } = require('../data/db');

/**
 * Update FCM token for a user
 * @param {string} userId - User ID
 * @param {string} fcmToken - FCM token from the mobile app
 */
async function updateToken(userId, fcmToken) {
  return withTx(async (client) => {
    await client.query(
      'UPDATE users SET fcm_token = $1 WHERE id = $2',
      [fcmToken, userId]
    );
    console.log(`FCM token updated for user ${userId}`);
  });
}

/**
 * Remove FCM token for a user (logout)
 * @param {string} userId - User ID
 */
async function removeToken(userId) {
  return withTx(async (client) => {
    await client.query(
      'UPDATE users SET fcm_token = NULL WHERE id = $1',
      [userId]
    );
    console.log(`FCM token removed for user ${userId}`);
  });
}

/**
 * Get FCM token for a user
 * @param {string} userId - User ID
 * @returns {string|null} FCM token or null if not found
 */
async function getToken(userId) {
  return withTx(async (client) => {
    const { rows } = await client.query(
      'SELECT fcm_token FROM users WHERE id = $1',
      [userId]
    );
    return rows[0]?.fcm_token || null;
  });
}

module.exports = {
  updateToken,
  removeToken,
  getToken
};
