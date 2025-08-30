const repo = require('./groupInvites.repository');
const { isDbEnabled } = require('../data/db');

class InviteError extends Error {
  constructor(message, code, status = 400) {
    super(message);
    this.code = code;
    this.status = status;
    this.name = 'InviteError';
  }
}

async function createInvite(groupId, userId, inviterId) {
  if (!isDbEnabled()) {
    // In-memory store not implemented for invites
    throw new InviteError('Invites not supported in memory mode', 'not_supported', 501);
  }

  // Check if user is already a member
  const { rows: memberCheck } = await repo.checkMembership(groupId, userId);
  if (memberCheck.length > 0) {
    throw new InviteError('User is already a member of this group', 'already_member');
  }

  // Check if invite already exists
  const { rows: existingInvite } = await repo.findInvite(groupId, userId);
  if (existingInvite.length > 0) {
    if (existingInvite[0].status === 'pending') {
      return existingInvite[0]; // Return existing pending invite
    }
    throw new InviteError('Invite already exists with status: ' + existingInvite[0].status, 'invite_exists');
  }

  // Create new invite
  return repo.createInvite(groupId, userId, inviterId);
}

async function getInvite(inviteId) {
  if (!isDbEnabled()) {
    throw new InviteError('Invites not supported in memory mode', 'not_supported', 501);
  }
  
  const { rows } = await repo.getInvite(inviteId);
  if (rows.length === 0) {
    throw new InviteError('Invite not found', 'not_found', 404);
  }
  return rows[0];
}

async function listGroupInvites(groupId, status = 'pending') {
  if (!isDbEnabled()) {
    return [];
  }
  const { rows } = await repo.listGroupInvites(groupId, status);
  return rows;
}

async function updateInviteStatus(inviteId, status, userId) {
  if (!isDbEnabled()) {
    throw new InviteError('Invites not supported in memory mode', 'not_supported', 501);
  }

  const validStatuses = ['accepted', 'declined', 'revoked'];
  if (!validStatuses.includes(status)) {
    throw new InviteError('Invalid status', 'invalid_status');
  }

  // Get current invite
  const { rows } = await repo.getInvite(inviteId);
  if (rows.length === 0) {
    throw new InviteError('Invite not found', 'not_found', 404);
  }

  const invite = rows[0];
  
  // Only pending invites can be updated
  if (invite.status !== 'pending') {
    throw new InviteError(`Cannot update invite with status: ${invite.status}`, 'invalid_status');
  }

  // Only the invited user or group admin can update the invite
  if (invite.user_id !== userId && invite.inviter_id !== userId) {
    throw new InviteError('Not authorized to update this invite', 'unauthorized', 403);
  }

  return repo.updateInviteStatus(inviteId, status, userId);
}

module.exports = {
  createInvite,
  getInvite,
  listGroupInvites,
  updateInviteStatus,
  InviteError
};
