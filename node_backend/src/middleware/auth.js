const jwt = require('jsonwebtoken');

function authOptional(req, res, next) {
  const header = req.headers.authorization || '';
  if (header.startsWith('Bearer ')) {
    try {
      const token = header.slice(7);
      req.user = jwt.verify(token, process.env.JWT_SECRET || 'devsecret');
    } catch (_) {
      // ignore
    }
  }
  next();
}

function authRequired(req, res, next) {
  const header = req.headers.authorization || '';
  if (!header.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'unauthorized' });
  }
  try {
    const token = header.slice(7);
    req.user = jwt.verify(token, process.env.JWT_SECRET || 'devsecret');
    return next();
  } catch (e) {
    return res.status(401).json({ error: 'unauthorized' });
  }
}

module.exports = { authOptional, authRequired };
