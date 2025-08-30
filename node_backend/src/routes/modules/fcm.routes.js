const express = require('express');
const router = express.Router();
const fcmController = require('../../modules/fcm.controller');
const { authenticateToken } = require('../../middleware/auth');

// Update FCM token for push notifications
router.put('/token', authenticateToken, fcmController.updateToken);

// Remove FCM token (logout)
router.delete('/token', authenticateToken, fcmController.removeToken);

module.exports = router;
