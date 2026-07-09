const express = require('express');
const router = express.Router();
const { getToken } = require('../controllers/agoraController');

// GET /api/agora/token?channelName=xxx&uid=0
router.get('/token', getToken);

module.exports = router;
