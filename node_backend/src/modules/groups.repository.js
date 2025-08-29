const store = require('../data/store');
const { isDbEnabled, getPool, withTx } = require('../data/db');

async function createGroup(name, type, maxMembers, ownerId, memberIds = []) {
  console.log('[GroupsRepository] createGroup - Input:', { 
    name, 
    type, 
    maxMembers, 
    ownerId, 
    memberIds,
    types: {
      name: typeof name,
      type: typeof type,
      maxMembers: typeof maxMembers,
      ownerId: typeof ownerId,
      memberIds: Array.isArray(memberIds) ? 'array' : typeof memberIds
    }
  });

  // Ensure all numeric parameters are valid numbers
  const numericOwnerId = Number(ownerId);
  const numericMaxMembers = Number(maxMembers);
  
  if (isNaN(numericOwnerId) || numericOwnerId <= 0) {
    throw new Error(`Invalid owner ID: ${ownerId}`);
  }
  
  if (isNaN(numericMaxMembers) || numericMaxMembers <= 0) {
    throw new Error(`Invalid max members: ${maxMembers}`);
  }

  // Process member IDs to ensure they are numbers and not including owner
  const numericMemberIds = Array.isArray(memberIds) 
    ? memberIds
        .map(id => {
          const num = Number(id);
          return isNaN(num) ? null : num;
        })
        .filter(id => id !== null && id !== numericOwnerId)
    : [];

  // Remove duplicates
  const uniqueMemberIds = [...new Set(numericMemberIds)];
  
  // Start transaction
  return withTx(async (client) => {
    try {
      // Default values for encryption fields (required by DB schema)
      const encryptedKey = 'default-encrypted-key';
      const keyNonce = 'default-key-nonce';

      // Insert group
      const groupQuery = {
        text: `
          INSERT INTO groups (
            name, 
            type, 
            max_members, 
            owner_id, 
            encrypted_group_key, 
            key_nonce,
            created_at
          ) VALUES ($1, $2, $3, $4, $5, $6, NOW())
          RETURNING *
        `,
        values: [
          String(name || '').trim(),
          String(type || 'open').toLowerCase(),
          numericMaxMembers,
          numericOwnerId,
          encryptedKey,
          keyNonce
        ]
      };

      console.log('[GroupsRepository] createGroup - Executing query:', {
        query: groupQuery.text,
        values: groupQuery.values
      });

      const groupResult = await client.query(groupQuery);
      
      if (!groupResult.rows || groupResult.rows.length === 0) {
        throw new Error('Failed to create group: No rows returned');
      }

      const group = groupResult.rows[0];
      console.log('[GroupsRepository] createGroup - Group created:', group);

      // Add owner as member
      const ownerMember = {
        group_id: group.id,
        user_id: numericOwnerId,
        is_admin: true,
        joined_at: new Date()
      };

      // Add other members
      const membersToAdd = [
        ownerMember,
        ...uniqueMemberIds.map(userId => ({
          group_id: group.id,
          user_id: userId,
          is_admin: false,
          joined_at: new Date()
        }))
      ];

      // Insert members in batches to avoid parameter limits
      const batchSize = 100;
      for (let i = 0; i < membersToAdd.length; i += batchSize) {
        const batch = membersToAdd.slice(i, i + batchSize);
        const values = [];
        const valuePlaceholders = [];
        
        batch.forEach((member, index) => {
          const base = i * batchSize + index * 4;
          values.push(
            member.group_id,
            member.user_id,
            member.is_admin,
            member.joined_at
          );
          valuePlaceholders.push(
            `($${base + 1}, $${base + 2}, $${base + 3}, $${base + 4})`
          );
        });

        const memberQuery = {
          text: `
            INSERT INTO group_members (group_id, user_id, is_admin, joined_at)
            VALUES ${valuePlaceholders.join(', ')}
            ON CONFLICT (group_id, user_id) DO NOTHING
            RETURNING user_id
          `,
          values: values
        };

        console.log(`[GroupsRepository] createGroup - Adding batch ${i / batchSize + 1} of members`);
        const result = await client.query(memberQuery);
        console.log(`[GroupsRepository] createGroup - Added ${result.rowCount} members`);
      }

      // Fetch the complete group with members
      const finalGroup = await getGroupWithMembers(client, group.id);
      console.log('[GroupsRepository] createGroup - Final group:', finalGroup);
      
      return finalGroup;
    } catch (error) {
      console.error('[GroupsRepository] createGroup - Error:', error);
      throw error; // Re-throw to trigger transaction rollback
    }
  });
}

async function getGroupWithMembers(client, groupId) {
  const groupQuery = {
    text: `
      SELECT g.*, 
             COALESCE(COUNT(gm.user_id), 0)::int as members_count
      FROM groups g
      LEFT JOIN group_members gm ON g.id = gm.group_id
      WHERE g.id = $1
      GROUP BY g.id
    `,
    values: [groupId]
  };

  const membersQuery = {
    text: `
      SELECT user_id, is_admin, joined_at
      FROM group_members
      WHERE group_id = $1
      ORDER BY joined_at
    `,
    values: [groupId]
  };

  const [groupResult, membersResult] = await Promise.all([
    client.query(groupQuery),
    client.query(membersQuery)
  ]);

  if (!groupResult.rows || groupResult.rows.length === 0) {
    throw new Error('Group not found');
  }

  const group = groupResult.rows[0];
  group.members = membersResult.rows;
  
  return group;
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
