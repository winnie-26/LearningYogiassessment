const store = require('../data/store');
const { isDbEnabled, getPool } = require('../data/db');

async function listUsers({ q, limit, offset } = {}) {
  if (!isDbEnabled()) {
    // In-memory store: apply filtering via store, then paginate here with offset
    const all = store.listUsers({ q });
    const off = typeof offset === 'number' && offset > 0 ? offset : 0;
    let items;
    if (typeof limit === 'number') {
      items = all.slice(off, off + limit);
    } else {
      items = all.slice(off);
    }
    return {
      items,
      total: all.length,
      limit: typeof limit === 'number' ? limit : (all.length - off),
      offset: off,
    };
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

// Update user's FCM token
async function updateFcmToken(userId, fcmToken) {
  if (!isDbEnabled()) {
    // For in-memory store, we would update it here
    // For now, just log it
    console.log(`[In-Memory] Updating FCM token for user ${userId} to ${fcmToken}`);
    return { id: userId };
  }
  
  const pool = getPool();
  const { rows } = await pool.query(
    'UPDATE users SET fcm_token = $1, updated_at = NOW() WHERE id = $2 RETURNING id',
    [fcmToken, userId]
  );
  return rows[0] || null;
}

// Get a single user by ID
async function getUserById(id) {
  if (!isDbEnabled()) {
    const user = store.getUserById(id);
    return user ? { ...user, username: user.email?.split('@')[0] } : null;
  }
  const pool = getPool();
  const { rows } = await pool.query(
    'SELECT id, email, name, username, fcm_token FROM users WHERE id = $1', 
    [id]
  );
  return rows[0] || null;
}

// Alias for compatibility with WebSocket server
const findById = getUserById;

module.exports = { 
  listUsers, 
  updateFcmToken, 
  getUserById,
  findById // Add the alias for compatibility
};
