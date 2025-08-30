const repo = require('./joinRequests.repository');
const notificationService = require('../services/notification.service');
const groupsRepo = require('./groups.repository');
const usersRepo = require('./users.repository');

async function list(groupId) {
  return repo.list(Number(groupId));
}

async function create(groupId, userId) {
  return repo.create(Number(groupId), Number(userId));
}

async function approve(groupId, reqId, adminId) {
  // First get the request to get the user ID
  const request = await repo.getRequest(Number(reqId));
  if (!request || request.rows.length === 0) {
    throw new Error('Join request not found');
  }
  
  const userId = request.rows[0].user_id;
  
  // Update the status
  const result = await repo.setStatus(Number(groupId), Number(reqId), 'approved');
  
  // Send notification to the user whose request was approved
  try {
    const [group, admin] = await Promise.all([
      groupsRepo.getGroupById(groupId),
      usersRepo.getUserById(adminId)
    ]);
    
    if (group && group.rows.length > 0 && admin && admin.rows.length > 0) {
      await notificationService.sendRequestAccepted(
        adminId,
        userId,
        groupId,
        group.rows[0].name
      );
    }
  } catch (error) {
    console.error('Error sending request approved notification:', error);
    // Don't fail the request if notification fails
  }
  
  return result;
}

async function decline(groupId, reqId) {
  return repo.setStatus(Number(groupId), Number(reqId), 'declined');
}

module.exports = { list, create, approve, decline };
