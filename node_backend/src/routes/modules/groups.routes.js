const express = require('express');
const { authRequired, authOptional } = require('../../middleware/auth');
const ctrl = require('../../modules/groups.controller');

const router = express.Router();

// GET /api/v1/groups?limit=50
router.get('/', authOptional, ctrl.list);

// POST /api/v1/groups
router.post('/', authRequired, ctrl.create);

// Check if current user can join a group
// GET /api/v1/groups/:id/can-join
router.get('/:id/can-join', authOptional, ctrl.canJoin);

// POST /api/v1/groups/:id/join
router.post('/:id/join', authRequired, ctrl.join);

// POST /api/v1/groups/:id/leave
router.post('/:id/leave', authRequired, ctrl.leave);

// POST /api/v1/groups/:id/transfer-owner
router.post('/:id/transfer-owner', authRequired, ctrl.transferOwner);

// DELETE /api/v1/groups/:id/members/:userId
router.delete('/:id/members/:userId', authRequired, ctrl.removeMember);

// PATCH /api/v1/groups/:id
router.patch('/:id', authRequired, ctrl.update);

// DELETE /api/v1/groups/:id
router.delete('/:id', authRequired, ctrl.destroy);

module.exports = router;
