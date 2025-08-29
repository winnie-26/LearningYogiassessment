const repo = require('./joinRequests.repository');

async function list(groupId) {
  return repo.list(Number(groupId));
}

async function create(groupId, userId) {
  return repo.create(Number(groupId), Number(userId));
}

async function approve(groupId, reqId) {
  return repo.setStatus(Number(groupId), Number(reqId), 'approved');
}

async function decline(groupId, reqId) {
  return repo.setStatus(Number(groupId), Number(reqId), 'declined');
}

module.exports = { list, create, approve, decline };
