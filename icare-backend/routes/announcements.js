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
    // Drop comments with no text. Until the key mismatch below was fixed
    // (client sent 'comment', the route read 'text') every comment saved
    // with text undefined, so those rows still exist and would otherwise
    // keep rendering as a bare author name above an empty line.
    for (const p of posts) {
      if (Array.isArray(p.comments)) {
        p.comments = p.comments.filter(c => c?.text && String(c.text).trim());
      }
    }
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
    // The Flutter client posts this as 'comment' (lms_service.addComment)
    // while this route only ever read 'text', so every comment was stored
    // with text undefined — the feed then rendered the author's name above
    // an empty line. Accept either key so old and new clients both work.
    const text = req.body.text ?? req.body.comment;
    if (!text || !String(text).trim()) {
      return res.status(400).json({ success: false, message: 'Comment text is required' });
    }
    const post = await Announcement.findById(toId(req.params.postId));
    if (!post) return res.status(404).json({ success: false, message: 'Post not found' });
    const userDoc = await User.findById(req.user.id).select('name username').lean();
    const authorName = userDoc?.name || userDoc?.username || 'User';
    post.comments.push({ authorId: req.user.id, authorName, text: String(text).trim() });
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
    // Ownership is enforced here, not in the client. This updated by id
    // alone, so any authenticated user could rewrite anyone's post — moot
    // while only instructors saw the menu, but the tab is now a two-way
    // discussion and students can post.
    const post = await Announcement.findById(toId(req.params.postId));
    if (!post) return res.status(404).json({ success: false, message: 'Post not found' });
    if (post.authorId?.toString() !== req.user.id?.toString()) {
      return res.status(403).json({ success: false, message: 'You can only edit your own post' });
    }
    post.content = content;
    await post.save();
    res.json({ success: true, post });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── Delete a post ─────────────────────────────────────────────────────────────
router.delete('/:postId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    // Same reasoning as the edit route: this deleted by id with no check, so
    // any authenticated user could remove any post. The author may delete
    // their own; the course's instructor may delete any of them, so they can
    // still moderate the discussion.
    const post = await Announcement.findById(toId(req.params.postId));
    if (!post) return res.status(404).json({ success: false, message: 'Post not found' });

    const isAuthor = post.authorId?.toString() === req.user.id?.toString();
    let isCourseInstructor = false;
    if (!isAuthor) {
      const Course = require('../models/Course');
      const course = await Course.findById(post.courseId).select('instructor_id coTeachers').lean();
      const uid = req.user.id?.toString();
      isCourseInstructor = course?.instructor_id?.toString() === uid
        || (course?.coTeachers || []).some(t =>
             t.userId?.toString() === uid && (t.status ?? 'accepted') === 'accepted');
    }
    if (!isAuthor && !isCourseInstructor) {
      return res.status(403).json({ success: false, message: 'Not allowed to delete this post' });
    }

    await Announcement.findByIdAndDelete(toId(req.params.postId));
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;
