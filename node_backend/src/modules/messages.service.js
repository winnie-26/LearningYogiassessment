const repo = require('./messages.repository');
const groupsRepo = require('./groups.repository');
const { withTx } = require('../data/db');

async function send(groupId, userId, text) {
  if (!text || typeof text !== 'string') {
    const err = new Error('invalid_payload'); err.status = 400; err.code = 'invalid_payload'; throw err;
  }
  const gid = Number(groupId);
  if (!Number.isFinite(gid)) { const err = new Error('invalid_payload'); err.status = 400; err.code = 'invalid_payload'; throw err; }
  
  // Verify user is a member of the group
  const group = await withTx(async (client) => {
    return await groupsRepo.getGroupWithMembers(client, gid);
  });
  
  if (!group) {
    const err = new Error('Group not found');
    err.status = 404;
    throw err;
  }
  
  const isMember = group.members.some(member => member.user_id === userId);
  if (!isMember) {
    const err = new Error('Not a member of this group');
    err.status = 403;
    throw err;
  }
  
  return withTx(async (client) => {
    return await repo.add(client, gid, userId, text);
  });
}

async function list(groupId, { limit } = {}) {
  const gid = Number(groupId);
  if (!Number.isFinite(gid)) { 
    const err = new Error('invalid_payload'); 
    err.status = 400; 
    err.code = 'invalid_payload'; 
    throw err; 
  }
  
  // Get the group with members
  const group = await withTx(async (client) => {
    return await groupsRepo.getGroupWithMembers(client, gid);
  });
  
  if (!group) {
    const err = new Error('Group not found');
    err.status = 404;
    throw err;
  }
  
  // List messages for the group
  return withTx(async (client) => {
    return await repo.list(client, gid, { limit });
  });
}

module.exports = { send, list };
