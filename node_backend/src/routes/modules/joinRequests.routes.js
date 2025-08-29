const express = require('express');
const { authRequired } = require('../../middleware/auth');
const ctrl = require('../../modules/joinRequests.controller');

const router = express.Router();

// GET /api/v1/groups/:id/join-requests
router.get('/:id/join-requests', authRequired, ctrl.list);

// POST /api/v1/groups/:id/join-requests
router.post('/:id/join-requests', authRequired, ctrl.create);

// POST /api/v1/groups/:id/join-requests/:reqId/approve
router.post('/:id/join-requests/:reqId/approve', authRequired, ctrl.approve);

// POST /api/v1/groups/:id/join-requests/:reqId/decline
router.post('/:id/join-requests/:reqId/decline', authRequired, ctrl.decline);

module.exports = router;
