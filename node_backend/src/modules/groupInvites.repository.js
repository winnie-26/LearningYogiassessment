const { getPool } = require('../data/db');

async function createInvite(groupId, userId, inviterId) {
  const pool = getPool();
  const { rows } = await pool.query(
    `INSERT INTO group_invites (group_id, user_id, inviter_id, status)
     VALUES ($1, $2, $3, 'pending')
     RETURNING *`,
    [groupId, userId, inviterId]
  );
  return rows[0];
}

async function getInvite(inviteId) {
  const pool = getPool();
  return pool.query(
    `SELECT gi.*, 
       u1.email as user_email,
       u2.email as inviter_email,
       g.name as group_name
     FROM group_invites gi
     JOIN users u1 ON gi.user_id = u1.id
     JOIN users u2 ON gi.inviter_id = u2.id
     JOIN groups g ON gi.group_id = g.id
     WHERE gi.id = $1`,
    [inviteId]
  );
}

async function findInvite(groupId, userId) {
  const pool = getPool();
  return pool.query(
    'SELECT * FROM group_invites WHERE group_id = $1 AND user_id = $2',
    [groupId, userId]
  );
}

async function listGroupInvites(groupId, status = 'pending') {
  const pool = getPool();
  const { rows } = await pool.query(
    `SELECT gi.*, 
       u1.email as user_email,
       u2.email as inviter_email,
       g.name as group_name
     FROM group_invites gi
     JOIN users u1 ON gi.user_id = u1.id
     JOIN users u2 ON gi.inviter_id = u2.id
     JOIN groups g ON gi.group_id = g.id
     WHERE gi.group_id = $1 AND gi.status = $2
     ORDER BY gi.created_at DESC`,
    [groupId, status]
  );
  return rows;
}

async function updateInviteStatus(inviteId, status, userId) {
  const pool = getPool();
  const { rows } = await pool.query(
    `UPDATE group_invites 
     SET status = $1, 
         updated_at = NOW(),
         updated_by = $2
     WHERE id = $3
     RETURNING *`,
    [status, userId, inviteId]
  );
  return rows[0];
}

async function checkMembership(groupId, userId) {
  const pool = getPool();
  return pool.query(
    'SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2',
    [groupId, userId]
  );
}

module.exports = {
  createInvite,
  getInvite,
  findInvite,
  listGroupInvites,
  updateInviteStatus,
  checkMembership
};
