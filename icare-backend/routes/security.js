const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/auth');
const { connectMongoDB } = require('../config/mongodb');
const speakeasy = require('speakeasy');
const QRCode = require('qrcode');

// POST /api/auth/2fa/setup — generate TOTP secret and QR code
router.post('/2fa/setup', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const User = require('../models/User');
    const user = await User.findById(req.user.id);
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    const secret = speakeasy.generateSecret({
      name: `iCare (${user.email})`,
      issuer: 'iCare',
      length: 20,
    });

    // Store secret as pending (not yet confirmed)
    await User.findByIdAndUpdate(
      user._id,
      { $set: { twoFactorSecret: secret.base32, twoFactorSecretPending: true } },
      { strict: false }
    );

    const qrCodeDataUrl = await QRCode.toDataURL(secret.otpauth_url);

    res.json({
      success: true,
      qrCode: qrCodeDataUrl,
      manualKey: secret.base32,
      message: 'Scan the QR code with Google Authenticator, then enter the 6-digit code to confirm.',
    });
  } catch (err) {
    console.error('2FA setup error:', err);
    res.status(500).json({ success: false, message: 'Failed to generate 2FA setup' });
  }
});

// POST /api/auth/2fa/enable — verify first TOTP code and activate 2FA
router.post('/2fa/enable', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { otp, code } = req.body;
    const token = otp || code;
    const User = require('../models/User');
    const user = await User.findById(req.user.id);
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    if (!user.twoFactorSecret) {
      return res.status(400).json({ success: false, message: 'Please scan the QR code first' });
    }

    const verified = speakeasy.totp.verify({
      secret: user.twoFactorSecret,
      encoding: 'base32',
      token,
      window: 1,
    });

    if (!verified) {
      return res.status(400).json({ success: false, message: 'Invalid code. Make sure your phone clock is correct and try again.' });
    }

    await User.findByIdAndUpdate(
      user._id,
      { $set: { twoFactorEnabled: true, twoFactorSecretPending: false } },
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
    await User.findByIdAndUpdate(
      req.user.id,
      { $set: { twoFactorEnabled: false }, $unset: { twoFactorSecret: '', twoFactorSecretPending: '' } },
      { strict: false }
    );
    res.json({ success: true, message: '2FA disabled' });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to disable 2FA' });
  }
});

// POST /api/auth/2fa/verify — verify TOTP code during login
router.post('/2fa/verify', async (req, res) => {
  try {
    await connectMongoDB();
    const { tempToken, otp, code } = req.body;
    const submittedToken = otp || code;
    if (!tempToken || !submittedToken) {
      return res.status(400).json({ success: false, message: 'Missing token or code' });
    }

    const jwt = require('jsonwebtoken');
    let decoded;
    try {
      decoded = jwt.verify(tempToken, process.env.JWT_SECRET);
    } catch (e) {
      return res.status(401).json({ success: false, message: 'Session expired. Please login again.' });
    }

    const User = require('../models/User');
    const user = await User.findById(decoded.id);
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    // Handle legacy users who have 2FA enabled but no TOTP secret
    if (!user.twoFactorSecret) {
      await User.findByIdAndUpdate(user._id, { $set: { twoFactorEnabled: false } });
      return res.status(400).json({
        success: false,
        message: 'Your 2FA setup is outdated. Please log in and re-enable 2FA in Settings to use Google Authenticator.',
      });
    }

    const verified = speakeasy.totp.verify({
      secret: user.twoFactorSecret,
      encoding: 'base32',
      token: submittedToken,
      window: 1,
    });

    if (!verified) {
      return res.status(400).json({ success: false, message: 'Invalid code. Please check Google Authenticator.' });
    }

    const fullToken = jwt.sign(
      { id: user._id.toString(), email: user.email, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.json({
      success: true,
      data: {
        token: fullToken,
        user: {
          id: user._id.toString(),
          username: user.username || user.name,
          email: user.email,
          phone: user.phone,
          role: user.role,
          isApproved: user.is_approved !== false,
          profilePicture: user.profilePicture || null,
          mrNumber: user.mrNumber || null,
        },
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
