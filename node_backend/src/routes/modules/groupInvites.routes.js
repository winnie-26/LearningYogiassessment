const express = require('express');
const { authRequired } = require('../../middleware/auth');
const controller = require('../../modules/groupInvites.controller');

const router = express.Router({ mergeParams: true });

// Create a new invite to a private group
// POST /api/v1/groups/:groupId/invites
router.post('/', authRequired, controller.createInvite);

// List all invites for a group
// GET /api/v1/groups/:groupId/invites
router.get('/', authRequired, controller.listGroupInvites);

// Get a specific invite
// GET /api/v1/groups/:groupId/invites/:inviteId
router.get('/:inviteId', authRequired, controller.getInvite);

// Respond to an invite (accept/decline)
// POST /api/v1/groups/:groupId/invites/:inviteId/respond
router.post('/:inviteId/respond', authRequired, controller.respondToInvite);

// Revoke an invite (group owner or inviter only)
// DELETE /api/v1/groups/:groupId/invites/:inviteId
router.delete('/:inviteId', authRequired, controller.revokeInvite);

module.exports = router;
