const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { OAuth2Client } = require('google-auth-library');
const { connectMongoDB } = require('../config/mongodb');
const User = require('../models/User');
const DoctorProfile = require('../models/DoctorProfile');
const LabProfile = require('../models/LabProfile');
const PharmacyProfile = require('../models/PharmacyProfile');

const GOOGLE_CLIENT_ID = '1076307742101-avj49igc93qipdcnqbqsk3u14gdcb2oh.apps.googleusercontent.com';
const googleClient = new OAuth2Client(GOOGLE_CLIENT_ID);

function detectDevice(req) {
  const platform = (req.headers['x-platform'] || '').toLowerCase();
  if (platform === 'android') return 'Android';
  if (platform === 'ios') return 'iOS';
  if (platform === 'web') return 'Web';
  const ua = (req.headers['user-agent'] || '').toLowerCase();
  if (ua.includes('android')) return 'Android';
  if (ua.includes('iphone') || ua.includes('ipad')) return 'iOS';
  if (ua.includes('mobile')) return 'Mobile';
  if (ua.includes('dart')) return 'Mobile'; // Flutter mobile fallback
  return 'Web';
}

async function logLoginSession(req, userId) {
  try {
    const entry = {
      date: new Date().toISOString(),
      ip: (req.headers['x-forwarded-for'] || req.connection?.remoteAddress || 'Unknown').split(',')[0].trim(),
      userAgent: req.headers['user-agent'] || 'Unknown',
      device: detectDevice(req),
      platform: req.headers['x-platform'] || 'unknown',
    };
    await User.findByIdAndUpdate(
      userId,
      { $push: { loginSessions: { $each: [entry], $slice: -100 } } },
      { strict: false }
    );
  } catch (_) {}
}

const { sendEmail } = require('../utils/email');

// ─── MR NUMBER GENERATOR ──────────────────────────────────────────────────────
// Format: MR-XXXXXX (6 uppercase alphanumeric chars, e.g. MR-A3F9K2)
const generateMrNumber = async () => {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I to avoid confusion
  let attempts = 0;
  while (attempts < 20) {
    let code = '';
    for (let i = 0; i < 6; i++) {
      code += chars[Math.floor(Math.random() * chars.length)];
    }
    const mrNumber = `MR-${code}`;
    // Ensure uniqueness
    const exists = await User.findOne({ mrNumber }).lean();
    if (!exists) return mrNumber;
    attempts++;
  }
  // Fallback: use timestamp-based suffix
  return `MR-${Date.now().toString(36).toUpperCase().slice(-6)}`;
};

