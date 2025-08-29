const svc = require('./messages.service');
const usersRepo = require('./users.repository');

async function send(req, res, next) {
  try {
    const { text } = req.body || {};
    const msg = await svc.send(req.params.id, req.user.sub, text);
    
    // Broadcast message to WebSocket clients with proper format
    if (global.wsServer) {
      // Ensure the message has the same format as API response with real sender info
      let sender = msg.sender;
      if (!sender) {
        try {
          const user = await usersRepo.getUserById(req.user.sub);
          if (user) {
            const email = user.email || '';
            const name = email.includes('@') ? email.split('@')[0] : (email || `user_${req.user.sub}`);
            sender = { id: req.user.sub, name, email: email || 'no-email' };
          }
        } catch (_) {
          // Fallback to placeholder if lookup fails
          sender = { id: req.user.sub, name: `user_${req.user.sub}`, email: 'no-email' };
        }
      }
      const broadcastMsg = { ...msg, sender };
      global.wsServer.broadcastNewMessage(req.params.id, broadcastMsg);
    }
    
    res.status(201).json(msg);
  } catch (e) { next(e); }
}

async function list(req, res, next) {
  try {
    if (!req.user || !req.user.sub) {
      const err = new Error('Authentication required');
      err.status = 401;
      throw err;
    }
    
    const limit = req.query.limit ? Number(req.query.limit) : undefined;
    const items = await svc.list(req.params.id, { limit });
    res.json(items);
  } catch (e) { next(e); }
}

async function destroy(req, res, next) {
  try {
    if (!req.user || !req.user.sub) {
      const err = new Error('Authentication required');
      err.status = 401;
      throw err;
    }
    const groupId = req.params.id;
    const messageId = req.params.messageId;
    await svc.remove(groupId, req.user.sub, messageId);
    res.json({ ok: true });
  } catch (e) { next(e); }
}

module.exports = { send, list, destroy };
