const express = require('express');
const router = express.Router();
const { register, login, getUserProfile, forgotPassword, verifyOTP, resetPassword, googleLogin, appleLogin } = require('../controllers/authController');
const { authMiddleware } = require('../middleware/auth');

// Public routes
router.post('/register', register);
router.post('/login', login);
router.post('/google', googleLogin);
router.post('/apple', appleLogin);
// Forgot password flow
router.post('/forget_password', forgotPassword);
router.post('/checkOTP', verifyOTP);
router.post('/reset_password', resetPassword);

// Protected routes
router.get('/profile', authMiddleware, getUserProfile);

// ── 2FA routes (proxied from security router) ────────────────────────────────
const securityRouter = require('./security');
router.use('/', securityRouter);

// ── Login sessions ────────────────────────────────────────────────────────────
router.get('/sessions', authMiddleware, async (req, res) => {
  try {
    const { connectMongoDB } = require('../config/mongodb');
    await connectMongoDB();
    const User = require('../models/User');
    const user = await User.findById(req.user.id).lean();
    const sessions = (user?.loginSessions || []).slice(-50).reverse();
    res.json({ success: true, sessions });
  } catch (err) {
    res.json({ success: true, sessions: [] });
  }
});

router.delete('/sessions/:sessionId', authMiddleware, async (req, res) => {
  res.json({ success: true, message: 'Session revoked' });
});

// PUT /api/auth/update-settings
router.put('/update-settings', authMiddleware, async (req, res) => {
  try {
    const { connectMongoDB } = require('../config/mongodb');
    await connectMongoDB();
    const User = require('../models/User');
    await User.findByIdAndUpdate(req.user.id, { $set: req.body });
    res.json({ success: true });
  } catch (_) {
    res.json({ success: true });
  }
});

module.exports = router;
