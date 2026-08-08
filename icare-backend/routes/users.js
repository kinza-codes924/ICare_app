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

    // Base user response
    const response = {
      _id: user._id.toString(),
      name: user.name || user.username || '',
      email: user.email || '',
      role: user.role || '',
      phoneNumber: user.phone || '',
      phone: user.phone || '',
      username: user.username || user.name || '',
      isApproved: user.is_approved !== false && user.isApproved !== false,
      createdAt: user.createdAt,
      profilePicture: user.profilePicture || null,
      gender: user.gender || null,
      age: user.age != null ? user.age.toString() : null,
      cnic: user.cnic || null,
      address: user.address || null,
      height: user.height || null,
      weight: user.weight || null,
      emergencyContacts: user.emergency_contacts || [],
      verificationDetails: user.verificationDetails || null,
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
      bloodGroup, blood_group, verificationDetails,
    } = req.body;
    const finalBloodGroup = bloodGroup || blood_group;
    
    const update = {};
    if (name) { update.name = name; update.username = name; }
    const finalPhone = phoneNumber || phone;
    if (finalPhone) update.phone = finalPhone;
    if (profilePicture !== undefined) update.profilePicture = profilePicture;
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
    if (verificationDetails && typeof verificationDetails === 'object') {
      for (const [k, v] of Object.entries(verificationDetails)) {
        update[`verificationDetails.${k}`] = v;
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

    // Build response
    const response = {
      _id: user._id.toString(),
      name: user.name || user.username || '',
      email: user.email || '',
      role: user.role || '',
      phoneNumber: user.phone || '',
      phone: user.phone || '',
      username: user.username || user.name || '',
      isApproved: user.is_approved !== false,
      createdAt: user.createdAt,
      profilePicture: user.profilePicture || null,
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
// DELETE /api/users/me — permanently delete the authenticated user's account
router.delete('/me', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    if (!userId) return res.status(400).json({ success: false, message: 'Invalid user ID' });

    const user = await User.findById(userId).lean();
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

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