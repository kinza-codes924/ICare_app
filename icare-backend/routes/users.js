const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const User = require('../models/User');
const DoctorProfile = require('../models/DoctorProfile');
const InstructorProfile = require('../models/InstructorProfile');
const LabProfile = require('../models/LabProfile');
const PharmacyProfile = require('../models/PharmacyProfile');
const { authMiddleware } = require('../middleware/auth');
const { sendEmail } = require('../utils/email');
const {
  OTP_TTL_MINUTES,
  RESEND_COOLDOWN_SECONDS,
  MAX_ATTEMPTS,
  generateOtp,
  hashOtp,
  otpMatches,
} = require('../utils/emailOtp');

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

// ─── GET PROFILE ──────────────────────────────────────────────────────────────
// Returns flat user object so Flutter's User.fromJson() can parse it directly
// Includes role-specific fields (specialization, conditionsTreated, etc.)
router.get('/profile', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const user = await User.findById(toId(req.user.id)).select('-password').lean();
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    // One login can hold several roles (a patient who later applies as a
    // doctor). Those are separate identities, but the account row only stores
    // the name/photo of whichever role registered first — so a doctor
    // application filled in as "Hashim Khan" showed the patient's "Shafay
    // Hashmi" and the patient's avatar. Prefer this role's own details.
    const roleProfile = (user.roleProfiles || {})[(user.role || '').toLowerCase()]
      || (user.roleProfiles || {})[user.role] || {};
    const displayName = roleProfile.name || user.name || user.username || '';

    // Base user response
    const response = {
      _id: user._id.toString(),
      name: displayName,
      email: user.email || '',
      role: user.role || '',
      phoneNumber: user.phone || '',
      phone: user.phone || '',
      username: displayName,
      isApproved: user.is_approved !== false && user.isApproved !== false,
      createdAt: user.createdAt,
      profilePicture: roleProfile.profilePicture || user.profilePicture || null,
      gender: user.gender || null,
      age: user.age != null ? user.age.toString() : null,
      cnic: user.cnic || null,
      address: user.address || null,
      height: user.height || null,
      weight: user.weight || null,
      emergencyContacts: user.emergency_contacts || [],
      // Prefer this account's active-role bucket; fall back to the old flat
      // shape for accounts saved before verificationDetails was namespaced.
      verificationDetails:
        user.verificationDetails?.byRole?.[(user.role || '').toLowerCase()] ||
        user.verificationDetails ||
        null,
      blood_group: user.blood_group || null,
      bloodGroup: user.blood_group || null,
      existing_conditions: user.existing_conditions || null,
      existingConditions: user.existing_conditions || null,
      health_goals: user.health_goals || null,
      healthGoals: user.health_goals || null,
      specialization: null,
      conditionsTreated: null,
    };

    // Fetch role-specific profile data
    const role = (user.role || '').toLowerCase();
    
    if (role === 'doctor') {
      const doctorProfile = await DoctorProfile.findOne({ user_id: user._id }).lean();
      if (doctorProfile) {
        response.specialization = doctorProfile.specialization || null;
        response.conditionsTreated = doctorProfile.conditions_treated || [];
      }
    } else if (role === 'instructor') {
      const instructorProfile = await InstructorProfile.findOne({ user_id: user._id }).lean();
      if (instructorProfile) {
        response.specialization = instructorProfile.specialization || null;
        response.conditionsTreated = instructorProfile.conditions_treated || [];
      }
    } else if (role === 'lab' || role === 'laboratory') {
      const labProfile = await LabProfile.findOne({ user_id: user._id }).lean();
      if (labProfile) {
        response.specialization = labProfile.specialization || null;
      }
    } else if (role === 'pharmacy') {
      const pharmacyProfile = await PharmacyProfile.findOne({ user_id: user._id }).lean();
      if (pharmacyProfile) {
        response.specialization = pharmacyProfile.specialization || null;
      }
    }

    res.json(response);
  } catch (error) {
    console.error('Get user profile error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ─── UPDATE PROFILE ───────────────────────────────────────────────────────────
router.put('/profile', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const {
      name, phoneNumber, phone, profilePicture, cnic, age, gender,
      height, weight, address, existingConditions, healthGoals,
      emergencyContacts, specialization, conditionsTreated,
      bloodGroup, blood_group, verificationDetails, verificationRole,
    } = req.body;
    const finalBloodGroup = bloodGroup || blood_group;
    
    const update = {};
    // Name and photo are per-role: an account holding both a patient and a
    // doctor role is two identities sharing one login, so editing one must not
    // rename or re-picture the other. Written to both places — the role-scoped
    // copy the profile route now prefers, and the top-level field everything
    // else (and any account with a single role) still reads.
    const roleKey = (req.user?.role || '').toLowerCase();
    if (name) {
      update.name = name;
      update.username = name;
      if (roleKey) update[`roleProfiles.${roleKey}.name`] = name;
    }
    const finalPhone = phoneNumber || phone;
    if (finalPhone) update.phone = finalPhone;
    if (profilePicture !== undefined) {
      update.profilePicture = profilePicture;
      if (roleKey) update[`roleProfiles.${roleKey}.profilePicture`] = profilePicture;
    }
    if (cnic !== undefined) update.cnic = cnic;
    if (age !== undefined) update.age = age;
    if (gender !== undefined) update.gender = gender;
    if (height !== undefined) update.height = height;
    if (weight !== undefined) update.weight = weight;
    if (address !== undefined) update.address = address;
    if (existingConditions !== undefined) update.existing_conditions = existingConditions;
    if (healthGoals !== undefined) update.health_goals = healthGoals;
    if (emergencyContacts !== undefined) update.emergency_contacts = emergencyContacts;
    if (finalBloodGroup !== undefined && finalBloodGroup !== null) update.blood_group = finalBloodGroup;

    // verificationDetails was not read from the body at all, so it was
    // silently dropped here. Work-with-us signup registers first (storing
    // only the document *names*) and then uploads each file and PUTs the
    // resulting *URLs* back through this route — so the URLs never landed,
    // and the admin approval screen showed no documents for any role. Merged
    // key-by-key rather than replaced, because that second call carries only
    // the document fields and would otherwise wipe the qualification,
    // institution, etc. saved at registration.
    //
    // verificationRole namespaces the write under verificationDetails.byRole.<role>
    // instead of the flat top-level object. Every Work-With-Us role's form uses
    // the same field names (organizationName, location, credentials, comments,
    // etc.), so on a multi-role account a second role's submission used to
    // silently overwrite the first role's saved details — the exact bug where
    // admin could no longer see an earlier role's application after a new one
    // came in. Old single-role accounts/rows keep working via the flat fallback
    // in the read path (GET /profile and admin's pending-users).
    if (verificationDetails && typeof verificationDetails === 'object') {
      if (verificationRole) {
        const roleKey = verificationRole.toString().toLowerCase();
        for (const [k, v] of Object.entries(verificationDetails)) {
          update[`verificationDetails.byRole.${roleKey}.${k}`] = v;
        }
      } else {
        for (const [k, v] of Object.entries(verificationDetails)) {
          update[`verificationDetails.${k}`] = v;
        }
      }
    }

    // strict:false is required — verificationDetails is not declared on the
    // User schema, so Mongoose would strip those paths otherwise. This is the
    // same reason authController.js passes it when saving them at signup.
    const user = await User.findByIdAndUpdate(
      toId(req.user.id),
      { $set: update },
      { new: true, strict: false }
    ).select('-password').lean();

    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    // Update role-specific profile data
    const role = (user.role || '').toLowerCase();
    
    if (role === 'doctor' && (specialization !== undefined || conditionsTreated !== undefined)) {
      const docUpdate = {};
      if (specialization !== undefined) docUpdate.specialization = specialization;
      if (conditionsTreated !== undefined) docUpdate.conditions_treated = conditionsTreated;
      await DoctorProfile.findOneAndUpdate(
        { user_id: user._id },
        { $set: docUpdate },
        { upsert: true }
      );
    } else if (role === 'instructor' && (specialization !== undefined || conditionsTreated !== undefined)) {
      const instrUpdate = {};
      if (specialization !== undefined) instrUpdate.specialization = specialization;
      if (conditionsTreated !== undefined) instrUpdate.conditions_treated = conditionsTreated;
      await InstructorProfile.findOneAndUpdate(
        { user_id: user._id },
        { $set: instrUpdate },
        { upsert: true }
      );
    }

    // Build response — same role-scoped preference as GET /profile.
    const savedRoleProfile = (user.roleProfiles || {})[role] || {};
    const savedName = savedRoleProfile.name || user.name || user.username || '';

    const response = {
      _id: user._id.toString(),
      name: savedName,
      email: user.email || '',
      role: user.role || '',
      phoneNumber: user.phone || '',
      phone: user.phone || '',
      username: savedName,
      isApproved: user.is_approved !== false,
      createdAt: user.createdAt,
      profilePicture: savedRoleProfile.profilePicture || user.profilePicture || null,
      gender: user.gender || null,
      age: user.age != null ? user.age.toString() : null,
      cnic: user.cnic || null,
      address: user.address || null,
      height: user.height || null,
      weight: user.weight || null,
      emergencyContacts: user.emergency_contacts || [],
      blood_group: user.blood_group || null,
      bloodGroup: user.blood_group || null,
      existing_conditions: user.existing_conditions || null,
      existingConditions: user.existing_conditions || null,
      health_goals: user.health_goals || null,
      healthGoals: user.health_goals || null,
      specialization: specialization || null,
      conditionsTreated: conditionsTreated || null,
    };

    res.json({ success: true, user: response, message: 'Profile updated successfully' });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ success: false, message: 'Failed to update profile' });
  }
});

