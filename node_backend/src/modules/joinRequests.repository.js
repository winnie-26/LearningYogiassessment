const store = require('../data/store');

async function create(groupId, userId) {
  return store.createJoinRequest(groupId, userId);
}

async function list(groupId) {
  return store.listJoinRequests(groupId);
}

async function setStatus(groupId, reqId, status) {
  return store.setJoinRequestStatus(groupId, reqId, status);
}

module.exports = { create, list, setStatus };
