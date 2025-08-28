const express = require('express');
const authRoutes = require('./modules/auth.routes');
const groupRoutes = require('./modules/groups.routes');
const messageRoutes = require('./modules/messages.routes');
const joinReqRoutes = require('./modules/joinRequests.routes');

const router = express.Router();

router.use('/auth', authRoutes);
router.use('/groups', groupRoutes);
router.use('/groups', joinReqRoutes); // nested join-requests under groups
router.use('/groups', messageRoutes); // nested messages under groups

module.exports = router;