// ─── SAVE FCM TOKEN ───────────────────────────────────────────────────────────
router.post('/fcm-token', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { fcmToken } = req.body;
    if (fcmToken) {
      await User.findByIdAndUpdate(toId(req.user.id), { $addToSet: { fcm_tokens: fcmToken } });
    }
    res.json({ success: true, message: 'FCM token saved' });
  } catch (error) {
    console.error('FCM token error:', error);
    res.json({ success: true, message: 'FCM token saved' });
  }
});

// ─── SEARCH USERS ─────────────────────────────────────────────────────────────
router.get('/search', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { q, role } = req.query;
    const query = { is_active: { $ne: false } };
    if (role) query.role = role;
    if (q) {
      query.$or = [
        { name: { $regex: q, $options: 'i' } },
        { username: { $regex: q, $options: 'i' } },
        { email: { $regex: q, $options: 'i' } },
      ];
    }
    const users = await User.find(query).select('-password').limit(20).lean();
    const result = users.map(u => ({
      _id: u._id.toString(),
      name: u.name || u.username || '',
      email: u.email || '',
      role: u.role || '',
      phoneNumber: u.phone || '',
    }));
    res.json({ success: true, users: result, count: result.length });
  } catch (error) {
    console.error('Search users error:', error);
    res.json({ success: true, users: [], count: 0 });
  }
});

