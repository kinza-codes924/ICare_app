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

// Notify everyone connected to a course's discussion about a new post or
// comment, except the person who wrote it. Recipients = the course
// instructor + accepted co-teachers + every enrolled student. Best-effort:
// a failure here must never block the post/comment itself, so callers wrap
// this in try/catch and ignore errors.
async function notifyCourseParticipants({ courseId, actorId, title, message, data }) {
  const Enrollment = require('../models/Enrollment');
  const Course = require('../models/Course');
  const Notification = require('../models/Notification');

  const course = await Course.findById(courseId).select('instructor_id coTeachers').lean();
  const recipientIds = new Set();
  if (course?.instructor_id) recipientIds.add(course.instructor_id.toString());
  for (const t of (course?.coTeachers || [])) {
    if (t.userId && (t.status ?? 'accepted') === 'accepted') {
      recipientIds.add(t.userId.toString());
    }
  }
  const enrollments = await Enrollment.find({ courseId }).select('userId').lean();
  for (const e of enrollments) {
    if (e.userId) recipientIds.add(e.userId.toString());
  }
  recipientIds.delete(actorId?.toString());

  if (!recipientIds.size) return;
  await Notification.insertMany([...recipientIds].map(uid => ({
    userId: uid,
    type: 'general',
    title,
    message,
    data,
  })));
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

    // Repair author names on posts saved before the POST route stopped
    // trusting req.user.name (absent from the JWT, so it fell through to the
    // literal 'Instructor' for everyone). Those rows stored the right
    // authorRole but the wrong name, which showed a student's own post as
    // the instructor's. Resolved from the User document at read time so old
    // posts display correctly without a migration.
    const stale = posts.filter(p => p.authorName === 'Instructor' && p.authorId);
    if (stale.length) {
      const users = await User.find({ _id: { $in: stale.map(p => p.authorId) } })
        .select('name username').lean();
      const nameById = new Map(users.map(u => [u._id.toString(), u.name || u.username]));
      for (const p of stale) {
        const real = nameById.get(p.authorId.toString());
        if (real) p.authorName = real;
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
    // Look the name up rather than trusting req.user.name: the JWT payload
    // does not carry it, so this fell through to 'Instructor' for everyone —
    // which mislabelled every student post as the instructor's now that
    // students can post here. The comment route below already reads the User
    // document for exactly this reason.
    const userDoc = await User.findById(req.user.id).select('name username role').lean();
    const roleStr = (userDoc?.role || req.user.role || '').toLowerCase();
    const authorName = userDoc?.name || userDoc?.username || 'User';
    const post = await Announcement.create({
      courseId, content, attachmentUrl, attachmentName,
      authorId:   req.user.id,
      authorName,
      authorRole: roleStr === 'instructor' || roleStr === 'doctor' ? 'instructor' : 'student',
    });

    // Tell the rest of the course a new post is up. Best-effort — never let
    // a notification failure fail the post itself.
    try {
      await notifyCourseParticipants({
        courseId,
        actorId: req.user.id,
        title: `${authorName} posted in the discussion`,
        message: content.length > 120 ? `${content.slice(0, 120)}…` : content,
        data: { type: 'announcement', courseId: courseId.toString(), postId: post._id.toString() },
      });
    } catch (e) { console.error('announcement notify failed:', e.message); }

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

    // Notify the course about the new comment. Best-effort.
    try {
      await notifyCourseParticipants({
        courseId: post.courseId,
        actorId: req.user.id,
        title: `${authorName} commented in the discussion`,
        message: text.length > 120 ? `${String(text).slice(0, 120)}…` : String(text).trim(),
        data: { type: 'announcement', courseId: post.courseId.toString(), postId: post._id.toString() },
      });
    } catch (e) { console.error('comment notify failed:', e.message); }

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

// ── Edit a comment ────────────────────────────────────────────────────────────
// Author only. Same ownership rule as editing a post.
router.put('/:postId/comment/:commentId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const text = req.body.text ?? req.body.comment;
    if (!text || !String(text).trim()) {
      return res.status(400).json({ success: false, message: 'Comment text is required' });
    }
    const post = await Announcement.findById(toId(req.params.postId));
    if (!post) return res.status(404).json({ success: false, message: 'Post not found' });
    const comment = post.comments.id(toId(req.params.commentId));
    if (!comment) return res.status(404).json({ success: false, message: 'Comment not found' });
    if (comment.authorId?.toString() !== req.user.id?.toString()) {
      return res.status(403).json({ success: false, message: 'You can only edit your own comment' });
    }
    comment.text = String(text).trim();
    await post.save();
    res.json({ success: true, post });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── Delete a comment ──────────────────────────────────────────────────────────
// The comment's author, or the course instructor (so they can moderate).
router.delete('/:postId/comment/:commentId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const post = await Announcement.findById(toId(req.params.postId));
    if (!post) return res.status(404).json({ success: false, message: 'Post not found' });
    const comment = post.comments.id(toId(req.params.commentId));
    if (!comment) return res.status(404).json({ success: false, message: 'Comment not found' });

    const isAuthor = comment.authorId?.toString() === req.user.id?.toString();
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
      return res.status(403).json({ success: false, message: 'Not allowed to delete this comment' });
    }

    post.comments.pull({ _id: toId(req.params.commentId) });
    await post.save();
    res.json({ success: true, post });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;
