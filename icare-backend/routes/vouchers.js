const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const auth = require('../middleware/auth');

// ─── Schema ───────────────────────────────────────────────────────────────────
const voucherSchema = new mongoose.Schema({
  code:           { type: String, required: true, unique: true, uppercase: true, trim: true },
  instructorId:   { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  discount:       { type: Number, required: true, min: 1, max: 100 }, // percent
  courseId:       { type: mongoose.Schema.Types.ObjectId, ref: 'Course', default: null }, // null = any course
  usedBy:         { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
  usedAt:         { type: Date, default: null },
  expiresAt:      { type: Date, default: null },
  createdAt:      { type: Date, default: Date.now },
});

const Voucher = mongoose.models.Voucher || mongoose.model('Voucher', voucherSchema);

// ─── GET /api/vouchers — instructor: list own vouchers ────────────────────────
router.get('/', auth, async (req, res) => {
  try {
    const vouchers = await Voucher.find({ instructorId: req.user._id })
      .sort({ createdAt: -1 })
      .lean();
    res.json({ success: true, vouchers });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── POST /api/vouchers — instructor creates a voucher ────────────────────────
router.post('/', auth, async (req, res) => {
  try {
    const { code, discount, courseId, expiresAt } = req.body;
    if (!code || !discount) return res.status(400).json({ success: false, message: 'code and discount are required' });

    const voucher = await Voucher.create({
      code: code.trim().toUpperCase(),
      instructorId: req.user._id,
      discount: Number(discount),
      courseId: courseId || null,
      expiresAt: expiresAt ? new Date(expiresAt) : null,
    });
    res.json({ success: true, voucher });
  } catch (err) {
    if (err.code === 11000) return res.status(409).json({ success: false, message: 'Voucher code already exists' });
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── DELETE /api/vouchers/:id — instructor deletes own unused voucher ─────────
router.delete('/:id', auth, async (req, res) => {
  try {
    const v = await Voucher.findOne({ _id: req.params.id, instructorId: req.user._id });
    if (!v) return res.status(404).json({ success: false, message: 'Not found' });
    if (v.usedBy) return res.status(400).json({ success: false, message: 'Cannot delete a used voucher' });
    await v.deleteOne();
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── POST /api/vouchers/validate — student validates a code before checkout ───
router.post('/validate', auth, async (req, res) => {
  try {
    const { code, courseId } = req.body;
    if (!code) return res.status(400).json({ success: false, message: 'code required' });

    const voucher = await Voucher.findOne({ code: code.trim().toUpperCase() });
    if (!voucher) return res.status(404).json({ success: false, message: 'Invalid voucher code' });
    if (voucher.usedBy) return res.status(400).json({ success: false, message: 'This voucher has already been used' });
    if (voucher.expiresAt && new Date() > voucher.expiresAt) return res.status(400).json({ success: false, message: 'Voucher has expired' });
    if (voucher.courseId && courseId && voucher.courseId.toString() !== courseId.toString()) {
      return res.status(400).json({ success: false, message: 'Voucher is not valid for this course' });
    }

    res.json({ success: true, discount: voucher.discount, voucherId: voucher._id });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── POST /api/vouchers/redeem — mark voucher as used on enrollment ───────────
router.post('/redeem', auth, async (req, res) => {
  try {
    const { code, courseId } = req.body;
    if (!code) return res.status(400).json({ success: false, message: 'code required' });

    const voucher = await Voucher.findOne({ code: code.trim().toUpperCase() });
    if (!voucher) return res.status(404).json({ success: false, message: 'Invalid voucher code' });
    if (voucher.usedBy) return res.status(400).json({ success: false, message: 'Voucher already used' });
    if (voucher.expiresAt && new Date() > voucher.expiresAt) return res.status(400).json({ success: false, message: 'Voucher expired' });
    if (voucher.courseId && courseId && voucher.courseId.toString() !== courseId.toString()) {
      return res.status(400).json({ success: false, message: 'Voucher not valid for this course' });
    }

    voucher.usedBy = req.user._id;
    voucher.usedAt = new Date();
    await voucher.save();

    res.json({ success: true, discount: voucher.discount });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
