const express = require('express');
const router = express.Router();
const FAQ = require('../models/FAQ');
const { authMiddleware, platformAdminOnly } = require('../middleware/auth');

// Platform-wide admin only — a clinic-scoped admin is rejected even with a
// matching role; see middleware/auth.js's platformAdminOnly.
const adminOnly = platformAdminOnly;

// GET /api/faqs — public list (optionally filtered by accountType)
router.get('/', async (req, res) => {
  try {
    const filter = { isActive: true };
    if (req.query.accountType) filter.accountType = req.query.accountType;
    const faqs = await FAQ.find(filter).sort({ accountType: 1, order: 1, createdAt: 1 }).lean();
    res.json({ success: true, faqs });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// GET /api/faqs/all — admin: all FAQs including inactive
router.get('/all', authMiddleware, adminOnly, async (req, res) => {
  try {
    const faqs = await FAQ.find({}).sort({ accountType: 1, order: 1, createdAt: 1 }).lean();
    res.json({ success: true, faqs });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// POST /api/faqs — admin create
router.post('/', authMiddleware, adminOnly, async (req, res) => {
  try {
    const { question, answer, accountType, order } = req.body;
    if (!question?.trim() || !answer?.trim()) {
      return res.status(400).json({ success: false, message: 'Question and answer are required' });
    }
    const faq = await FAQ.create({
      question: question.trim(),
      answer: answer.trim(),
      accountType: accountType || 'general',
      order: order || 0,
      createdBy: req.user.id,
    });
    res.json({ success: true, faq });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// PUT /api/faqs/:id — admin update
router.put('/:id', authMiddleware, adminOnly, async (req, res) => {
  try {
    const { question, answer, accountType, order, isActive } = req.body;
    const faq = await FAQ.findByIdAndUpdate(
      req.params.id,
      { question, answer, accountType, order, isActive },
      { new: true, runValidators: true }
    );
    if (!faq) return res.status(404).json({ success: false, message: 'FAQ not found' });
    res.json({ success: true, faq });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// DELETE /api/faqs/:id — admin delete
router.delete('/:id', authMiddleware, adminOnly, async (req, res) => {
  try {
    await FAQ.findByIdAndDelete(req.params.id);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;
