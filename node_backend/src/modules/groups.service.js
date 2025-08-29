const repo = require('./groups.repository');

async function list({ limit, userId }) {
  return repo.listGroups({ limit, userId });
}

async function create({ name, type, max_members, member_ids }, ownerId) {
  console.log('[GroupsService] create - Raw input:', { 
    name, 
    type, 
    max_members,
    member_ids,
    ownerId,
    types: {
      name: typeof name,
      type: typeof type,
      max_members: typeof max_members,
      member_ids: Array.isArray(member_ids) ? 'array' : typeof member_ids,
      ownerId: typeof ownerId
    }
  });
  
  // Validate required fields
  if (!name || !type || max_members === undefined || max_members === null) {
    const err = new Error('Missing required fields'); 
    err.status = 400; 
    err.code = 'invalid_payload'; 
    throw err;
  }
  
  // Ensure ownerId is a number
  const numericOwnerId = typeof ownerId === 'string' 
    ? parseInt(ownerId, 10) 
    : Number(ownerId);
    
  if (isNaN(numericOwnerId) || numericOwnerId <= 0) {
    const err = new Error(`Invalid owner ID: ${ownerId}`);
    err.status = 400;
    throw err;
  }
  
  // Process max_members
  const numericMaxMembers = typeof max_members === 'string' 
    ? parseInt(max_members, 10)
    : Number(max_members);
    
  if (isNaN(numericMaxMembers) || numericMaxMembers <= 0) {
    const err = new Error(`Invalid max_members: ${max_members}`);
    err.status = 400;
    throw err;
  }
  
  // Process member IDs - ensure they are valid numbers and not the owner
  let members = [];
  if (Array.isArray(member_ids)) {
    members = member_ids.reduce((acc, memberId) => {
      if (memberId === null || memberId === undefined) return acc;
      const num = typeof memberId === 'string' ? parseInt(memberId, 10) : Number(memberId);
      if (isNaN(num) || num <= 0) return acc;
      if (num === numericOwnerId) return acc; // Skip owner ID
      return [...acc, num];
    }, []);
    
    // Remove duplicates
    members = [...new Set(members)];
  }
  
  const processed = { 
    name: String(name || '').trim(),
    type: String(type || 'open').toLowerCase(),
    maxMembers: numericMaxMembers,
    ownerId: numericOwnerId,
    members
  };
  
  // Validate group type
  if (!['open', 'private'].includes(processed.type)) {
    processed.type = 'open'; // Default to open if invalid type provided
  }
  
  console.log('[GroupsService] create - Processed:', processed);
  
  try {
    return await repo.createGroup(
      processed.name,
      processed.type,
      processed.maxMembers,
      processed.ownerId,
      processed.members
    );
  } catch (error) {
    // Handle unique constraint violation
    if (error.code === '23505' && error.constraint === 'groups_name_key') {
      const err = new Error('A group with this name already exists');
      err.status = 400;
      err.code = 'duplicate_group_name';
      throw err;
    }
    // Re-throw other errors
    throw error;
  }
}

async function join(groupId, userId) {
  try {
    const out = await repo.joinGroup(Number(groupId), userId);
    // Normalize shapes from store (Set) vs DB (count)
    if (out && typeof out.members_count === 'number') return out;
    if (out && out.members && typeof out.members.size === 'number') {
      return { 
        id: out.id, 
        members_count: out.members.size,
        is_new_member: true
      };
    }
    return out;
  } catch (error) {
    // Enhance error message for private group restrictions
    if (error.code === 'invitation_required') {
      error.message = 'This is a private group. You need an invitation to join.';
      error.status = 403;
    }
    throw error;
  }
}

async function leave(groupId, userId) {
  const out = await repo.leaveGroup(Number(groupId), userId);
  if (out && typeof out.members_count === 'number') return out;
  if (out && out.members && typeof out.members.size === 'number') {
    return { id: out.id, members_count: out.members.size };
  }
  return out;
}

async function transferOwner(groupId, newOwnerId) {
  return repo.transferOwner(Number(groupId), Number(newOwnerId));
}

async function destroy(groupId) {
  await repo.deleteGroup(Number(groupId));
  return { ok: true };
}

async function update(groupId, { name, type, max_members } = {}) {
  return repo.updateGroup(Number(groupId), { name, type, max_members });
}

async function removeMember(groupId, userId) {
  return repo.removeMember(Number(groupId), Number(userId));
}

async function getGroup(groupId) {
  try {
    return await repo.getGroupWithMembers(Number(groupId));
  } catch (e) {
    if (e && e.message === 'Group not found') return null;
    throw e;
  }
}

async function checkMembership(groupId, userId) {
  const g = await getGroup(groupId);
  if (!g) return { rows: [] };
  const isMember = g.members && g.members.some(m => String(m.user_id) === String(userId));
  return { rows: isMember ? [{}] : [] };
}

module.exports = { list, create, join, leave, transferOwner, destroy, update, removeMember, getGroup, checkMembership };
