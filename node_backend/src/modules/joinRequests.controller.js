const svc = require('./joinRequests.service');

async function list(req, res, next) {
  try {
    const items = await svc.list(req.params.id);
    res.json(items);
  } catch (e) { next(e); }
}

async function create(req, res, next) {
  try {
    const groupId = req.params.id;
    const userId = req.user?.sub;
    if (!userId) return res.status(401).json({ code: 'unauthorized', message: 'Login required' });
    const jr = await svc.create(groupId, userId);
    res.status(201).json(jr);
  } catch (e) { next(e); }
}

async function approve(req, res, next) {
  try {
    const adminId = req.user?.sub;
    if (!adminId) {
      return res.status(401).json({ code: 'unauthorized', message: 'Login required' });
    }
    const jr = await svc.approve(req.params.id, req.params.reqId, adminId);
    res.json(jr);
  } catch (e) { next(e); }
}

async function decline(req, res, next) {
  try {
    const jr = await svc.decline(req.params.id, req.params.reqId);
    res.json(jr);
  } catch (e) { next(e); }
}

module.exports = { list, create, approve, decline };
