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
  // If first argument is not a client, it's probably being called with (groupId)
  if (client && typeof client.query !== 'function') {
    groupId = client;
    client = null;
  }

  const query = async (queryObj) => {
    if (client) {
      return client.query(queryObj);
    }
    const pool = getPool();
    return pool.query(queryObj);
  };

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
      SELECT 
        gm.user_id, 
        gm.is_admin, 
        gm.joined_at,
        u.email as user_email
      FROM group_members gm
      JOIN users u ON gm.user_id = u.id
      WHERE gm.group_id = $1
      ORDER BY gm.joined_at
    `,
    values: [groupId]
  };

  const [groupResult, membersResult] = await Promise.all([
    query(groupQuery),
    query(membersQuery)
  ]);

  if (!groupResult.rows || groupResult.rows.length === 0) {
    throw new Error('Group not found');
  }

  const group = groupResult.rows[0];
  group.members = membersResult.rows.map(row => ({
    user_id: row.user_id,
    is_admin: row.is_admin,
    joined_at: row.joined_at,
    email: row.user_email,
    name: row.user_email.split('@')[0] // Use the part before @ as a simple name
  }));
  
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
           (g.type = 'private') AS is_private,
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
  const pool = getPool();
  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');
    
    // Get group details including type and owner
    const groupResult = await client.query(
      'SELECT id, owner_id, type, max_members FROM groups WHERE id = $1 FOR UPDATE',
      [groupId]
    );
    
    if (groupResult.rows.length === 0) {
      throw new Error('Group not found');
    }
    
    const group = groupResult.rows[0];
    
    // Check if user is already a member
    const memberCheck = await client.query(
      'SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2',
      [groupId, userId]
    );
    
    if (memberCheck.rows.length > 0) {
      // User is already a member, return current member count
      const countResult = await client.query(
        'SELECT COUNT(*) FROM group_members WHERE group_id = $1',
        [groupId]
      );
      await client.query('COMMIT');
      return { id: groupId, members_count: parseInt(countResult.rows[0].count) };
    }
    
    // For private groups, check if user has a pending invitation
    if (group.type === 'private') {
      const inviteCheck = await client.query(
        `SELECT id FROM group_invites 
         WHERE group_id = $1 AND user_id = $2 AND status = 'pending'`,
        [groupId, userId]
      );
      
      if (inviteCheck.rows.length === 0 && group.owner_id !== userId) {
        // No pending invite and user is not the owner
        const err = new Error('Invitation required to join private group');
        err.code = 'invitation_required';
        throw err;
      }
      
      // Mark the invite as accepted if it exists
      if (inviteCheck.rows.length > 0) {
        await client.query(
          `UPDATE group_invites 
           SET status = 'accepted', updated_at = NOW() 
           WHERE id = $1`,
          [inviteCheck.rows[0].id]
        );
      }
    }
    
    // Check group capacity
    const countResult = await client.query(
      'SELECT COUNT(*) FROM group_members WHERE group_id = $1',
      [groupId]
    );
    
    const memberCount = parseInt(countResult.rows[0].count);
    if (memberCount >= group.max_members) {
      const err = new Error('Group has reached maximum capacity');
      err.code = 'group_full';
      throw err;
    }
    
    // Add user to group
    await client.query(
      'INSERT INTO group_members (group_id, user_id) VALUES ($1, $2)',
      [groupId, userId]
    );
    
    await client.query('COMMIT');
    
    return { 
      id: groupId, 
      members_count: memberCount + 1,
      is_new_member: true
    };
    
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
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

// Remove a member by owner/admin
async function removeMember(groupId, userId) {
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
  removeMember,
  transferOwner,
  deleteGroup,
  getGroupWithMembers,
};

// Update group properties (name, type, max_members)
async function updateGroup(groupId, { name, type, max_members } = {}) {
  if (!isDbEnabled()) {
    const g = store.getGroup(Number(groupId));
    if (!g) throw Object.assign(new Error('not_found'), { status: 404, code: 'not_found' });
    if (typeof name === 'string' && name.trim()) g.name = name.trim();
    if (typeof type === 'string' && type.trim()) g.type = type.trim().toLowerCase() === 'public' ? 'open' : type.trim().toLowerCase();
    if (max_members !== undefined && max_members !== null) {
      const mm = Number(max_members);
      if (!Number.isNaN(mm) && mm > 0) g.max_members = mm;
    }
    return g;
  }
  const pool = getPool();
  const sets = [];
  const vals = [];
  let i = 1;
  if (typeof name === 'string' && name.trim()) { sets.push(`name = $${i++}`); vals.push(name.trim()); }
  if (typeof type === 'string' && type.trim()) { 
    const t = type.trim().toLowerCase() === 'public' ? 'open' : type.trim().toLowerCase();
    sets.push(`type = $${i++}`); vals.push(t); 
  }
  if (max_members !== undefined && max_members !== null) { sets.push(`max_members = $${i++}`); vals.push(Number(max_members)); }
  if (sets.length === 0) {
    const { rows } = await pool.query('SELECT * FROM groups WHERE id = $1', [groupId]);
    if (!rows[0]) throw Object.assign(new Error('not_found'), { status: 404, code: 'not_found' });
    return rows[0];
  }
  vals.push(groupId);
  const sql = `UPDATE groups SET ${sets.join(', ')} WHERE id = $${i} RETURNING *`;
  const { rows } = await pool.query(sql, vals);
  if (!rows[0]) throw Object.assign(new Error('not_found'), { status: 404, code: 'not_found' });
  return rows[0];
}

module.exports.updateGroup = updateGroup;
