const repo = require('./users.repository');
const { NotFoundError } = require('../errors');

// Update user's FCM token
async function updateFcmToken(req, res, next) {
  try {
    const { userId } = req.params;
    const { fcmToken } = req.body;
    
    if (!fcmToken) {
      return res.status(400).json({ error: 'FCM token is required' });
    }
    
    const updatedUser = await repo.updateFcmToken(userId, fcmToken);
    
    if (!updatedUser) {
      throw new NotFoundError('User not found');
    }
    
    res.json({ message: 'FCM token updated successfully' });
  } catch (error) {
    next(error);
  }
}

async function list(req, res, next) {
  try {
    const q = typeof req.query.q === 'string' ? req.query.q : undefined;
    const limit = req.query.limit ? Number(req.query.limit) : 20; // Default to 20 items per page
    const offset = req.query.offset ? Number(req.query.offset) : 0;
    
    const result = await repo.listUsers({ 
      q, 
      limit,
      offset
    });
    
    res.json({
      data: result.items,
      pagination: {
        total: result.total,
        limit: result.limit,
        offset: result.offset,
        hasMore: (result.offset + result.items.length) < result.total
      }
    });
  } catch (e) { next(e); }
}

module.exports = { 
  list, 
  updateFcmToken 
};
