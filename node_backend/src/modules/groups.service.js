const repo = require('./groups.repository');

async function list({ limit, userId }) {
  return repo.listGroups({ limit, userId });
}

async function create({ name, type, max_members }, ownerId) {
  if (!name || !type || !max_members) {
    const err = new Error('invalid_payload'); err.status = 400; err.code = 'invalid_payload'; throw err;
  }
  return repo.createGroup(name, type, Number(max_members), ownerId);
}

async function join(groupId, userId) {
  return repo.joinGroup(Number(groupId), userId);
}

async function leave(groupId, userId) {
  return repo.leaveGroup(Number(groupId), userId);
}

async function transferOwner(groupId, newOwnerId) {
  return repo.transferOwner(Number(groupId), Number(newOwnerId));
}

async function destroy(groupId) {
  await repo.deleteGroup(Number(groupId));
  return { ok: true };
}

module.exports = { list, create, join, leave, transferOwner, destroy };
