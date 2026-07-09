const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const { authMiddleware } = require('../middleware/auth');

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

// Inline credential schema (no separate model needed — stored inside DoctorProfile)
const DoctorProfile = require('../models/DoctorProfile');

// GET /credentials/me — list doctor's credentials
router.get('/me', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const doctorId = toId(req.user.id || req.user._id || req.user.userId);
    if (!doctorId) return res.json({ success: true, credentials: [] });

    const profile = await DoctorProfile.findOne({ user_id: doctorId }).lean();
    const credentials = (profile?.credentials || []).sort(
      (a, b) => new Date(b.createdAt) - new Date(a.createdAt)
    );
    res.json({ success: true, credentials });
  } catch (e) {
    console.error('GET /credentials/me error:', e);
    res.json({ success: true, credentials: [] });
  }
});

// POST /credentials — create a credential (submitted for verification)
router.post('/', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const doctorId = toId(req.user.id || req.user._id || req.user.userId);
    if (!doctorId) return res.status(400).json({ success: false, message: 'Invalid doctor id' });

    const { type, title, documentUrl } = req.body;
    if (!type || !title) return res.status(400).json({ success: false, message: 'type and title are required' });

    const newCred = {
      _id: new mongoose.Types.ObjectId(),
      type,
      title,
      documentUrl: documentUrl || '',
      status: 'pending', // pending → unverified; admin sets verified/rejected
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    await DoctorProfile.findOneAndUpdate(
      { user_id: doctorId },
      { $push: { credentials: newCred } },
      { upsert: true, new: true }
    );

    res.status(201).json({ success: true, credential: newCred, message: 'Credential submitted for verification.' });
  } catch (e) {
    console.error('POST /credentials error:', e);
    res.status(500).json({ success: false, message: e.message });
  }
});

// PATCH /credentials/:id/verify — admin verifies a credential
router.patch('/:id/verify', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { status } = req.body; // 'verified' | 'rejected'
    if (!['verified', 'rejected'].includes(status)) {
      return res.status(400).json({ success: false, message: 'status must be verified or rejected' });
    }

    await DoctorProfile.updateOne(
      { 'credentials._id': new mongoose.Types.ObjectId(req.params.id) },
      { $set: { 'credentials.$.status': status, 'credentials.$.updatedAt': new Date() } }
    );

    res.json({ success: true, message: `Credential ${status}.` });
  } catch (e) {
    console.error('PATCH /credentials/:id/verify error:', e);
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;
