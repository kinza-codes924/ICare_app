const express = require('express');
const router  = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const { authMiddleware }  = require('../middleware/auth');
const Announcement = require('../models/Announcement');
const User = require('../models/User');

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

// ── Get stream (announcements) for a course ───────────────────────────────────
router.get('/course/:courseId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const posts = await Announcement.find({ courseId: toId(req.params.courseId) })
      .sort({ createdAt: -1 }).lean();
    res.json({ success: true, posts });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── Post to stream ────────────────────────────────────────────────────────────
router.post('/', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { courseId, content, attachmentUrl, attachmentName } = req.body;
    if (!courseId || !content) return res.status(400).json({ success: false, message: 'courseId and content required' });
    const post = await Announcement.create({
      courseId, content, attachmentUrl, attachmentName,
      authorId:   req.user.id,
      authorName: req.user.name || 'Instructor',
      authorRole: req.user.role?.toLowerCase() === 'instructor' || req.user.role?.toLowerCase() === 'doctor' ? 'instructor' : 'student',
    });
    res.json({ success: true, post });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── Add comment to a post ─────────────────────────────────────────────────────
router.post('/:postId/comment', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { text } = req.body;
    const post = await Announcement.findById(toId(req.params.postId));
    if (!post) return res.status(404).json({ success: false, message: 'Post not found' });
    const userDoc = await User.findById(req.user.id).select('name username').lean();
    const authorName = userDoc?.name || userDoc?.username || 'User';
    post.comments.push({ authorId: req.user.id, authorName, text });
    await post.save();
    res.json({ success: true, post });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── Edit a post ───────────────────────────────────────────────────────────────
router.put('/:postId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { content } = req.body;
    const post = await Announcement.findByIdAndUpdate(
      toId(req.params.postId),
      { content },
      { new: true }
    );
    if (!post) return res.status(404).json({ success: false, message: 'Post not found' });
    res.json({ success: true, post });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── Delete a post ─────────────────────────────────────────────────────────────
router.delete('/:postId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    await Announcement.findByIdAndDelete(toId(req.params.postId));
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;