// ─── REGISTER ─────────────────────────────────────────────────────────────────
const register = async (req, res) => {
  try {
    await connectMongoDB();
    const { username: usernameField, name, email, phone, password, role: roleRaw } = req.body;
    const username = usernameField || name;
    const role = roleRaw?.toLowerCase();

    if (!username || !email || !password || !role) {
      return res.status(400).json({ success: false, message: 'Please provide all required fields' });
    }

    // Check existing
    const existing = await User.findOne({
      $or: [{ email: email.toLowerCase() }, { username }],
    });
    if (existing) {
      return res.status(400).json({ success: false, message: 'User with this email or username already exists' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const rolesRequiringApproval = ['doctor', 'lab', 'pharmacy', 'instructor'];
    const isApproved = !rolesRequiringApproval.includes(role);

    // Auto-generate MR number for patients and students
    let mrNumber;
    if (role === 'patient' || role === 'student') {
      mrNumber = await generateMrNumber();
    }

    const user = await User.create({
      username,
      name: username,
      email: email.toLowerCase(),
      phone,
      password: hashedPassword,
      role,
      is_approved: isApproved,
      is_active: true,
      ...(mrNumber && { mrNumber }),
    });

    // Create role-specific profile
    if (role === 'doctor') {
      await DoctorProfile.create({ user_id: user._id });
    } else if (role === 'lab') {
      await LabProfile.create({ user_id: user._id });
    } else if (role === 'pharmacy') {
      await PharmacyProfile.create({ user_id: user._id });
    }

    const token = jwt.sign(
      { id: user._id.toString(), email: user.email, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.status(201).json({
      success: true,
      message: 'Registration successful',
      data: {
        token,
        user: {
          id: user._id.toString(),
          username: user.username,
          email: user.email,
          phone: user.phone,
          role: user.role,
          isApproved: user.is_approved,
          mrNumber: user.mrNumber || null,
        },
      },
    });
  } catch (error) {
    console.error('Register error:', error);
    res.status(500).json({ success: false, message: 'Server error during registration' });
  }
};

// ─── LOGIN ────────────────────────────────────────────────────────────────────
const login = async (req, res) => {
  try {
    await connectMongoDB();

    // Ensure default accounts exist (serverless-safe, runs once per cold start)
    const ensureAccount = async (email, name, role, password) => {
      const exists = await User.findOne({ email }).lean();
      if (!exists) {
        const hashed = await bcrypt.hash(password, 10);
        await User.create({ username: name, name, email, password: hashed, role, is_approved: true, is_active: true }).catch(() => {});
      } else if (exists.is_approved === false || exists.is_active === false) {
        await User.findByIdAndUpdate(exists._id, { $set: { is_approved: true, is_active: true } }).catch(() => {});
      }
    };
    await Promise.all([
      ensureAccount('admin@icare.com',      'Admin',      'admin',      'adminPassword123'),
      ensureAccount('instructor@icare.com', 'Dr. Instructor', 'Instructor', 'instructor123'),
    ]);

    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ success: false, message: 'Please provide email and password' });
    }

    // Find by email OR username
    const user = await User.findOne({
      $or: [{ email: email.toLowerCase() }, { username: email }],
    });

    if (!user) {
      return res.status(401).json({ success: false, message: 'Invalid credentials' });
    }

    // Check active
    const isActive = user.is_active !== false && user.isActive !== false;
    if (!isActive) {
      return res.status(403).json({ success: false, message: 'Your account has been deactivated' });
    }

    // Check approval for professional roles (only block if explicitly false)
    const rolesRequiringApproval = ['doctor', 'lab', 'pharmacy', 'instructor'];
    if (rolesRequiringApproval.includes(user.role?.toLowerCase()) && user.is_approved === false) {
      return res.status(403).json({ success: false, message: 'Your account is pending admin approval. Please wait for verification.' });
    }

    // Verify password
    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      return res.status(401).json({ success: false, message: 'Invalid credentials' });
    }

    // Auto-assign MR number to existing patients/students who don't have one yet
    if ((user.role === 'patient' || user.role === 'student') && !user.mrNumber) {
      try {
        const newMr = await generateMrNumber();
        await User.findByIdAndUpdate(user._id, { mrNumber: newMr });
        user.mrNumber = newMr;
      } catch (_) {}
    }

    // Log this login session
    await logLoginSession(req, user._id);

    // 2FA check — if enabled, issue temp token for TOTP verification
    if (user.twoFactorEnabled) {
      const tempToken = jwt.sign(
        { id: user._id.toString(), email: user.email, role: user.role, is2FA: true },
        process.env.JWT_SECRET,
        { expiresIn: '15m' }
      );
      return res.status(200).json({
        success: true,
        requiresOtp: true,
        tempToken,
        message: 'Open Google Authenticator and enter your 6-digit code.',
      });
    }

    const token = jwt.sign(
      { id: user._id.toString(), email: user.email, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.status(200).json({
      success: true,
      message: 'Login successful',
      data: {
        token,
        user: {
          id: user._id.toString(),
          username: user.username || user.name,
          email: user.email,
          phone: user.phone,
          role: user.role,
          isApproved: user.is_approved !== false && user.isApproved !== false,
          profilePicture: user.profilePicture || null,
          mrNumber: user.mrNumber || null,
        },
      },
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ success: false, message: 'Server error during login' });
  }
};

// ─── GET PROFILE ──────────────────────────────────────────────────────────────
const getUserProfile = async (req, res) => {
  try {
    await connectMongoDB();
    const user = await User.findById(req.user.id).select('-password');
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }
    res.status(200).json({
      success: true,
      user: {
        id: user._id.toString(),
        username: user.username || user.name,
        email: user.email,
        phone: user.phone,
        role: user.role,
        isApproved: user.is_approved !== false,
        mrNumber: user.mrNumber || null,
        prescriptionEmailEnabled: user.prescriptionEmailEnabled !== false,
      },
    });
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// ─── FORGOT PASSWORD (Send OTP) ───────────────────────────────────────────────
const forgotPassword = async (req, res) => {
  try {
    await connectMongoDB();
    const { email } = req.body;
    if (!email) return res.status(400).json({ success: false, message: 'Email is required' });

    const user = await User.findOne({ email: email.toLowerCase().trim() });
    if (!user) {
      // Don't reveal whether user exists — just say OTP sent
      return res.status(200).json({ success: true, message: 'OTP sent to your email' });
    }

    // Generate 6-digit OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expiry = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    // Save OTP to user
    await User.findByIdAndUpdate(user._id, {
      resetOtp: otp,
      resetOtpExpiry: expiry,
    });

    let emailSent = false;
    let emailError = null;
    try {
      await sendEmail({
        to: user.email,
        subject: 'iCare — Password Reset OTP',
        html: `
          <div style="font-family:Arial,sans-serif;max-width:480px;margin:0 auto;padding:32px;background:#f8fafc;border-radius:12px;">
            <h2 style="color:#0036BC;margin-bottom:8px;">iCare Password Reset</h2>
            <p style="color:#374151;font-size:15px;">Your one-time password (OTP) is:</p>
            <div style="background:#0036BC;color:#fff;font-size:32px;font-weight:bold;letter-spacing:10px;text-align:center;padding:20px;border-radius:8px;margin:20px 0;">
              ${otp}
            </div>
            <p style="color:#6b7280;font-size:13px;">This code expires in <strong>10 minutes</strong>. Do not share it with anyone.</p>
            <p style="color:#6b7280;font-size:13px;">If you did not request this, please ignore this email.</p>
          </div>
        `,
      });
      emailSent = true;
    } catch (mailErr) {
      emailError = mailErr.message;
      console.error('Email send failed:', mailErr.message);
    }

    res.status(200).json({ success: true, message: emailSent ? 'OTP sent to your email' : 'OTP generation failed. Please try again.', emailSent, emailError });
  } catch (error) {
    console.error('Forgot password error:', error);
    res.status(500).json({ success: false, message: 'Failed to send OTP. Please try again.' });
  }
};

// ─── VERIFY OTP ───────────────────────────────────────────────────────────────
const verifyOTP = async (req, res) => {
  try {
    await connectMongoDB();
    const { email, code } = req.body;
    if (!email || !code) return res.status(400).json({ success: false, message: 'Email and code are required' });

    const user = await User.findOne({ email: email.toLowerCase().trim() });
    if (!user || !user.resetOtp) {
      return res.status(400).json({ success: false, message: 'Invalid or expired OTP' });
    }

    if (user.resetOtp !== code.toString()) {
      return res.status(400).json({ success: false, message: 'Incorrect OTP. Please try again.' });
    }

    if (new Date() > new Date(user.resetOtpExpiry)) {
      return res.status(400).json({ success: false, message: 'OTP has expired. Please request a new one.' });
    }

    res.status(200).json({ success: true, message: 'OTP verified successfully' });
  } catch (error) {
    console.error('Verify OTP error:', error);
    res.status(500).json({ success: false, message: 'Verification failed. Please try again.' });
  }
};

// ─── RESET PASSWORD ───────────────────────────────────────────────────────────
const resetPassword = async (req, res) => {
  try {
    await connectMongoDB();
    const { email, password, confirmpassword } = req.body;
    if (!email || !password) return res.status(400).json({ success: false, message: 'Email and password are required' });
    if (password !== confirmpassword) return res.status(400).json({ success: false, message: 'Passwords do not match' });
    if (password.length < 6) return res.status(400).json({ success: false, message: 'Password must be at least 6 characters' });

    const user = await User.findOne({ email: email.toLowerCase().trim() });
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    const hashedPassword = await bcrypt.hash(password, 10);
    await User.findByIdAndUpdate(user._id, {
      password: hashedPassword,
      resetOtp: null,
      resetOtpExpiry: null,
    });

    res.status(200).json({ success: true, message: 'Password reset successfully' });
  } catch (error) {
    console.error('Reset password error:', error);
    res.status(500).json({ success: false, message: 'Password reset failed. Please try again.' });
  }
};

// ─── GOOGLE LOGIN ─────────────────────────────────────────────────────────────
const googleLogin = async (req, res) => {
  try {
    await connectMongoDB();
    const { idToken, accessToken, email: bodyEmail, name: bodyName } = req.body;

    let googleEmail = bodyEmail;
    let googleName = bodyName;

    // Verify idToken with Google if provided
    if (idToken) {
      try {
        const ticket = await googleClient.verifyIdToken({
          idToken,
          audience: GOOGLE_CLIENT_ID,
        });
        const payload = ticket.getPayload();
        googleEmail = payload.email;
        googleName = payload.name || bodyName;
      } catch (verifyErr) {
        // Token verification failed — fall back to email/name from request body
        console.warn('Google token verify failed, using body fields:', verifyErr.message);
        if (!bodyEmail) {
          return res.status(400).json({ success: false, message: 'Invalid Google token' });
        }
      }
    }

    if (!googleEmail) {
      return res.status(400).json({ success: false, message: 'Email not received from Google' });
    }

    googleEmail = googleEmail.toLowerCase().trim();
    const displayName = googleName || googleEmail.split('@')[0];

    // Find existing user or create new one
    let user = await User.findOne({ email: googleEmail });

    if (!user) {
      const mrNumber = await generateMrNumber();
      const randomPassword = await bcrypt.hash(crypto.randomBytes(32).toString('hex'), 10);
      user = await User.create({
        username: displayName,
        name: displayName,
        email: googleEmail,
        password: randomPassword,
        role: 'patient',
        is_approved: true,
        is_active: true,
        authProvider: 'google',
        mrNumber,
      });
    }

    const token = jwt.sign(
      { id: user._id.toString(), email: user.email, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    await logLoginSession(req, user._id);

    res.status(200).json({
      success: true,
      message: 'Google sign-in successful',
      token,
      data: {
        token,
        user: {
          id: user._id.toString(),
          username: user.username || user.name,
          email: user.email,
          phone: user.phone || '',
          role: user.role,
          isApproved: true,
          profilePicture: user.profilePicture || null,
          mrNumber: user.mrNumber || null,
        },
      },
    });
  } catch (error) {
    console.error('Google login error:', error);
    res.status(500).json({ success: false, message: 'Google sign-in failed. Please try again.' });
  }
};

// ─── APPLE LOGIN ──────────────────────────────────────────────────────────────
const appleLogin = async (req, res) => {
  try {
    await connectMongoDB();
    const { identityToken, email: bodyEmail, name: bodyName } = req.body;

    if (!identityToken && !bodyEmail) {
      return res.status(400).json({ success: false, message: 'Apple token or email required' });
    }

    // Decode Apple JWT to get email (Apple public key verification is optional here)
    let appleEmail = bodyEmail;
    let appleName = bodyName;

    if (identityToken) {
      try {
        // Decode without verification just to extract email claim
        const decoded = JSON.parse(Buffer.from(identityToken.split('.')[1], 'base64url').toString());
        appleEmail = decoded.email || bodyEmail;
      } catch (_) {
        if (!bodyEmail) {
          return res.status(400).json({ success: false, message: 'Invalid Apple token' });
        }
      }
    }

    if (!appleEmail) {
      return res.status(400).json({ success: false, message: 'Email not received from Apple' });
    }

    appleEmail = appleEmail.toLowerCase().trim();
    const displayName = appleName || appleEmail.split('@')[0];

    let user = await User.findOne({ email: appleEmail });

    if (!user) {
      const mrNumber = await generateMrNumber();
      const randomPassword = await bcrypt.hash(crypto.randomBytes(32).toString('hex'), 10);
      user = await User.create({
        username: displayName,
        name: displayName,
        email: appleEmail,
        password: randomPassword,
        role: 'patient',
        is_approved: true,
        is_active: true,
        authProvider: 'apple',
        mrNumber,
      });
    }

    const token = jwt.sign(
      { id: user._id.toString(), email: user.email, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    await logLoginSession(req, user._id);

    res.status(200).json({
      success: true,
      message: 'Apple sign-in successful',
      token,
      data: {
        token,
        user: {
          id: user._id.toString(),
          username: user.username || user.name,
          email: user.email,
          phone: user.phone || '',
          role: user.role,
          isApproved: true,
          profilePicture: user.profilePicture || null,
          mrNumber: user.mrNumber || null,
        },
      },
    });
  } catch (error) {
    console.error('Apple login error:', error);
    res.status(500).json({ success: false, message: 'Apple sign-in failed. Please try again.' });
  }
};

module.exports = { register, login, getUserProfile, forgotPassword, verifyOTP, resetPassword, googleLogin, appleLogin };
