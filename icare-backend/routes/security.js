const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/auth');
const { connectMongoDB } = require('../config/mongodb');
const speakeasy = require('speakeasy');
const QRCode = require('qrcode');
const {
  OTP_TTL_MINUTES,
  RESEND_COOLDOWN_SECONDS,
  MAX_ATTEMPTS,
  generateOtp,
  hashOtp,
  otpMatches,
  sendOtpEmail,
} = require('../utils/emailOtp');

// POST /api/auth/2fa/setup-email — enable email-code 2FA directly, no QR
// needed. Sends a confirmation code immediately so /2fa/enable-email can
// verify the address actually receives mail before flipping the flag on.
router.post('/2fa/setup-email', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const User = require('../models/User');
    const user = await User.findById(req.user.id);
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    const otp = generateOtp();
    await User.findByIdAndUpdate(
      user._id,
      {
        $set: {
          twoFactorMethod: 'email',
          twoFactorEmailOtpHash: hashOtp(otp),
          twoFactorEmailOtpExpiresAt: new Date(Date.now() + OTP_TTL_MINUTES * 60 * 1000),
          twoFactorEmailOtpAttempts: 0,
          twoFactorEmailOtpLastSentAt: new Date(),
        },
      },
      { strict: false }
    );
    await sendOtpEmail({ to: user.email, name: user.name || user.username, otp, purpose: 'login2fa' });

    res.json({
      success: true,
      message: `We sent a 6-digit code to ${user.email}. Enter it below to confirm.`,
    });
  } catch (err) {
    console.error('2FA email setup error:', err);
    res.status(500).json({ success: false, message: 'Failed to send confirmation code' });
  }
});

// POST /api/auth/2fa/enable-email — confirm the code from setup-email and
// activate email-based 2FA.
router.post('/2fa/enable-email', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { otp, code } = req.body;
    const submitted = otp || code;
    const User = require('../models/User');
    const user = await User.findById(req.user.id);
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    if (!user.twoFactorEmailOtpExpiresAt || user.twoFactorEmailOtpExpiresAt.getTime() < Date.now()) {
      return res.status(400).json({ success: false, message: 'Code expired. Please request a new one.' });
    }
    if ((user.twoFactorEmailOtpAttempts || 0) >= MAX_ATTEMPTS) {
      return res.status(429).json({ success: false, message: 'Too many attempts. Please request a new code.' });
    }
    if (!otpMatches(submitted, user.twoFactorEmailOtpHash)) {
      await User.updateOne({ _id: user._id }, { $inc: { twoFactorEmailOtpAttempts: 1 } });
      return res.status(400).json({ success: false, message: 'Invalid code. Please try again.' });
    }

    await User.findByIdAndUpdate(
      user._id,
      {
        $set: { twoFactorEnabled: true, twoFactorMethod: 'email' },
        $unset: {
          twoFactorEmailOtpHash: '',
          twoFactorEmailOtpExpiresAt: '',
          twoFactorEmailOtpAttempts: '',
        },
      },
      { strict: false }
    );

    res.json({ success: true, message: 'Email-based 2FA enabled successfully' });
  } catch (err) {
    console.error('2FA email enable error:', err);
    res.status(500).json({ success: false, message: 'Failed to enable 2FA' });
  }
});

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
      // Explicitly back to 'totp' -- switching from email 2FA to
      // Authenticator and completing setup must not leave the account on
      // 'email' with a live TOTP secret underneath it.
      { $set: { twoFactorEnabled: true, twoFactorSecretPending: false, twoFactorMethod: 'totp' } },
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
      {
        $set: { twoFactorEnabled: false },
        $unset: {
          twoFactorSecret: '',
          twoFactorSecretPending: '',
          twoFactorMethod: '',
          twoFactorEmailOtpHash: '',
          twoFactorEmailOtpExpiresAt: '',
          twoFactorEmailOtpAttempts: '',
        },
      },
      { strict: false }
    );
    res.json({ success: true, message: '2FA disabled' });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to disable 2FA' });
  }
});

// POST /api/auth/2fa/resend-email — re-send this login's code, for when the
// first one is lost or expires. Takes the same tempToken as /2fa/verify
// since the caller isn't authenticated yet at this point in login.
router.post('/2fa/resend-email', async (req, res) => {
  try {
    await connectMongoDB();
    const { tempToken } = req.body;
    if (!tempToken) {
      return res.status(400).json({ success: false, message: 'Missing session token' });
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
    if (user.twoFactorMethod !== 'email') {
      return res.status(400).json({ success: false, message: 'This account does not use email 2FA' });
    }

    const lastSent = user.twoFactorEmailOtpLastSentAt?.getTime() || 0;
    const waitedSeconds = (Date.now() - lastSent) / 1000;
    if (waitedSeconds < RESEND_COOLDOWN_SECONDS) {
      return res.status(429).json({
        success: false,
        message: `Please wait ${Math.ceil(RESEND_COOLDOWN_SECONDS - waitedSeconds)}s before requesting another code.`,
      });
    }

    const otp = generateOtp();
    await User.findByIdAndUpdate(user._id, {
      $set: {
        twoFactorEmailOtpHash: hashOtp(otp),
        twoFactorEmailOtpExpiresAt: new Date(Date.now() + OTP_TTL_MINUTES * 60 * 1000),
        twoFactorEmailOtpAttempts: 0,
        twoFactorEmailOtpLastSentAt: new Date(),
      },
    });
    await sendOtpEmail({ to: user.email, name: user.name || user.username, otp, purpose: 'login2fa' });

    res.json({ success: true, message: `We sent a new code to ${user.email}.` });
  } catch (err) {
    console.error('2FA resend-email error:', err);
    res.status(500).json({ success: false, message: 'Failed to resend code' });
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

    if (user.twoFactorMethod === 'email') {
      if (!user.twoFactorEmailOtpExpiresAt || user.twoFactorEmailOtpExpiresAt.getTime() < Date.now()) {
        return res.status(400).json({ success: false, message: 'Code expired. Please log in again to get a new one.' });
      }
      if ((user.twoFactorEmailOtpAttempts || 0) >= MAX_ATTEMPTS) {
        return res.status(429).json({ success: false, message: 'Too many attempts. Please log in again to get a new code.' });
      }
      if (!otpMatches(submittedToken, user.twoFactorEmailOtpHash)) {
        await User.updateOne({ _id: user._id }, { $inc: { twoFactorEmailOtpAttempts: 1 } });
        return res.status(400).json({ success: false, message: 'Invalid code. Please check your email.' });
      }
      // One-time use: clear it so the same code can't be replayed, and a
      // fresh /2fa/verify retry always needs a fresh login.
      await User.updateOne({ _id: user._id }, {
        $unset: { twoFactorEmailOtpHash: '', twoFactorEmailOtpExpiresAt: '', twoFactorEmailOtpAttempts: '' },
      });
    } else {
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
          username: user.name || user.username,
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
