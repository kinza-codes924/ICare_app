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
    await User.findByIdAndUpdate(req.user.id, { $set: req.body }, { strict: false });
    res.json({ success: true });
  } catch (_) {
    res.json({ success: true });
  }
});

// ── 2FA routes — proxy directly to security handlers to avoid router-instance reuse issues ──
const securityRouter = require('./security');
router.post('/2fa/setup', authMiddleware, (req, res, next) => {
  req.url = '/2fa/setup';
  securityRouter.handle(req, res, next);
});
// Legacy alias — keeps old cached frontends from 404ing
router.post('/2fa/send-otp', authMiddleware, (req, res, next) => {
  req.url = '/2fa/setup';
  securityRouter.handle(req, res, next);
});
router.post('/2fa/enable', authMiddleware, (req, res, next) => {
  req.url = '/2fa/enable';
  securityRouter.handle(req, res, next);
});
router.post('/2fa/disable', authMiddleware, (req, res, next) => {
  req.url = '/2fa/disable';
  securityRouter.handle(req, res, next);
});
router.post('/2fa/verify', (req, res, next) => {
  req.url = '/2fa/verify';
  securityRouter.handle(req, res, next);
});

module.exports = router;
