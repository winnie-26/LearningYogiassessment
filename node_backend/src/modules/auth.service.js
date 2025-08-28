const bcrypt = require('bcryptjs');
const { signAccess, signRefresh, verify } = require('../utils/jwt');
const authRepo = require('./auth.repository');

async function register(email, password) {
  const passwordHash = await bcrypt.hash(password, 10);
  const user = await authRepo.createUser(email, passwordHash);
  return { id: user.id, email: user.email };
}

async function login(email, password) {
  const user = await authRepo.findUserByEmail(email);
  if (!user) throw Object.assign(new Error('invalid_credentials'), { status: 401, code: 'invalid_credentials' });
  const ok = await bcrypt.compare(password, user.passwordHash);
  if (!ok) throw Object.assign(new Error('invalid_credentials'), { status: 401, code: 'invalid_credentials' });
  const payload = { sub: user.id, email: user.email };
  return { access: signAccess(payload), refresh: signRefresh(payload) };
}

async function refresh(refreshToken) {
  try {
    const decoded = verify(refreshToken);
    const user = await authRepo.findUserById(decoded.sub);
    if (!user) throw new Error('invalid_user');
    const payload = { sub: user.id, email: user.email };
    return { access: signAccess(payload) };
  } catch (e) {
    throw Object.assign(new Error('invalid_refresh'), { status: 401, code: 'invalid_refresh' });
  }
}

module.exports = { register, login, refresh };
