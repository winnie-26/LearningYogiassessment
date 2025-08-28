const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'devsecret';
const ACCESS_TTL_SECONDS = Number(process.env.ACCESS_TTL_SECONDS || 3600);
const REFRESH_TTL_SECONDS = Number(process.env.REFRESH_TTL_SECONDS || 60 * 60 * 24 * 30);

function signAccess(payload) {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: ACCESS_TTL_SECONDS });
}

function signRefresh(payload) {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: REFRESH_TTL_SECONDS });
}

function verify(token) {
  return jwt.verify(token, JWT_SECRET);
}

module.exports = { signAccess, signRefresh, verify };
