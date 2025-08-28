const svc = require('./joinRequests.service');

async function list(req, res, next) {
  try {
    const items = await svc.list(req.params.id);
    res.json(items);
  } catch (e) { next(e); }
}

async function approve(req, res, next) {
  try {
    const jr = await svc.approve(req.params.id, req.params.reqId);
    res.json(jr);
  } catch (e) { next(e); }
}

async function decline(req, res, next) {
  try {
    const jr = await svc.decline(req.params.id, req.params.reqId);
    res.json(jr);
  } catch (e) { next(e); }
}

module.exports = { list, approve, decline };
