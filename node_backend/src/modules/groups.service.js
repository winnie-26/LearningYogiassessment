const repo = require('./groups.repository');

async function list({ limit, userId }) {
  return repo.listGroups({ limit, userId });
}

async function create({ name, type, max_members, member_ids }, ownerId) {
  if (!name || !type || !max_members) {
    const err = new Error('invalid_payload'); err.status = 400; err.code = 'invalid_payload'; throw err;
  }
  let members = undefined;
  if (Array.isArray(member_ids)) {
    members = member_ids.map(n => Number(n)).filter(n => Number.isFinite(n));
  }
  return repo.createGroup(name, type, Number(max_members), ownerId, members);
}

async function join(groupId, userId) {
  const out = await repo.joinGroup(Number(groupId), userId);
  // Normalize shapes from store (Set) vs DB (count)
  if (out && typeof out.members_count === 'number') return out;
  if (out && out.members && typeof out.members.size === 'number') {
    return { id: out.id, members_count: out.members.size };
  }
  return out;
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

module.exports = { list, create, join, leave, transferOwner, destroy };
