const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const { authMiddleware } = require('../middleware/auth');
const Course = require('../models/Course');
const Enrollment = require('../models/Enrollment');

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

// GET /api/courses/public — list active courses WITHOUT auth (for browsing)
router.get('/public', async (req, res) => {
  try {
    await connectMongoDB();
    const filter = { is_active: true, isPublished: true };
    if (req.query.q) filter.title = { $regex: req.query.q, $options: 'i' };
    if (req.query.category) filter.category = req.query.category;
    const courses = await Course.find(filter).select('-modules').lean();
    res.json({ success: true, courses, count: courses.length });
  } catch (e) {
    res.json({ success: true, courses: [], count: 0 });
  }
});

// GET /api/courses/students — enrolled students in a course (instructor use)
router.get('/enrolled-students/:courseId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const enrollments = await Enrollment.find({ courseId: toId(req.params.courseId) })
      .populate('userId', 'name email username').lean();
    const students = enrollments.map(e => ({
      _id: e.userId?._id, name: e.userId?.name || e.userId?.username,
      email: e.userId?.email, progress: e.progress, enrolledAt: e.createdAt,
    }));
    res.json({ success: true, students });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// GET /api/courses or GET /api/students/courses — list active courses
router.get('/', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const filter = { is_active: true };
    if (req.query.instructorId) filter.instructor_id = toId(req.query.instructorId);
    if (req.query.visibility) filter.visibility = req.query.visibility;
    if (req.query.q) filter.title = { $regex: req.query.q, $options: 'i' };
    const courses = await Course.find(filter).lean();
    res.json({ success: true, courses, count: courses.length });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── ENROLLMENTS ────────────────────────────────────────────────────────────
// POST /enrollments — enroll logged-in user in a course
router.post('/enrollments', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { courseId } = req.body;
    if (!courseId) return res.status(400).json({ success: false, message: 'courseId required' });

    const cId = toId(courseId);
    if (!cId) return res.status(400).json({ success: false, message: 'Invalid courseId' });

    const course = await Course.findById(cId).lean();
    if (!course) return res.status(404).json({ success: false, message: 'Course not found' });

    const uId = toId(req.user.id);
    // Upsert: if already enrolled, just return existing
    const existing = await Enrollment.findOne({ userId: uId, courseId: cId }).lean();
    if (existing) {
      return res.json({ success: true, message: 'Already enrolled', enrollment: existing });
    }

    const enrollment = await Enrollment.create({ userId: uId, courseId: cId });
    res.status(201).json({ success: true, enrollment });
  } catch (e) {
    if (e.code === 11000) {
      // Duplicate key — already enrolled
      const existing = await Enrollment.findOne({ userId: toId(req.user.id), courseId: toId(req.body.courseId) }).lean();
      return res.json({ success: true, message: 'Already enrolled', enrollment: existing });
    }
    res.status(500).json({ success: false, message: e.message });
  }
});

// GET /enrollments/my — get logged-in user's enrollments with course data
router.get('/enrollments/my', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const uId = toId(req.user.id);
    const enrollments = await Enrollment.find({ userId: uId }).lean();
    // Populate course data
    const courseIds = enrollments.map(e => e.courseId);
    const courses = await Course.find({ _id: { $in: courseIds } }).lean();
    const courseMap = {};
    courses.forEach(c => { courseMap[c._id.toString()] = c; });
    const items = enrollments.map(e => ({
      ...e,
      course: courseMap[e.courseId.toString()] || null,
    }));
    res.json({ success: true, enrollments: items, items, count: items.length });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// PUT /enrollments/:id/progress — update lesson/quiz progress
router.put('/enrollments/:id/progress', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const update = {};
    if (req.body.completedVideos !== undefined) update['progress.completedVideos'] = req.body.completedVideos;
    if (req.body.completed !== undefined) {
      update['progress.completed'] = req.body.completed;
      if (req.body.completed) update['progress.completedAt'] = new Date();
    }
    if (req.body.quizResult) {
      const enrollment = await Enrollment.findByIdAndUpdate(
        toId(req.params.id),
        { $push: { 'progress.quizResults': req.body.quizResult }, $set: update },
        { new: true },
      );
      return res.json({ success: true, enrollment });
    }
    const enrollment = await Enrollment.findByIdAndUpdate(
      toId(req.params.id),
      { $set: update },
      { new: true },
    );
    if (!enrollment) return res.status(404).json({ success: false, message: 'Enrollment not found' });
    res.json({ success: true, enrollment });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// GET /certificates/my — get completed enrollments as certificates
router.get('/certificates/my', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const uId = toId(req.user.id);
    const enrollments = await Enrollment.find({ userId: uId, 'progress.completed': true }).lean();
    const courseIds = enrollments.map(e => e.courseId);
    const courses = await Course.find({ _id: { $in: courseIds } }).lean();
    const courseMap = {};
    courses.forEach(c => { courseMap[c._id.toString()] = c; });
    const certificates = enrollments.map(e => ({
      _id: e._id,
      completedAt: e.progress?.completedAt,
      course: courseMap[e.courseId.toString()] || null,
    }));
    res.json({ success: true, certificates, count: certificates.length });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// PUT /enrollments/:id/complete — mark enrollment as completed
router.put('/enrollments/:id/complete', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const enrollment = await Enrollment.findByIdAndUpdate(
      toId(req.params.id),
      { 'progress.completed': true, 'progress.completedAt': new Date() },
      { new: true }
    );
    if (!enrollment) return res.status(404).json({ success: false, message: 'Enrollment not found' });
    res.json({ success: true, enrollment });
  } catch (e) { res.status(500).json({ success: false, message: e.message }); }
});

// PUT /courses/:courseId/certificate/release — instructor releases certificate
router.put('/:courseId/certificate/release', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { released, template } = req.body;
    const update = { certificateReleased: released !== false };
    if (template) update.certificateTemplate = template;
    const course = await Course.findByIdAndUpdate(toId(req.params.courseId), update, { new: true });
    if (!course) return res.status(404).json({ success: false, message: 'Course not found' });
    res.json({ success: true, course, message: released !== false ? 'Certificate released to students' : 'Certificate revoked' });
  } catch (e) { res.status(500).json({ success: false, message: e.message }); }
});

