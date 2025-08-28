const store = require('../data/store');

async function createGroup(name, type, maxMembers, ownerId) {
  return store.createGroup(name, type, maxMembers, ownerId);
}

async function listGroups({ limit, userId } = {}) {
  return store.listGroups({ limit, userId });
}

async function joinGroup(groupId, userId) {
  return store.joinGroup(groupId, userId);
}

async function leaveGroup(groupId, userId) {
  return store.leaveGroup(groupId, userId);
}

async function transferOwner(groupId, newOwnerId) {
  return store.transferOwner(groupId, newOwnerId);
}

async function deleteGroup(groupId) {
  return store.deleteGroup(groupId);
}

module.exports = {
  createGroup,
  listGroups,
  joinGroup,
  leaveGroup,
  transferOwner,
  deleteGroup,
};
