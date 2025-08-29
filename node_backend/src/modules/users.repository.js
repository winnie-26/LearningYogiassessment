const store = require('../data/store');
const { isDbEnabled, getPool } = require('../data/db');

async function listUsers({ q, limit } = {}) {
  if (!isDbEnabled()) {
    return store.listUsers({ q, limit });
  }
  const pool = getPool();
  const params = [];
  let sql = 'SELECT id, email FROM users';
  if (q && typeof q === 'string' && q.trim()) {
    params.push(`%${q.trim().toLowerCase()}%`);
    sql += ` WHERE LOWER(email) LIKE $${params.length}`;
  }
  sql += ' ORDER BY email ASC';
  if (typeof limit === 'number') {
    params.push(limit);
    sql += ` LIMIT $${params.length}`;
  }
  const { rows } = await pool.query(sql, params);
  return rows;
}

module.exports = { listUsers };
