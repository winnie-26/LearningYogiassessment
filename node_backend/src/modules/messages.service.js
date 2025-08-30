const repo = require('./messages.repository');
const groupsRepo = require('./groups.repository');
const { withTx } = require('../data/db');
const notificationService = require('../services/notification.service');

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
  
  const message = await withTx(async (client) => {
    return await repo.add(client, gid, userId, text);
  });

  // Send notifications to other group members in the background
  try {
    // Get group info and members
    const group = await withTx(async (client) => {
      return await groupsRepo.getGroupWithMembers(client, gid);
    });

    if (group && group.members && group.members.length > 0) {
      // Get user IDs of all members except the sender
      const recipientIds = group.members
        .filter(member => member.user_id !== userId && member.status === 'active')
        .map(member => member.user_id.toString());

      if (recipientIds.length > 0) {
        // Truncate message for notification
        const messagePreview = text.length > 100 ? text.substring(0, 100) + '...' : text;
        
        // Send notifications in the background (don't await)
        console.log(`[MessagesService] Sending notifications to ${recipientIds.length} recipients:`, recipientIds);
        notificationService.sendNewMessage(
          userId,
          recipientIds,
          gid,
          group.name,
          messagePreview
        ).catch(error => {
          console.error('Error sending message notifications:', error);
        });
      }
    }
  } catch (error) {
    console.error('Error processing message notifications:', error);
    // Don't fail the message send if notifications fail
  }

  return message;
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

async function remove(groupId, requesterId, messageId) {
  const gid = Number(groupId);
  const mid = Number(messageId);
  if (!Number.isFinite(gid) || !Number.isFinite(mid)) {
    const err = new Error('invalid_payload');
    err.status = 400;
    err.code = 'invalid_payload';
    throw err;
  }

  // Verify requester is the group owner
  const group = await withTx(async (client) => {
    return await groupsRepo.getGroupWithMembers(client, gid);
  });
  if (!group) {
    const err = new Error('Group not found');
    err.status = 404;
    throw err;
  }
  if (String(group.owner_id) !== String(requesterId)) {
    const err = new Error('Only the owner can delete messages');
    err.status = 403;
    err.code = 'forbidden';
    throw err;
  }

  return withTx(async (client) => {
    await repo.remove(client, gid, mid);
    return { ok: true };
  });
}

module.exports = { send, list, remove };
