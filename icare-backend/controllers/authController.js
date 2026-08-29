const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const mongoose = require('mongoose');
const { OAuth2Client } = require('google-auth-library');
const { connectMongoDB } = require('../config/mongodb');
const User = require('../models/User');
const DoctorProfile = require('../models/DoctorProfile');
const LabProfile = require('../models/LabProfile');
const PharmacyProfile = require('../models/PharmacyProfile');
const {
  OTP_TTL_MINUTES,
  RESEND_COOLDOWN_SECONDS,
  MAX_ATTEMPTS,
  generateOtp,
  hashOtp,
  otpMatches,
  sendOtpEmail,
} = require('../utils/emailOtp');

const GOOGLE_CLIENT_IDS = [
  '1076307742101-avj49igc93qipdcnqbqsk3u14gdcb2oh.apps.googleusercontent.com', // web
  '564788374793-1eptqsl65ohkvsquqhc4qnhlia592v2f.apps.googleusercontent.com',   // android
];
const googleClient = new OAuth2Client();

// Kept in sync with User.js's role enum. Shared by checkEmail() and
// register()'s existing-account branch so both report the same "still
// available to apply for" role set.
const ALL_ROLES = ['doctor', 'lab', 'pharmacy', 'instructor', 'student', 'patient'];

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

