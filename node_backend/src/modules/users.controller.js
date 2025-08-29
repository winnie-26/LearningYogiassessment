const repo = require('./users.repository');

async function list(req, res, next) {
  try {
    const q = typeof req.query.q === 'string' ? req.query.q : undefined;
    const limit = req.query.limit ? Number(req.query.limit) : undefined;
    const items = await repo.listUsers({ q, limit });
    res.json(items);
  } catch (e) { next(e); }
}

module.exports = { list };
