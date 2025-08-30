const express = require('express');
const router = express.Router();
const db = require('../config/database');
const { authenticateToken } = require('../middleware/auth');

// Update FCM token for a user
router.post('/:userId/fcm-token', authenticateToken, async (req, res) => {
  try {
    const { userId } = req.params;
    const { fcmToken } = req.body;

    if (!fcmToken) {
      return res.status(400).json({ error: 'FCM token is required' });
    }

    // Update the user's FCM token in the database
    await db('users')
      .where({ id: userId })
      .update({ fcm_token: fcmToken, updated_at: db.fn.now() });

    res.status(200).json({ message: 'FCM token updated successfully' });
  } catch (error) {
    console.error('Error updating FCM token:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