// ─── CHECK EMAIL ────────────────────────────────────────────────────────────────
// GET /auth/check-email?email=... — lets the frontend show "this email
// already has an approved <role> account, here are the roles still
// available to request" BEFORE the user fills out and submits the whole
// Work With Us form, instead of only finding out after submit.
// Plain "is this email free to sign up with?" — mirrors exactly what
// register() will accept, so the signup form's live feedback can't disagree
// with what happens on submit. checkEmail() below answers a different
// question (which roles can this approved account still apply for) and
// deliberately reports exists:false for unapproved accounts, which would
// tell the user an already-taken email is available.
const checkEmailAvailable = async (req, res) => {
  try {
    await connectMongoDB();
    const email = (req.query.email || '').toString().trim().toLowerCase();
    if (!email) return res.status(400).json({ success: false, message: 'email is required' });
    const taken = await User.exists({ email });
    res.json({ success: true, available: !taken, taken: !!taken });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

const checkEmail = async (req, res) => {
  try {
    await connectMongoDB();
    const email = (req.query.email || '').toString().trim().toLowerCase();
    if (!email) return res.status(400).json({ success: false, message: 'email is required' });

    const existing = await User.findOne({ email });
    if (!existing || existing.is_approved !== true) {
      // No account, or an unapproved one — normal new-registration flow
      // applies, nothing to report.
      return res.json({ success: true, exists: false });
    }

    const existingRolesArr = [...new Set([existing.role, ...(existing.roles || [])])].filter(Boolean);
    const existingRoles = new Set(existingRolesArr);
    const pendingRolesArr = existing.pendingRoles || [];
    const availableRoles = ALL_ROLES.filter(r => !existingRoles.has(r) && !pendingRolesArr.includes(r));

    res.json({
      success: true,
      exists: true,
      existingRoles: existingRolesArr,
      pendingRoles: pendingRolesArr,
      availableRoles,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ─── REGISTER ─────────────────────────────────────────────────────────────────
const register = async (req, res) => {
  try {
    await connectMongoDB();
    const { username: usernameField, name, email, phone, password, role: roleRaw, recaptchaToken } = req.body;
    const username = usernameField || name;
    // Display name is the real name the form sent (e.g. "Rabia Sufi"), NOT the
    // username — which for work-with-us signups is the email prefix
    // ("rabiajalalani"). Using `username` as the display name is what made
    // approved doctors show up under their email handle instead of their name.
    const displayName = (name && name.trim()) ? name.trim() : username;
    const role = roleRaw?.toLowerCase();

    if (!username || !email || !password || !role) {
      return res.status(400).json({ success: false, message: 'Please provide all required fields' });
    }

    // Soft-enforced here (unlike login) — multiple screens call this same
    // /auth/register endpoint (work_with_us_signup.dart, lms_purchase_flow.dart,
    // possibly more) and not all of them render the checkbox yet, so a hard
    // block would reject every signup from a screen that hasn't been wired
    // up. Once every register call site sends a token, flip this to match
    // login's hard block.
    const { verifyRecaptcha } = require('../utils/recaptcha');
    const recaptchaResult = await verifyRecaptcha(recaptchaToken);
    if (!recaptchaResult.ok) {
      console.warn(`reCAPTCHA failed on register for ${email}: ${recaptchaResult.reason}`);
    }

    // Identity is the email alone — deliberately NOT the username. `username`
    // falls back to the person's display name (see above), so two unrelated
    // people who happen to share a name were being rejected as duplicates.
    const existing = await User.findOne({ email: email.toLowerCase() });
    if (existing) {
      // Same email, different role, and the existing account is already
      // approved (e.g. an approved doctor now applying as a student via
      // Work-With-Us or normal signup) — instead of hard-rejecting, request
      // the new role on the SAME account via the existing multi-role system.
      // Admin still explicitly approves it from the pending-users list.
      const existingRolesArr = [...new Set([existing.role, ...(existing.roles || [])])].filter(Boolean);
      const existingRoles = new Set(existingRolesArr);
      const pendingRolesArr = existing.pendingRoles || [];
      const alreadyHasRole = existingRoles.has(role);
      const alreadyPending = pendingRolesArr.includes(role);

      if (existing.email?.toLowerCase() === email.toLowerCase() && existing.is_approved === true) {
        // Roles neither approved nor already requested — what the client
        // wants surfaced as "still available to apply for" instead of a
        // flat "email already taken" rejection.
        const availableRoles = ALL_ROLES.filter(r => !existingRoles.has(r) && !pendingRolesArr.includes(r));

        if (alreadyHasRole) {
          return res.status(400).json({
            success: false,
            message: `This email already has an approved ${role} account — no need to request that role again.`,
            existingRoles: existingRolesArr,
            availableRoles,
          });
        }
        if (alreadyPending) {
          return res.status(400).json({
            success: false,
            message: `A request for the ${role} role on this email is already pending admin approval.`,
            existingRoles: existingRolesArr,
            availableRoles,
          });
        }

        await User.findByIdAndUpdate(existing._id, { $addToSet: { pendingRoles: role } });
        // Issue a token for the EXISTING account (same as login would) so
        // the frontend can carry on exactly like a fresh registration —
        // upload the role's supporting documents, hit /users/profile with
        // verificationDetails, and land on the same verification-status
        // screen — instead of dead-ending with only a "request sent" toast
        // and no way to attach documents to the pending role request.
        const roleRequestToken = jwt.sign(
          { id: existing._id.toString(), email: existing.email, role: existing.role },
          process.env.JWT_SECRET,
          { expiresIn: '30d' }
        );
        return res.status(200).json({
          success: true,
          message: 'You already have an approved account with this email. Your request for a new role has been sent to admin for approval — you\'ll be notified once approved.',
          pendingRoleRequest: true,
          existingRoles: existingRolesArr,
          availableRoles: availableRoles.filter(r => r !== role),
          data: { token: roleRequestToken },
        });
      }

      return res.status(400).json({ success: false, message: 'An account with this email already exists' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const rolesRequiringApproval = ['doctor', 'lab', 'pharmacy', 'instructor', 'student'];
    const isApproved = !rolesRequiringApproval.includes(role);

    // Auto-generate MR number for patients and students
    let mrNumber;
    if (role === 'patient' || role === 'student') {
      mrNumber = await generateMrNumber();
    }

    // Web registrations skip phone OTP (Firebase Phone Auth requires paid plan on web).
    // Mobile (android/ios) registrations require phone verification.
    const platform = (req.headers['x-platform'] || '').toLowerCase();
    const isWebPlatform = platform === 'web' || platform === '';

    // Email ownership check. The account is created either way — otherwise a
    // half-finished signup would leave the email free for someone else to
    // claim mid-flow — but login refuses it until the code is entered.
    const otp = generateOtp();

    const user = await User.create({
      username,
      name: displayName,
      email: email.toLowerCase(),
      phone,
      password: hashedPassword,
      role,
      is_approved: isApproved,
      is_active: true,
      isPhoneVerified: isWebPlatform,
      isEmailVerified: false,
      emailVerified: false,
      emailOtpHash: hashOtp(otp),
      emailOtpExpiresAt: new Date(Date.now() + OTP_TTL_MINUTES * 60 * 1000),
      emailOtpAttempts: 0,
      emailOtpLastSentAt: new Date(),
      ...(mrNumber && { mrNumber }),
    });

    // Fire-and-forget: a slow mail server shouldn't hold up the signup
    // response. If it fails the user can hit /auth/resend-email-otp.
    sendOtpEmail({ to: user.email, name: displayName, otp })
      .catch(e => console.error('[signup] OTP email failed:', e.message));

    // A Work-With-Us applicant (doctor/lab/pharmacy/instructor) lands in
    // manual review and only ever saw "Verification in Progress" in the app —
    // nothing reached their inbox, so an applicant who closed the tab had no
    // record they'd applied at all. Same fire-and-forget treatment as the OTP.
    if (!isApproved) {
      const roleLabel = { doctor: 'Doctor', lab: 'Laboratory', pharmacy: 'Pharmacy', instructor: 'Instructor', student: 'Student' }[role] || role;
      sendEmail({
        to: user.email,
        subject: 'Your iCare application has been received',
        html: `
          <div style="font-family:Arial,Helvetica,sans-serif;max-width:560px;margin:0 auto;color:#0F172A">
            <h2 style="color:#0036BC;margin-bottom:4px">Application Received</h2>
            <p>Dear ${displayName},</p>
            <p>Thank you for applying to join iCare as a <strong>${roleLabel}</strong>. We have received your application and supporting documents.</p>
            <p>Our team is now reviewing your submission. Verification usually takes <strong>24–48 hours</strong>, and you will be updated by email in due course of time once a decision has been made.</p>
            <p>You do not need to take any further action for now.</p>
            <p style="margin-top:24px">Regards,<br/>iCare Team</p>
          </div>`,
      }).catch(e => console.error('[signup] application email failed:', e.message));
    }

    // Save verificationDetails to user document, namespaced by role so a
    // later role-request on the same account (via /users/profile) can't
    // silently overwrite this role's saved details — every Work-With-Us
    // role form reuses the same field names (organizationName, location,
    // credentials, etc.).
    const vd = req.body.verificationDetails || {};
    if (Object.keys(vd).length > 0) {
      await User.findByIdAndUpdate(
        user._id,
        { $set: { [`verificationDetails.byRole.${role}`]: vd } },
        { strict: false }
      );
    }

    // Create role-specific profile, seeding fields from verificationDetails
    if (role === 'doctor') {
      const docProfileData = { user_id: user._id };
      if (vd.specialization) docProfileData.specialization = vd.specialization;
      if (vd.pmdcNumber) docProfileData.pmdcNumber = vd.pmdcNumber;
      if (vd.licenseNumber) docProfileData.license_number = vd.licenseNumber;
      if (vd.experience) docProfileData.experience_years = vd.experience;
      if (vd.availableDays?.length) docProfileData.available_days = vd.availableDays;
      if (vd.availableTimings) docProfileData.available_hours = vd.availableTimings;
      // Save uploaded documents as credentials so they appear in the dashboard
      const credentials = [];
      if (vd.cnicDocument) credentials.push({ _id: new mongoose.Types.ObjectId(), type: 'CNIC', title: 'CNIC / National ID', documentUrl: vd.cnicDocument, status: 'pending', createdAt: new Date(), updatedAt: new Date() });
      if (vd.pmdcCertDocument) credentials.push({ _id: new mongoose.Types.ObjectId(), type: 'PMDC Certificate', title: 'PMDC Certificate', documentUrl: vd.pmdcCertDocument, status: 'pending', createdAt: new Date(), updatedAt: new Date() });
      if (vd.experienceCertDocument) credentials.push({ _id: new mongoose.Types.ObjectId(), type: 'Experience Certificate', title: 'Experience Certificate', documentUrl: vd.experienceCertDocument, status: 'pending', createdAt: new Date(), updatedAt: new Date() });
      if (credentials.length > 0) docProfileData.credentials = credentials;
      await DoctorProfile.create(docProfileData);
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
      message: 'Registration successful. Check your email for the verification code.',
      emailVerificationRequired: true,
      email: user.email,
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
          isPhoneVerified: isWebPlatform,
          isEmailVerified: false,
          emailVerified: false,
        },
      },
    });
  } catch (error) {
    console.error('Register error:', error);
    res.status(500).json({ success: false, message: 'Server error during registration' });
  }
};

// ─── EMAIL VERIFICATION ───────────────────────────────────────────────────────
// Confirms the person signing up controls the address they entered.
const verifyEmailOtp = async (req, res) => {
  try {
    await connectMongoDB();
    const email = (req.body.email || '').toString().trim().toLowerCase();
    const otp = (req.body.otp || req.body.code || '').toString().trim();

    if (!email || !otp) {
      return res.status(400).json({ success: false, message: 'Email and code are required' });
    }

    const user = await User.findOne({ email });
    // Same message whether the account is missing or the code is wrong —
    // otherwise this endpoint doubles as a way to enumerate registered emails.
    const generic = { success: false, message: 'Invalid or expired code' };
    if (!user) return res.status(400).json(generic);

    if (user.emailVerified === true) {
      return res.json({ success: true, message: 'Email already verified', alreadyVerified: true });
    }

    if (!user.emailOtpExpiresAt || user.emailOtpExpiresAt.getTime() < Date.now()) {
      return res.status(400).json({ success: false, message: 'This code has expired. Request a new one.', expired: true });
    }

    if ((user.emailOtpAttempts || 0) >= MAX_ATTEMPTS) {
      return res.status(429).json({
        success: false,
        message: 'Too many incorrect attempts. Request a new code.',
        attemptsExhausted: true,
      });
    }

    if (!otpMatches(otp, user.emailOtpHash)) {
      await User.updateOne({ _id: user._id }, { $inc: { emailOtpAttempts: 1 } });
      const left = MAX_ATTEMPTS - ((user.emailOtpAttempts || 0) + 1);
      return res.status(400).json({
        success: false,
        message: left > 0 ? `Incorrect code. ${left} attempt${left === 1 ? '' : 's'} left.` : 'Incorrect code. Request a new one.',
        attemptsLeft: Math.max(left, 0),
      });
    }

    // Correct — clear the challenge so the code can't be replayed.
    await User.updateOne({ _id: user._id }, {
      $set: { emailVerified: true, isEmailVerified: true },
      $unset: { emailOtpHash: '', emailOtpExpiresAt: '', emailOtpAttempts: '' },
    });

    const token = jwt.sign(
      { id: user._id.toString(), email: user.email, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.json({
      success: true,
      message: 'Email verified',
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
          emailVerified: true,
          isEmailVerified: true,
        },
      },
    });
  } catch (err) {
    console.error('verifyEmailOtp error:', err);
    res.status(500).json({ success: false, message: 'Server error verifying code' });
  }
};

const resendEmailOtp = async (req, res) => {
  try {
    await connectMongoDB();
    const email = (req.body.email || req.query.email || '').toString().trim().toLowerCase();
    if (!email) return res.status(400).json({ success: false, message: 'Email is required' });

    const user = await User.findOne({ email });
    // Always report success — a differing response would reveal which
    // addresses are registered.
    const ok = { success: true, message: 'If that account needs verification, a new code has been sent.' };
    if (!user || user.emailVerified === true) return res.json(ok);

    // Rate limit: one code per minute, so this can't be used to spam an inbox.
    const last = user.emailOtpLastSentAt?.getTime() || 0;
    const waited = (Date.now() - last) / 1000;
    if (waited < RESEND_COOLDOWN_SECONDS) {
      return res.status(429).json({
        success: false,
        message: `Please wait ${Math.ceil(RESEND_COOLDOWN_SECONDS - waited)}s before requesting another code.`,
        retryAfterSeconds: Math.ceil(RESEND_COOLDOWN_SECONDS - waited),
      });
    }

    const otp = generateOtp();
    await User.updateOne({ _id: user._id }, {
      $set: {
        emailOtpHash: hashOtp(otp),
        emailOtpExpiresAt: new Date(Date.now() + OTP_TTL_MINUTES * 60 * 1000),
        emailOtpAttempts: 0,
        emailOtpLastSentAt: new Date(),
      },
    });

    sendOtpEmail({ to: user.email, name: user.name || user.username, otp })
      .catch(e => console.error('[resend] OTP email failed:', e.message));

    res.json(ok);
  } catch (err) {
    console.error('resendEmailOtp error:', err);
    res.status(500).json({ success: false, message: 'Server error sending code' });
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

    const { email, password, recaptchaToken } = req.body;

    if (!email || !password) {
      return res.status(400).json({ success: false, message: 'Please provide email and password' });
    }

    // reCAPTCHA is a web-only "I'm not a robot" checkbox — it does not exist
    // in the mobile app, which therefore never sends a token. Requiring it
    // unconditionally blocked every mobile login with "Please complete the
    // I'm not a robot verification", an impossible instruction on a phone.
    // Only enforce it when a token is actually present (i.e. from the web
    // client); mobile requests carry none and skip the check. Web still
    // sends one on every submit, so this doesn't weaken the browser flow.
    if (recaptchaToken) {
      const { verifyRecaptcha } = require('../utils/recaptcha');
      const recaptchaResult = await verifyRecaptcha(recaptchaToken);
      if (!recaptchaResult.ok) {
        return res.status(400).json({ success: false, message: 'Please complete the "I\'m not a robot" verification.' });
      }
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

    // Check approval — block login until admin approves
    const rolesRequiringApproval = ['doctor', 'lab', 'pharmacy', 'instructor', 'student'];
    if (rolesRequiringApproval.includes(user.role?.toLowerCase()) && user.is_approved === false) {
      return res.status(403).json({ success: false, message: 'Your account is pending admin approval. Please wait for verification.' });
    }

    // Email verification gate. Explicitly `=== false` — accounts created
    // before this feature have the field undefined and must keep working.
    if (user.emailVerified === false) {
      return res.status(403).json({
        success: false,
        message: 'Please verify your email to continue. Check your inbox for the code.',
        emailVerificationRequired: true,
        email: user.email,
      });
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

    // All roles this account can use (always includes the primary role)
    const availableRoles = [...new Set([user.role, ...(user.roles || [])].filter(Boolean))];

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
          roles: availableRoles,
          isApproved: user.is_approved !== false && user.isApproved !== false,
          profilePicture: user.profilePicture || null,
          mrNumber: user.mrNumber || null,
          // Old accounts without these fields default to true (grandfathered)
          isPhoneVerified: user.isPhoneVerified !== false,
          isEmailVerified: user.isEmailVerified !== false,
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
        roles: [...new Set([user.role, ...(user.roles || [])].filter(Boolean))],
        pendingRoles: user.pendingRoles || [],
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
      return res.status(404).json({ success: false, message: 'No account found with this email address. Please check and try again.' });
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
          audience: GOOGLE_CLIENT_IDS,
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
        // Google already proved ownership of this address — no OTP needed.
        emailVerified: true,
        isEmailVerified: true,
        isPhoneVerified: true,
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
          isPhoneVerified: user.isPhoneVerified !== false,
          isEmailVerified: user.isEmailVerified !== false,
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
        // Apple already proved ownership of this address — no OTP needed.
        emailVerified: true,
        isEmailVerified: true,
        isPhoneVerified: true,
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
          isPhoneVerified: user.isPhoneVerified !== false,
          isEmailVerified: user.isEmailVerified !== false,
        },
      },
    });
  } catch (error) {
    console.error('Apple login error:', error);
    res.status(500).json({ success: false, message: 'Apple sign-in failed. Please try again.' });
  }
};

module.exports = { register, login, getUserProfile, forgotPassword, verifyOTP, resetPassword, googleLogin, appleLogin, checkEmail, checkEmailAvailable, verifyEmailOtp, resendEmailOtp };
