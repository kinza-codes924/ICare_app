const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/auth');
const { connectMongoDB } = require('../config/mongodb');
const { sendEmail } = require('../utils/email');
const crypto = require('crypto');

// Helper: generate 6-digit OTP
function genOtp() { return String(Math.floor(100000 + Math.random() * 900000)); }

// POST /api/auth/2fa/send-otp — send OTP to email before enabling 2FA
router.post('/2fa/send-otp', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const User = require('../models/User');
    const user = await User.findById(req.user.id);
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    const otp = genOtp();
    const expires = new Date(Date.now() + 10 * 60 * 1000); // 10 min
    await User.findByIdAndUpdate(
      user._id,
      { $set: { twoFactorOtp: otp, twoFactorOtpExpires: expires } },
      { strict: false }
    );

    let emailSent = false;
    try {
      await sendEmail({
        to: user.email,
        subject: 'iCare — Enable Two-Factor Authentication',
        html: `
          <div style="font-family:Arial,sans-serif;max-width:500px;margin:0 auto;">
            <div style="background:#0036BC;padding:24px;border-radius:12px 12px 0 0;">
              <h2 style="color:#fff;margin:0;">Two-Factor Authentication</h2>
            </div>
            <div style="background:#fff;padding:24px;border-radius:0 0 12px 12px;border:1px solid #e2e8f0;">
              <p style="color:#374151;">Your OTP code to enable 2FA:</p>
              <div style="text-align:center;margin:20px 0;">
                <span style="font-size:36px;font-weight:900;letter-spacing:10px;color:#0036BC;">${otp}</span>
              </div>
              <p style="color:#94a3b8;font-size:12px;">Valid for 10 minutes. Do not share this code.</p>
            </div>
          </div>`,
      });
      emailSent = true;
    } catch (mailErr) {
      console.error('2FA OTP email error:', mailErr.message);
    }

    res.json({ success: true, message: emailSent ? `OTP sent to ${user.email}` : 'OTP generated', otp, emailSent });
  } catch (err) {
    console.error('2FA send OTP error:', err);
    res.status(500).json({ success: false, message: 'Failed to send OTP' });
  }
});

// POST /api/auth/2fa/enable — verify OTP and enable 2FA
router.post('/2fa/enable', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { otp, code } = req.body;
    const submittedOtp = otp || code;
    const User = require('../models/User');
    const user = await User.findById(req.user.id);
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    if (!user.twoFactorOtp || !user.twoFactorOtpExpires) {
      return res.status(400).json({ success: false, message: 'Please request an OTP first' });
    }
    if (new Date() > new Date(user.twoFactorOtpExpires)) {
      return res.status(400).json({ success: false, message: 'OTP has expired. Please request a new one.' });
    }
    if (user.twoFactorOtp !== submittedOtp) {
      return res.status(400).json({ success: false, message: 'Invalid OTP' });
    }

    await User.findByIdAndUpdate(
      user._id,
      { $set: { twoFactorEnabled: true }, $unset: { twoFactorOtp: '', twoFactorOtpExpires: '' } },
      { strict: false }
    );

    res.json({ success: true, message: '2FA enabled successfully' });
  } catch (err) {
    console.error('2FA enable error:', err);
    res.status(500).json({ success: false, message: 'Failed to enable 2FA' });
  }
});

// POST /api/auth/2fa/disable
router.post('/2fa/disable', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const User = require('../models/User');
    await User.findByIdAndUpdate(req.user.id, { $set: { twoFactorEnabled: false } });
    res.json({ success: true, message: '2FA disabled' });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to disable 2FA' });
  }
});

// POST /api/auth/2fa/verify — verify OTP during login
router.post('/2fa/verify', async (req, res) => {
  try {
    await connectMongoDB();
    const { tempToken, otp, code } = req.body;
    const submittedOtp = otp || code;
    if (!tempToken || !submittedOtp) return res.status(400).json({ success: false, message: 'Missing token or OTP' });

    const jwt = require('jsonwebtoken');
    let decoded;
    try { decoded = jwt.verify(tempToken, process.env.JWT_SECRET); } catch (e) { return res.status(401).json({ success: false, message: 'Invalid or expired session' }); }

    const User = require('../models/User');
    const user = await User.findById(decoded.id);
    if (!user) return res.status(404).json({ success: false });

    if (!user.twoFactorOtp || !user.twoFactorOtpExpires) {
      return res.status(400).json({ success: false, message: 'No OTP pending. Please login again.' });
    }
    if (new Date() > new Date(user.twoFactorOtpExpires)) {
      return res.status(400).json({ success: false, message: 'OTP expired. Please login again.' });
    }
    if (user.twoFactorOtp !== submittedOtp) {
      return res.status(400).json({ success: false, message: 'Invalid OTP' });
    }

    // Clear OTP and issue full token
    user.twoFactorOtp = undefined;
    user.twoFactorOtpExpires = undefined;
    user.markModified('twoFactorOtp');
    await user.save();

    const fullToken = jwt.sign(
      { id: user._id.toString(), email: user.email, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.json({
      success: true,
      data: {
        token: fullToken,
        user: { id: user._id.toString(), username: user.username || user.name, email: user.email, phone: user.phone, role: user.role, isApproved: user.is_approved !== false, profilePicture: user.profilePicture || null, mrNumber: user.mrNumber || null },
      },
    });
  } catch (err) {
    console.error('2FA verify error:', err);
    res.status(500).json({ success: false, message: 'Verification failed' });
  }
});

// PUT /api/security/biometrics
router.put('/biometrics', authMiddleware, async (req, res) => {
  res.json({ success: true, message: 'Biometric preference updated' });
});

// GET /api/security/audit-logs
router.get('/audit-logs', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const User = require('../models/User');
    const user = await User.findById(req.user.id).lean();
    const logs = user?.loginSessions || [];
    res.json({ success: true, logs: logs.slice(-50).reverse() });
  } catch (_) {
    res.json({ success: true, logs: [] });
  }
});

// POST /api/security/data-consent
router.post('/data-consent', authMiddleware, async (req, res) => {
  res.json({ success: true, message: 'Data consent updated' });
});

// GET /api/security/settings
router.get('/settings', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const User = require('../models/User');
    const user = await User.findById(req.user.id).lean();
    res.json({
      success: true,
      settings: {
        twoFactorEnabled: user?.twoFactorEnabled || false,
        biometricEnabled: false,
        loginHistory: (user?.loginSessions || []).slice(-10).reverse(),
        activeSessions: [],
      },
    });
  } catch (_) {
    res.json({ success: true, settings: { twoFactorEnabled: false, biometricEnabled: false, loginHistory: [], activeSessions: [] } });
  }
});

module.exports = router;