// ─── SET ROLE (admin/debug only) ──────────────────────────────────────────────
// POST /api/users/set-role { email, role }
router.post('/set-role', async (req, res) => {
  try {
    await connectMongoDB();
    const { email, role } = req.body;
    if (!email || !role) return res.status(400).json({ success: false, message: 'email and role required' });
    const validRoles = ['patient', 'doctor', 'lab', 'pharmacy', 'admin', 'instructor', 'student'];
    if (!validRoles.includes(role)) return res.status(400).json({ success: false, message: 'invalid role' });
    const user = await User.findOneAndUpdate(
      { email: email.toLowerCase() },
      { $set: { role, is_active: true, is_approved: true } },
      { new: true }
    ).select('-password').lean();
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    res.json({ success: true, user: { _id: user._id, email: user.email, role: user.role } });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── DELETE ACCOUNT ───────────────────────────────────────────────────────────
// Deletion is permanent, so it takes a code emailed to the account's own
// address — typing "DELETE" alone was the only guard, which anyone holding an
// unlocked phone could pass.
// POST /api/users/me/delete-otp — send the confirmation code
router.post('/me/delete-otp', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    if (!userId) return res.status(400).json({ success: false, message: 'Invalid user ID' });

    const user = await User.findById(userId).select('email name username deleteOtpLastSentAt').lean();
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    if (!user.email) return res.status(400).json({ success: false, message: 'This account has no email address' });

    const lastSent = user.deleteOtpLastSentAt ? new Date(user.deleteOtpLastSentAt) : null;
    if (lastSent && (Date.now() - lastSent.getTime()) < RESEND_COOLDOWN_SECONDS * 1000) {
      const wait = Math.ceil((RESEND_COOLDOWN_SECONDS * 1000 - (Date.now() - lastSent.getTime())) / 1000);
      return res.status(429).json({ success: false, message: `Please wait ${wait}s before requesting another code` });
    }

    const otp = generateOtp();
    await User.findByIdAndUpdate(userId, {
      $set: {
        deleteOtpHash: hashOtp(otp),
        deleteOtpExpiresAt: new Date(Date.now() + OTP_TTL_MINUTES * 60 * 1000),
        deleteOtpAttempts: 0,
        deleteOtpLastSentAt: new Date(),
      },
    }, { strict: false });

    const name = user.name || user.username || 'there';
    await sendEmail({
      to: user.email,
      subject: 'Confirm your iCare account deletion',
      html: `
        <div style="font-family:Arial,Helvetica,sans-serif;max-width:560px;margin:0 auto;color:#0F172A">
          <h2 style="color:#EF4444;margin-bottom:4px">Confirm Account Deletion</h2>
          <p>Dear ${name},</p>
          <p>We received a request to permanently delete your iCare account. Enter this code in the app to confirm:</p>
          <p style="font-size:28px;font-weight:800;letter-spacing:6px;color:#0F172A;margin:20px 0">${otp}</p>
          <p>The code expires in ${OTP_TTL_MINUTES} minutes.</p>
          <p><strong>If you did not request this, ignore this email</strong> — your account stays exactly as it is, and we'd suggest changing your password.</p>
          <p style="margin-top:24px">Regards,<br/>iCare Team</p>
        </div>`,
    });

    res.json({ success: true, message: 'Confirmation code sent to your email' });
  } catch (err) {
    console.error('POST /users/me/delete-otp error:', err);
    res.status(500).json({ success: false, message: 'Failed to send confirmation code' });
  }
});

// DELETE /api/users/me — permanently delete the authenticated user's account
router.delete('/me', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    if (!userId) return res.status(400).json({ success: false, message: 'Invalid user ID' });

    const user = await User.findById(userId).lean();
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    // Verify the emailed code before touching anything.
    const submitted = (req.body?.otp || '').toString().trim();
    if (!submitted) {
      return res.status(400).json({ success: false, code: 'OTP_REQUIRED', message: 'Confirmation code is required' });
    }
    if (!user.deleteOtpHash || !user.deleteOtpExpiresAt) {
      return res.status(400).json({ success: false, code: 'OTP_REQUIRED', message: 'Request a confirmation code first' });
    }
    if (new Date(user.deleteOtpExpiresAt).getTime() < Date.now()) {
      return res.status(400).json({ success: false, code: 'OTP_EXPIRED', message: 'That code has expired — request a new one' });
    }
    if ((user.deleteOtpAttempts || 0) >= MAX_ATTEMPTS) {
      return res.status(429).json({ success: false, code: 'OTP_LOCKED', message: 'Too many incorrect codes — request a new one' });
    }
    if (!otpMatches(submitted, user.deleteOtpHash)) {
      await User.findByIdAndUpdate(userId, { $inc: { deleteOtpAttempts: 1 } }, { strict: false });
      return res.status(400).json({ success: false, code: 'OTP_INVALID', message: 'Incorrect code' });
    }

    const role = (user.role || '').toLowerCase();

    // Delete role-specific profile data
    if (role === 'doctor') {
      await DoctorProfile.deleteMany({ user_id: userId });
    } else if (role === 'instructor') {
      await InstructorProfile.deleteMany({ user_id: userId });
    } else if (role === 'lab' || role === 'laboratory') {
      await LabProfile.deleteMany({ user_id: userId });
    } else if (role === 'pharmacy') {
      await PharmacyProfile.deleteMany({ user_id: userId });
    }

    // Delete the user
    await User.findByIdAndDelete(userId);

    res.json({ success: true, message: 'Account deleted successfully' });
  } catch (err) {
    console.error('DELETE /users/me error:', err);
    res.status(500).json({ success: false, message: 'Failed to delete account' });
  }
});

// ─── FALLBACK ─────────────────────────────────────────────────────────────────
router.all('/{*path}', (req, res) => {
  res.json({ success: true, users: [], count: 0 });
});

module.exports = router;