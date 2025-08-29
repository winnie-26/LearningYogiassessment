const store = require('../data/store');
const { isDbEnabled, getPool, withTx } = require('../data/db');

async function createGroup(name, type, maxMembers, ownerId, memberIds = []) {
  if (!isDbEnabled()) {
    return store.createGroup(name, type, maxMembers, ownerId, memberIds);
  }
  return withTx(async (client) => {
    const { rows } = await client.query(
      `INSERT INTO groups (
        name, 
        type, 
        max_members, 
        owner_id, 
        encrypted_group_key, 
        key_nonce
      ) VALUES (
        $1, $2, $3, $4, 
        'default-encrypted-key',  -- Default encrypted key
        'default-key-nonce'       -- Default key nonce
      ) RETURNING id, name, type, max_members, owner_id`,
      [name, type, maxMembers, ownerId]
    );
    const g = rows[0];
    // Add owner as member
    await client.query('INSERT INTO group_members (group_id, user_id) VALUES ($1,$2) ON CONFLICT DO NOTHING', [g.id, ownerId]);
    let count = 1;
    // Add initial members up to max
    if (Array.isArray(memberIds)) {
      const uniq = Array.from(new Set(memberIds.map(n => Number(n)).filter(n => Number.isFinite(n) && n !== ownerId)));
      for (const uid of uniq) {
        if (count >= g.max_members) break;
        await client.query('INSERT INTO group_members (group_id, user_id) VALUES ($1,$2) ON CONFLICT DO NOTHING', [g.id, uid]);
        count++;
      }
    }
    return g;
  });
}

async function listGroups({ limit, userId } = {}) {
  if (!isDbEnabled()) {
    return store.listGroups({ limit, userId });
  }
  const pool = getPool();
  const params = [];
  let sql = `
    SELECT g.id, g.name, g.type, g.max_members, g.owner_id,
           COALESCE(COUNT(m.user_id),0)::int AS members,
           CASE WHEN $1::int IS NULL THEN NULL ELSE BOOL_OR(m.user_id = $1::int) END AS is_member
    FROM groups g
    LEFT JOIN group_members m ON m.group_id = g.id
    GROUP BY g.id
    ORDER BY g.id DESC`;
  params.push(userId || null);
  if (typeof limit === 'number') {
    params.push(limit);
    sql += ` LIMIT $${params.length}`;
  }
  const { rows } = await pool.query(sql, params);
  return rows;
}

async function joinGroup(groupId, userId) {
  if (!isDbEnabled()) {
    const g = store.joinGroup(groupId, userId);
    return { id: g.id, members_count: g.members.size };
  }
  return withTx(async (client) => {
    // enforce capacity
    const { rows } = await client.query('SELECT id, max_members FROM groups WHERE id = $1', [groupId]);
    if (!rows[0]) throw Object.assign(new Error('not_found'), { status: 404, code: 'not_found' });
    const g = rows[0];
    const { rows: cntRows } = await client.query('SELECT COUNT(*)::int AS c FROM group_members WHERE group_id = $1', [groupId]);
    const count = cntRows[0].c;
    if (count >= g.max_members) throw Object.assign(new Error('group_full'), { status: 400, code: 'group_full' });
    await client.query('INSERT INTO group_members (group_id, user_id) VALUES ($1,$2) ON CONFLICT DO NOTHING', [groupId, userId]);
    const { rows: after } = await client.query('SELECT COUNT(*)::int AS c FROM group_members WHERE group_id = $1', [groupId]);
    return { id: Number(groupId), members_count: after[0].c };
  });
}

async function leaveGroup(groupId, userId) {
  if (!isDbEnabled()) {
    const g = store.leaveGroup(groupId, userId);
    return { id: g.id, members_count: g.members.size };
  }
  const pool = getPool();
  await pool.query('DELETE FROM group_members WHERE group_id = $1 AND user_id = $2', [groupId, userId]);
  const { rows } = await pool.query('SELECT COUNT(*)::int AS c FROM group_members WHERE group_id = $1', [groupId]);
  return { id: Number(groupId), members_count: rows[0].c };
}

async function transferOwner(groupId, newOwnerId) {
  if (!isDbEnabled()) {
    return store.transferOwner(groupId, newOwnerId);
  }
  const pool = getPool();
  const { rows } = await pool.query('UPDATE groups SET owner_id = $2 WHERE id = $1 RETURNING id, owner_id', [groupId, newOwnerId]);
  if (!rows[0]) throw Object.assign(new Error('not_found'), { status: 404, code: 'not_found' });
  return rows[0];
}

async function deleteGroup(groupId) {
  if (!isDbEnabled()) {
    return store.deleteGroup(groupId);
  }
  const pool = getPool();
  await pool.query('DELETE FROM groups WHERE id = $1', [groupId]);
  return { ok: true };
}

module.exports = {
  createGroup,
  listGroups,
  joinGroup,
  leaveGroup,
  transferOwner,
  deleteGroup,
};
