const store = require('../data/store');
const { isDbEnabled, getPool, withTx } = require('../data/db');

async function create(groupId, userId) {
  if (!isDbEnabled()) {
    return store.createJoinRequest(groupId, userId);
  }
  const pool = getPool();
  const { rows } = await pool.query(
    'INSERT INTO join_requests (group_id, requester_id, status) VALUES ($1,$2,\'pending\') RETURNING id, group_id, requester_id AS user_id, status',
    [groupId, userId]
  );
  return rows[0];
}

async function list(groupId) {
  if (!isDbEnabled()) {
    return store.listJoinRequests(groupId);
  }
  const pool = getPool();
  const { rows } = await pool.query('SELECT id, group_id, requester_id AS user_id, status FROM join_requests WHERE group_id = $1 ORDER BY id ASC', [groupId]);
  return rows;
}

async function setStatus(groupId, reqId, status) {
  if (!isDbEnabled()) {
    return store.setJoinRequestStatus(groupId, reqId, status);
  }
  return withTx(async (client) => {
    const { rows } = await client.query('UPDATE join_requests SET status = $3 WHERE id = $2 AND group_id = $1 RETURNING id, group_id, requester_id AS user_id, status', [groupId, reqId, status]);
    const jr = rows[0];
    if (!jr) throw Object.assign(new Error('not_found'), { status: 404, code: 'not_found' });
    if (status === 'approved') {
      await client.query('INSERT INTO group_members (group_id, user_id) VALUES ($1,$2) ON CONFLICT DO NOTHING', [groupId, jr.user_id]);
    }
    return jr;
  });
}

module.exports = { create, list, setStatus };
