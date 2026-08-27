const express = require('express');
const router = express.Router();
const { register, login, getUserProfile, forgotPassword, verifyOTP, resetPassword, googleLogin, appleLogin, checkEmail, checkEmailAvailable, verifyEmailOtp, resendEmailOtp } = require('../controllers/authController');
const { authMiddleware } = require('../middleware/auth');

// Public routes
router.get('/check-email', checkEmail);
router.get('/email-available', checkEmailAvailable);
// Email ownership verification at signup
router.post('/verify-email-otp', verifyEmailOtp);
router.post('/resend-email-otp', resendEmailOtp);
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

// ── Switch role (multi-role accounts) ─────────────────────────────────────────
// Body: { role } — must be one of the account's approved roles.
// Updates the active role and returns a fresh token + user (same shape as login).
router.post('/switch-role', authMiddleware, async (req, res) => {
  try {
    const { connectMongoDB } = require('../config/mongodb');
    await connectMongoDB();
    const User = require('../models/User');
    const jwt = require('jsonwebtoken');

    const requested = (req.body.role || '').toString().toLowerCase();
    if (!requested) return res.status(400).json({ success: false, message: 'role is required' });

    const user = await User.findById(req.user.id);
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    const availableRoles = [...new Set([user.role, ...(user.roles || [])].filter(Boolean))]
      .map(r => r.toLowerCase());
    if (!availableRoles.includes(requested)) {
      return res.status(403).json({ success: false, message: 'This role is not enabled for your account' });
    }

    // Keep the full roles list intact; only the active role changes
    if (!(user.roles || []).map(r => r.toLowerCase()).includes(user.role?.toLowerCase())) {
      user.roles = [...(user.roles || []), user.role];
    }
    user.role = requested;
    await user.save();

    const token = jwt.sign(
      { id: user._id.toString(), email: user.email, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.json({
      success: true,
      message: 'Role switched',
      data: {
        token,
        user: {
          id: user._id.toString(),
          username: user.username || user.name,
          email: user.email,
          phone: user.phone,
          role: user.role,
          roles: [...new Set([user.role, ...(user.roles || [])].filter(Boolean))],
          isApproved: user.is_approved !== false && user.isApproved !== false,
          profilePicture: user.profilePicture || null,
          mrNumber: user.mrNumber || null,
          isPhoneVerified: user.isPhoneVerified !== false,
          isEmailVerified: user.isEmailVerified !== false,
        },
      },
    });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

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

// ── PHONE & EMAIL OTP VERIFICATION ───────────────────────────────────────────

// POST /api/auth/send-email-otp  — generate 6-digit OTP, store hash+expiry, send via Brevo
router.post('/send-email-otp', authMiddleware, async (req, res) => {
  try {
    const { connectMongoDB } = require('../config/mongodb');
    await connectMongoDB();
    const User = require('../models/User');

    const user = await User.findById(req.user.id).lean();
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    if (user.isEmailVerified) {
      return res.json({ success: true, alreadyVerified: true, message: 'Email is already verified' });
    }

    const otp = String(Math.floor(100000 + Math.random() * 900000));
    const expiry = new Date(Date.now() + 10 * 60 * 1000); // 10-minute window

    await User.findByIdAndUpdate(
      req.user.id,
      { $set: { emailOtp: otp, emailOtpExpiry: expiry } },
      { strict: false }
    );

    const { sendEmail } = require('../utils/email');
    await sendEmail({
      to: user.email,
      subject: 'Your iCare Email Verification Code',
      html: `
        <div style="font-family:Arial,sans-serif;max-width:520px;margin:0 auto;background:#ffffff;border:1px solid #e2e8f0;border-radius:12px;overflow:hidden;">
          <div style="background:linear-gradient(135deg,#0036BC,#1A56DB);padding:32px 28px;">
            <img src="https://www.icare.com.co/assets/Asset%201.png" alt="iCare" height="48" style="display:block;margin-bottom:12px;" onerror="this.style.display='none'"/>
            <h1 style="color:#ffffff;font-size:22px;margin:0;font-weight:700;">Email Verification</h1>
          </div>
          <div style="padding:32px 28px;">
            <p style="color:#334155;font-size:15px;margin:0 0 24px;">
              Hi <strong>${user.name || user.username || 'there'}</strong>, use the code below to verify your iCare account email address.
              This code expires in <strong>10 minutes</strong>.
            </p>
            <div style="background:#F0F7FF;border:2px dashed #1A56DB;border-radius:10px;text-align:center;padding:28px 20px;margin-bottom:28px;">
              <p style="font-size:13px;color:#64748B;margin:0 0 8px;letter-spacing:1px;text-transform:uppercase;">Your verification code</p>
              <div style="font-size:42px;font-weight:900;letter-spacing:12px;color:#0036BC;font-family:monospace;">${otp}</div>
            </div>
            <p style="color:#94A3B8;font-size:12px;margin:0;">
              If you did not request this code, you can safely ignore this email. Your account will not be affected.
            </p>
          </div>
          <div style="background:#F8FAFC;padding:16px 28px;border-top:1px solid #E2E8F0;">
            <p style="color:#94A3B8;font-size:11px;margin:0;text-align:center;">
              © 2026 iCare · Pakistan's leading telehealth platform · <a href="https://www.icare.com.co" style="color:#1A56DB;text-decoration:none;">www.icare.com.co</a>
            </p>
          </div>
        </div>`,
    });

    res.json({ success: true, message: `Verification code sent to ${user.email}` });
  } catch (e) {
    console.error('send-email-otp error:', e.message);
    res.status(500).json({ success: false, message: e.message });
  }
});

// POST /api/auth/verify-email-otp  — compare OTP, clear it, set isEmailVerified true
router.post('/verify-email-otp', authMiddleware, async (req, res) => {
  try {
    const { connectMongoDB } = require('../config/mongodb');
    await connectMongoDB();
    const User = require('../models/User');

    const { otp } = req.body;
    if (!otp || otp.toString().trim().length !== 6) {
      return res.status(400).json({ success: false, message: 'A 6-digit verification code is required' });
    }

    const user = await User.findById(req.user.id).lean();
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    if (user.isEmailVerified) {
      return res.json({ success: true, alreadyVerified: true, message: 'Email already verified' });
    }

    if (!user.emailOtp) {
      return res.status(400).json({ success: false, message: 'No verification code found. Please request a new one.' });
    }
    if (user.emailOtp !== otp.toString().trim()) {
      return res.status(400).json({ success: false, message: 'Incorrect verification code' });
    }
    if (user.emailOtpExpiry && new Date() > new Date(user.emailOtpExpiry)) {
      return res.status(400).json({ success: false, message: 'Verification code has expired. Please request a new one.' });
    }

    await User.findByIdAndUpdate(
      req.user.id,
      {
        $set: { isEmailVerified: true },
        $unset: { emailOtp: '', emailOtpExpiry: '' },
      },
      { strict: false }
    );

    res.json({ success: true, message: 'Email verified successfully' });
  } catch (e) {
    console.error('verify-email-otp error:', e.message);
    res.status(500).json({ success: false, message: e.message });
  }
});

// POST /api/auth/send-phone-otp  — generate 6-digit OTP, store+expiry, send via Brevo SMS
router.post('/send-phone-otp', authMiddleware, async (req, res) => {
  try {
    const { connectMongoDB } = require('../config/mongodb');
    await connectMongoDB();
    const User = require('../models/User');

    const user = await User.findById(req.user.id).lean();
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    if (user.isPhoneVerified) {
      return res.json({ success: true, alreadyVerified: true, message: 'Phone already verified' });
    }

    // Use phone from request body (user may correct it) or fall back to stored phone
    const phone = (req.body.phone || user.phone || '').trim();
    if (!phone) return res.status(400).json({ success: false, message: 'Phone number is required' });

    const otp = String(Math.floor(100000 + Math.random() * 900000));
    const expiry = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    await User.findByIdAndUpdate(
      req.user.id,
      { $set: { phoneOtp: otp, phoneOtpExpiry: expiry } },
      { strict: false }
    );

    const { sendSms } = require('../utils/sms');
    await sendSms({ to: phone, message: `Your iCare verification code is: ${otp}. Valid for 10 minutes. Do not share this code.` });

    res.json({ success: true, message: `Verification code sent to ${phone}` });
  } catch (e) {
    console.error('send-phone-otp error:', e.message);
    res.status(500).json({ success: false, message: e.message });
  }
});

// POST /api/auth/verify-phone-otp  — compare OTP, clear it, set isPhoneVerified true
router.post('/verify-phone-otp', authMiddleware, async (req, res) => {
  try {
    const { connectMongoDB } = require('../config/mongodb');
    await connectMongoDB();
    const User = require('../models/User');

    const { otp } = req.body;
    if (!otp || otp.toString().trim().length !== 6) {
      return res.status(400).json({ success: false, message: 'A 6-digit verification code is required' });
    }

    const user = await User.findById(req.user.id).lean();
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    if (user.isPhoneVerified) {
      return res.json({ success: true, alreadyVerified: true, message: 'Phone already verified' });
    }

    if (!user.phoneOtp) {
      return res.status(400).json({ success: false, message: 'No verification code found. Please request a new one.' });
    }
    if (user.phoneOtp !== otp.toString().trim()) {
      return res.status(400).json({ success: false, message: 'Incorrect verification code' });
    }
    if (user.phoneOtpExpiry && new Date() > new Date(user.phoneOtpExpiry)) {
      return res.status(400).json({ success: false, message: 'Verification code has expired. Please request a new one.' });
    }

    await User.findByIdAndUpdate(
      req.user.id,
      {
        $set: { isPhoneVerified: true },
        $unset: { phoneOtp: '', phoneOtpExpiry: '' },
      },
      { strict: false }
    );

    res.json({ success: true, message: 'Phone number verified successfully' });
  } catch (e) {
    console.error('verify-phone-otp error:', e.message);
    res.status(500).json({ success: false, message: e.message });
  }
});

// POST /api/auth/mark-phone-verified  — kept for backward compatibility
router.post('/mark-phone-verified', authMiddleware, async (req, res) => {
  try {
    const { connectMongoDB } = require('../config/mongodb');
    await connectMongoDB();
    const User = require('../models/User');
    await User.findByIdAndUpdate(req.user.id, { $set: { isPhoneVerified: true } }, { strict: false });
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// GET /api/auth/verification-status  — returns current verification flags for the logged-in user
router.get('/verification-status', authMiddleware, async (req, res) => {
  try {
    const { connectMongoDB } = require('../config/mongodb');
    await connectMongoDB();
    const User = require('../models/User');

    const user = await User.findById(req.user.id).select('isPhoneVerified isEmailVerified phone email').lean();
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    res.json({
      success: true,
      isPhoneVerified: user.isPhoneVerified === true,
      isEmailVerified: user.isEmailVerified === true,
      phone: user.phone || '',
      email: user.email || '',
    });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;
