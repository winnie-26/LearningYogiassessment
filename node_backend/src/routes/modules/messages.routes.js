const express = require('express');
const { authRequired } = require('../../middleware/auth');
const ctrl = require('../../modules/messages.controller');

const router = express.Router();

// POST /api/v1/groups/:id/messages
router.post('/:id/messages', authRequired, ctrl.send);

// GET /api/v1/groups/:id/messages
router.get('/:id/messages', authRequired, ctrl.list);

module.exports = router;
