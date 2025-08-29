const express = require('express');
const { authRequired } = require('../../middleware/auth');
const ctrl = require('../../modules/users.controller');

const router = express.Router();

// GET /api/v1/users?q=abc&limit=50
router.get('/', authRequired, ctrl.list);

module.exports = router;
