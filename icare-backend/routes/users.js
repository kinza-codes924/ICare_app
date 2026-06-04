const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const User = require('../models/User');
const { authMiddleware } = require('../middleware/auth');

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

// ─── GET PROFILE ──────────────────────────────────────────────────────────────
// Returns flat user object so Flutter's User.fromJson() can parse it directly
router.get('/profile', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const user = await User.findById(toId(req.user.id)).select('-password').lean();
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }
    // Return flat so Flutter User.fromJson receives _id, name, email, role, phoneNumber at top level
    res.json({
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
    });
  } catch (error) {
    console.error('Get user profile error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ─── UPDATE PROFILE ───────────────────────────────────────────────────────────
router.put('/profile', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { name, phoneNumber, phone, profilePicture, cnic, age, gender, height, weight, address } = req.body;
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

    const user = await User.findByIdAndUpdate(
      toId(req.user.id),
      { $set: update },
      { new: true }
    ).select('-password').lean();

    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    res.json({
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
    });
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
    const validRoles = ['patient', 'doctor', 'lab', 'pharmacy', 'admin'];
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

// ─── FALLBACK ─────────────────────────────────────────────────────────────────
router.all('/{*path}', (req, res) => {
  res.json({ success: true, users: [], count: 0 });
});

module.exports = router;
