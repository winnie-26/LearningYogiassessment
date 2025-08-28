const svc = require('./messages.service');

async function send(req, res, next) {
  try {
    const { text } = req.body || {};
    const msg = await svc.send(req.params.id, req.user.sub, text);
    res.status(201).json(msg);
  } catch (e) { next(e); }
}

async function list(req, res, next) {
  try {
    const limit = req.query.limit ? Number(req.query.limit) : undefined;
    const items = await svc.list(req.params.id, { limit });
    res.json(items);
  } catch (e) { next(e); }
}

module.exports = { send, list };
