const store = require('../data/store');
const { isDbEnabled, getPool } = require('../data/db');

async function listUsers({ q, limit, offset } = {}) {
  if (!isDbEnabled()) {
    return store.listUsers({ q, limit });
  }
  const pool = getPool();
  const params = [];
  let sql = 'SELECT id, email FROM users';
  let whereClause = '';
  
  // Add search filter if query is provided
  if (q && typeof q === 'string' && q.trim()) {
    params.push(`%${q.trim().toLowerCase()}%`);
    whereClause = ` WHERE LOWER(email) LIKE $${params.length}`;
  }
  
  // Get total count for pagination
  const countSql = `SELECT COUNT(*) as total FROM users${whereClause}`;
  const countResult = await pool.query(countSql, params);
  const total = parseInt(countResult.rows[0].total, 10);
  
  // Build the main query
  sql += whereClause;
  sql += ' ORDER BY email ASC';
  
  // Add pagination
  if (typeof limit === 'number') {
    params.push(limit);
    sql += ` LIMIT $${params.length}`;
    
    if (typeof offset === 'number' && offset > 0) {
      params.push(offset);
      sql += ` OFFSET $${params.length}`;
    }
  }
  
  const { rows } = await pool.query(sql, params);
  
  return {
    items: rows,
    total,
    limit: limit || total,
    offset: offset || 0
  };
}

module.exports = { listUsers };
