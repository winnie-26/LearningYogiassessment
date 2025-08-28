const express = require('express');
const ctrl = require('../../modules/auth.controller');

const router = express.Router();

router.post('/register', ctrl.register);
router.post('/login', ctrl.login);
router.post('/refresh', ctrl.refresh);

module.exports = router;
