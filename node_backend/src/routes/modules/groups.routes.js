const express = require('express');
const { authRequired, authOptional } = require('../../middleware/auth');
const ctrl = require('../../modules/groups.controller');

const router = express.Router();

// GET /api/v1/groups?limit=50
router.get('/groups', authOptional, ctrl.list);

// POST /api/v1/groups
router.post('/groups', authRequired, ctrl.create);

// POST /api/v1/groups/:id/join
router.post('/groups/:id/join', authRequired, ctrl.join);

// POST /api/v1/groups/:id/leave
router.post('/groups/:id/leave', authRequired, ctrl.leave);

// POST /api/v1/groups/:id/transfer-owner
router.post('/groups/:id/transfer-owner', authRequired, ctrl.transferOwner);

// DELETE /api/v1/groups/:id
router.delete('/groups/:id', authRequired, ctrl.destroy);

module.exports = router;
