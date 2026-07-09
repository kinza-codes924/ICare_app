const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const multer = require('multer');
const { put } = require('@vercel/blob');
const { connectMongoDB } = require('../config/mongodb');
const { authMiddleware } = require('../middleware/auth');
const StudentVerification = require('../models/StudentVerification');
const User = require('../models/User');

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } });

// Vercel Blob — same private-storage + backend-proxy pattern as
// upload.js's /blob-doc route, avoiding Cloudinary's delivery-restriction
// failures seen on the doc-stream proxy (401/404 across all fallback attempts).
function uploadToBlob(buffer, originalname, mimetype) {
  const safeName = originalname.replace(/[^a-zA-Z0-9._-]/g, '_');
  const blobPath = `verification/${Date.now()}-${safeName}`;
  return put(blobPath, buffer, {
    access: 'private',
    contentType: mimetype,
    addRandomSuffix: false,
  });
}

// ── STUDENT: Upload verification documents ──────────────────────────────────
router.post('/upload', authMiddleware, upload.array('documents', 5), async (req, res) => {
  try {
    await connectMongoDB();
    const userId = toId(req.user.id);
    const { documentTypes } = req.body; // JSON array of types
    
    if (!req.files || req.files.length === 0) {
      return res.status(400).json({ success: false, message: 'No files uploaded' });
    }

    const types = JSON.parse(documentTypes || '[]');
    const documents = [];

    for (let i = 0; i < req.files.length; i++) {
      const file = req.files[i];
      const type = types[i] || 'other';

      const blob = await uploadToBlob(file.buffer, file.originalname, file.mimetype);
      documents.push({
        type,
        url: blob.url,
        fileName: file.originalname,
        uploadedAt: new Date()
      });
    }

    let verification = await StudentVerification.findOne({ userId });
    
    if (verification) {
      verification.documents.push(...documents);
      verification.status = 'pending';
      await verification.save();
    } else {
      verification = await StudentVerification.create({
        userId,
        documents,
        status: 'pending',
        verificationLevel: 'limited'
      });
    }

    res.json({ success: true, verification });
  } catch (e) {
    console.error('Upload error:', e);
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── STUDENT: Get my verification status ─────────────────────────────────────
router.get('/my-status', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const verification = await StudentVerification.findOne({ userId: toId(req.user.id) }).lean();
    
    if (!verification) {
      return res.json({ 
        success: true, 
        verification: { 
          status: 'not_submitted', 
          verificationLevel: 'limited' 
        } 
      });
    }

    res.json({ success: true, verification });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── ADMIN: Get all pending verifications ────────────────────────────────────
router.get('/pending', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    
    // Check if user is admin
    const user = await User.findById(toId(req.user.id)).lean();
    if ((user.role || '').toLowerCase() !== 'admin') {
      return res.status(403).json({ success: false, message: 'Admin access required' });
    }

    const verifications = await StudentVerification.find({ status: 'pending' })
      .populate('userId', 'name username email')
      .sort({ createdAt: -1 })
      .lean();

    res.json({ success: true, verifications, count: verifications.length });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── ADMIN: Approve verification ─────────────────────────────────────────────
router.post('/:id/approve', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    
    const user = await User.findById(toId(req.user.id)).lean();
    if ((user.role || '').toLowerCase() !== 'admin') {
      return res.status(403).json({ success: false, message: 'Admin access required' });
    }

    const verification = await StudentVerification.findById(toId(req.params.id));
    if (!verification) {
      return res.status(404).json({ success: false, message: 'Verification not found' });
    }

    verification.status = 'approved';
    verification.verificationLevel = 'full';
    verification.reviewedBy = toId(req.user.id);
    verification.reviewedAt = new Date();
    await verification.save();

    // TODO: Send email notification to student

    res.json({ success: true, verification });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── ADMIN: Reject verification ──────────────────────────────────────────────
router.post('/:id/reject', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    
    const user = await User.findById(toId(req.user.id)).lean();
    if ((user.role || '').toLowerCase() !== 'admin') {
      return res.status(403).json({ success: false, message: 'Admin access required' });
    }

    const { reason } = req.body;
    const verification = await StudentVerification.findById(toId(req.params.id));
    
    if (!verification) {
      return res.status(404).json({ success: false, message: 'Verification not found' });
    }

    verification.status = 'rejected';
    verification.rejectionReason = reason || 'Documents not valid';
    verification.reviewedBy = toId(req.user.id);
    verification.reviewedAt = new Date();
    await verification.save();

    // TODO: Send email notification to student

    res.json({ success: true, verification });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── ADMIN: Get all verifications (with filters) ─────────────────────────────
router.get('/all', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    
    const user = await User.findById(toId(req.user.id)).lean();
    if ((user.role || '').toLowerCase() !== 'admin') {
      return res.status(403).json({ success: false, message: 'Admin access required' });
    }

    const filter = {};
    if (req.query.status) filter.status = req.query.status;

    const verifications = await StudentVerification.find(filter)
      .populate('userId', 'name username email')
      .populate('reviewedBy', 'name username')
      .sort({ createdAt: -1 })
      .lean();

    res.json({ success: true, verifications, count: verifications.length });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;
