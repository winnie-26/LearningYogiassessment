const { StatusCodes } = require('http-status-codes');
const fcmService = require('./fcm.service');

/**
 * Update FCM token for the authenticated user
 */
async function updateToken(req, res) {
  try {
    const userId = req.user.id;
    const { fcm_token } = req.body;

    if (!fcm_token || typeof fcm_token !== 'string') {
      return res.status(StatusCodes.BAD_REQUEST).json({
        error: 'FCM token is required'
      });
    }

    await fcmService.updateToken(userId, fcm_token);

    res.status(StatusCodes.OK).json({
      message: 'FCM token updated successfully'
    });
  } catch (error) {
    console.error('Error updating FCM token:', error);
    res.status(StatusCodes.INTERNAL_SERVER_ERROR).json({
      error: 'Failed to update FCM token'
    });
  }
}

/**
 * Remove FCM token for the authenticated user (logout)
 */
async function removeToken(req, res) {
  try {
    const userId = req.user.id;
    await fcmService.removeToken(userId);

    res.status(StatusCodes.OK).json({
      message: 'FCM token removed successfully'
    });
  } catch (error) {
    console.error('Error removing FCM token:', error);
    res.status(StatusCodes.INTERNAL_SERVER_ERROR).json({
      error: 'Failed to remove FCM token'
    });
  }
}

module.exports = {
  updateToken,
  removeToken
};
