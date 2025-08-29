const svc = require('./messages.service');

async function send(req, res, next) {
  try {
    const { text } = req.body || {};
    const msg = await svc.send(req.params.id, req.user.sub, text);
    
    // Broadcast message to WebSocket clients with proper format
    if (global.wsServer) {
      // Ensure the message has the same format as API response
      const broadcastMsg = {
        ...msg,
        sender: msg.sender || {
          id: req.user.sub,
          name: `User${req.user.sub}`,
          email: `user${req.user.sub}@example.com`
        }
      };
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
