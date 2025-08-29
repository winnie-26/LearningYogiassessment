const svc = require('./groups.service');

async function list(req, res, next) {
  try {
    const limit = req.query.limit ? Number(req.query.limit) : undefined;
    const userId = req.user && req.user.sub ? Number(req.user.sub) : undefined;
    const items = await svc.list({ limit, userId });
    res.json(items); // raw list for simplicity; client handles shapes flexibly
  } catch (e) { next(e); }
}

async function create(req, res, next) {
  try {
    const payload = req.body || {};
    const group = await svc.create(payload, req.user.sub);
    res.status(201).json(group);
  } catch (e) { next(e); }
}

async function join(req, res, next) {
  try {
    const g = await svc.join(req.params.id, req.user.sub);
    res.json({ ok: true, group_id: g.id, members: g.members_count });
  } catch (e) { next(e); }
}

async function leave(req, res, next) {
  try {
    const g = await svc.leave(req.params.id, req.user.sub);
    res.json({ ok: true, group_id: g.id, members: g.members_count });
  } catch (e) { next(e); }
}

async function transferOwner(req, res, next) {
  try {
    const { new_owner_id } = req.body || {};
    const g = await svc.transferOwner(req.params.id, new_owner_id);
    res.json({ ok: true, group_id: g.id, owner_id: g.owner_id });
  } catch (e) { next(e); }
}

async function destroy(req, res, next) {
  try {
    const out = await svc.destroy(req.params.id);
    res.json(out);
  } catch (e) { next(e); }
}

module.exports = { list, create, join, leave, transferOwner, destroy };
