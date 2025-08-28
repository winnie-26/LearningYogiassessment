const authSvc = require('./auth.service');

async function register(req, res, next) {
  try {
    const { email, password } = req.body || {};
    const user = await authSvc.register(email, password);
    res.status(201).json(user);
  } catch (e) { next(e); }
}

async function login(req, res, next) {
  try {
    const { email, password } = req.body || {};
    const tokens = await authSvc.login(email, password);
    res.json(tokens); // {access, refresh}
  } catch (e) { next(e); }
}

async function refresh(req, res, next) {
  try {
    const { refresh_token } = req.body || {};
    const token = await authSvc.refresh(refresh_token);
    res.json(token); // {access}
  } catch (e) { next(e); }
}

module.exports = { register, login, refresh };
