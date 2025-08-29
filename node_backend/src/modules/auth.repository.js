const store = require('../data/store');
const { isDbEnabled, getPool } = require('../data/db');

function mapRow(r) {
  if (!r) return null;
  return { id: r.id, email: r.email, passwordHash: r.password_hash };
}

async function createUser(email, passwordHash) {
  if (!isDbEnabled()) {
    return store.createUser(email, passwordHash);
  }
  const pool = getPool();
  try {
    const { rows } = await pool.query(
      'INSERT INTO users (email, password_hash) VALUES ($1, $2) RETURNING id, email, password_hash',
      [email, passwordHash]
    );
    return mapRow(rows[0]);
  } catch (e) {
    if (e && e.code === '23505') { // unique_violation
      const err = new Error('email_taken'); err.status = 400; err.code = 'email_taken'; throw err;
    }
    throw e;
  }
}

async function findUserByEmail(email) {
  if (!isDbEnabled()) {
    return store.findUserByEmail(email);
  }
  const pool = getPool();
  const { rows } = await pool.query('SELECT id, email, password_hash FROM users WHERE email = $1', [email]);
  return mapRow(rows[0]);
}

async function findUserById(id) {
  if (!isDbEnabled()) {
    return store.findUserById(id);
  }
  const pool = getPool();
  const { rows } = await pool.query('SELECT id, email, password_hash FROM users WHERE id = $1', [id]);
  return mapRow(rows[0]);
}

module.exports = { createUser, findUserByEmail, findUserById };