// GET /api/courses/:id — get single course
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const course = await Course.findById(toId(req.params.id)).lean();
    if (!course) return res.status(404).json({ success: false, message: 'Course not found' });
    res.json({ success: true, course });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// POST /api/courses — create course (instructor)
router.post('/', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const course = await Course.create({ ...req.body, instructor_id: toId(req.user.id) });
    res.status(201).json({ success: true, course });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// PUT /api/courses/:id — update course
router.put('/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const course = await Course.findByIdAndUpdate(toId(req.params.id), { $set: req.body }, { new: true });
    if (!course) return res.status(404).json({ success: false, message: 'Not found' });
    res.json({ success: true, course });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// DELETE /api/courses/:id — soft delete
router.delete('/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    await Course.findByIdAndUpdate(toId(req.params.id), { is_active: false });
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// POST /enrollments/:id/complete-module — mark module as complete
router.post('/enrollments/:id/complete-module', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { moduleId } = req.body;
    if (!moduleId) return res.status(400).json({ success: false, message: 'moduleId required' });

    const enrollment = await Enrollment.findById(toId(req.params.id));
    if (!enrollment) return res.status(404).json({ success: false, message: 'Enrollment not found' });

    // Check if already completed
    const existing = enrollment.moduleCompletions.find(mc => mc.moduleId === moduleId);
    if (existing) {
      return res.json({ success: true, message: 'Module already completed', enrollment });
    }

    // Add completion
    enrollment.moduleCompletions.push({ moduleId, completedAt: new Date() });
    await enrollment.save();

    // Send notification to instructor (non-blocking)
    try {
      const Notification = require('../models/Notification');
      const User = require('../models/User');
      const course = await Course.findById(enrollment.courseId).lean();
      const student = await User.findById(enrollment.userId).lean();
      if (course?.instructor_id && student) {
        await Notification.create({
          userId: course.instructor_id,
          type: 'general',
          title: 'Module Completed',
          message: `${student.name || student.username} completed a module in ${course.title}`,
          data: { studentId: enrollment.userId, moduleId, courseId: course._id },
        });
      }
    } catch (_) { /* notification failure should not break the response */ }

    res.json({ success: true, enrollment });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// POST /courses/:id/invite-teacher — invite co-teacher by email
router.post('/:id/invite-teacher', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { email } = req.body;
    if (!email) return res.status(400).json({ success: false, message: 'Email required' });

    const course = await Course.findById(toId(req.params.id)).lean();
    if (!course) return res.status(404).json({ success: false, message: 'Course not found' });

    const User = require('../models/User');
    const invitedUser = await User.findOne({ email: email.toLowerCase().trim() }).lean();

    if (!invitedUser) {
      return res.status(404).json({ success: false, message: `No user found with email: ${email}. They must register on iCare first.` });
    }

    // Add as co-teacher if not already
    const alreadyTeacher = course.coTeachers?.some(t => t.toString() === invitedUser._id.toString());
    if (alreadyTeacher) {
      return res.json({ success: true, message: 'This teacher is already in the course.' });
    }

    await Course.findByIdAndUpdate(toId(req.params.id), {
      $addToSet: { coTeachers: invitedUser._id }
    });

    // Send notification to invited teacher
    const Notification = require('../models/Notification');
    const inviter = await User.findById(req.user.id).lean();
    await Notification.create({
      userId: invitedUser._id,
      type: 'general',
      title: 'Co-Teacher Invitation',
      message: `${inviter?.name || 'An instructor'} has invited you to co-teach "${course.title}"`,
      data: { courseId: course._id, courseName: course.title },
    }).catch(() => {});

    res.json({ success: true, message: `Invitation sent to ${invitedUser.name || email}` });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;
