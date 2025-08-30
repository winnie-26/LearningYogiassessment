const express = require('express');
const router = express.Router();
const { authenticateToken } = require('../../middleware/auth');

// Import controller functions directly
const { updateToken, removeToken } = require('../../modules/fcm.controller');

// Update FCM token for push notifications
router.put('/token', authenticateToken, updateToken);

// Remove FCM token (logout)
router.delete('/token', authenticateToken, removeToken);

module.exports = router;
