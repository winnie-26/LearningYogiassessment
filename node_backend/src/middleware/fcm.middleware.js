const { StatusCodes } = require('http-status-codes');
const db = require('../config/database');

/**
 * Middleware to update user's FCM token
 * Should be called when user logs in or updates their device
 */
const updateFcmToken = async (req, res, next) => {
  try {
    const { userId } = req.user; // Assuming you have user data in req.user from auth middleware
    const { fcmToken } = req.body;

    if (!fcmToken) {
      return res.status(StatusCodes.BAD_REQUEST).json({
        success: false,
        message: 'FCM token is required',
      });
    }

    // Update user's FCM token in the database
    await db.User.update(
      { fcmToken },
      { where: { id: userId } }
    );

    next();
  } catch (error) {
    console.error('Error updating FCM token:', error);
    next(error);
  }
};

module.exports = {
  updateFcmToken,
};
