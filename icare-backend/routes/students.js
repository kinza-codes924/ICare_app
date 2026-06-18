const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const { authMiddleware } = require('../middleware/auth');
const User = require('../models/User');

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

// GET /students/me — returns current student's profile from User model
router.get('/me', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const user = await User.findById(toId(req.user.id)).select('-password').lean();
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    res.json({
      success: true,
      student: {
        _id: user._id.toString(),
        name: user.name || user.username || '',
        email: user.email || '',
        profilePicture: user.profilePicture || null,
        age: user.age != null ? user.age.toString() : '',
        gender: user.gender || '',
        address: user.address || '',
        bio: user.bio || '',
        qualification: user.qualification || '',
        educationLevel: user.educationLevel || '',
        preferences: user.preferences || [],
      },
    });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// POST /students/add_student_details — save student profile fields to User model
router.post('/add_student_details', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const { name, profilePicture, age, gender, address, bio, qualification, educationLevel, preferences } = req.body;

    const update = {};
    if (name) { update.name = name; update.username = name; }
    if (profilePicture !== undefined) update.profilePicture = profilePicture;
    if (age !== undefined) update.age = age;
    if (gender !== undefined) update.gender = gender;
    if (address !== undefined) update.address = address;
    if (bio !== undefined) update.bio = bio;
    if (qualification !== undefined) update.qualification = qualification;
    if (educationLevel !== undefined) update.educationLevel = educationLevel;
    if (preferences !== undefined) update.preferences = preferences;

    const user = await User.findByIdAndUpdate(userId, { $set: update }, { new: true }).select('-password').lean();
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    res.json({
      success: true,
      student: {
        _id: user._id.toString(),
        name: user.name || user.username || '',
        email: user.email || '',
        profilePicture: user.profilePicture || null,
        age: user.age != null ? user.age.toString() : '',
        gender: user.gender || '',
        address: user.address || '',
        bio: user.bio || '',
        qualification: user.qualification || '',
        educationLevel: user.educationLevel || '',
        preferences: user.preferences || [],
      },
    });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;
