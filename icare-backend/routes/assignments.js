const express = require('express');
const router  = express.Router();
const mongoose = require('mongoose');
const multer   = require('multer');
const { v2: cloudinary } = require('cloudinary');
const { connectMongoDB }  = require('../config/mongodb');
const { authMiddleware }  = require('../middleware/auth');
const Assignment           = require('../models/Assignment');
const AssignmentSubmission = require('../models/AssignmentSubmission');
const Enrollment           = require('../models/Enrollment');
const User                 = require('../models/User');

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 20 * 1024 * 1024 } });

function uploadBuffer(buffer, folder) {
  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      { folder, resource_type: 'auto' },
      (err, result) => err ? reject(err) : resolve(result)
    );
    stream.end(buffer);
  });
}

// ── INSTRUCTOR: create assignment ────────────────────────────────────────────
router.post('/', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { courseId, title, description, dueDate, totalMarks, passingMarks } = req.body;
    if (!courseId || !title) return res.status(400).json({ success: false, message: 'courseId and title required' });
    const a = await Assignment.create({
      courseId, title, description, dueDate,
      totalMarks: totalMarks || 100,
      passingMarks: passingMarks || 50,
      instructorId: req.user.id,
    });

    // Notify all enrolled students about the new assignment (non-blocking)
    const Course = require('../models/Course');
    const Notification = require('../models/Notification');
    Promise.resolve().then(async () => {
      try {
        const course = await Course.findById(toId(courseId)).lean();
        const enrollments = await Enrollment.find({ courseId: toId(courseId) }).lean();
        if (course && enrollments.length > 0) {
          const dueDateStr = dueDate ? new Date(dueDate).toLocaleDateString('en-PK') : 'No deadline';
          const notifs = enrollments.map(e => ({
            userId: e.userId,
            type: 'general',
            title: `New Assignment: ${title}`,
            message: `A new assignment has been posted in "${course.title}". Due: ${dueDateStr}`,
            data: { type: 'assignment', assignmentId: a._id.toString(), courseId },
          }));
          await Notification.insertMany(notifs);
        }
      } catch (_) {}
    });

    res.json({ success: true, assignment: a });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── Get assignments for a course ─────────────────────────────────────────────
router.get('/course/:courseId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const assignments = await Assignment.find({
      courseId: toId(req.params.courseId), isPublished: true,
    }).sort({ createdAt: -1 }).lean();

    // Attach submission count to each assignment
    const assignmentIds = assignments.map(a => a._id);
    const counts = await AssignmentSubmission.aggregate([
      { $match: { assignmentId: { $in: assignmentIds } } },
      { $group: { _id: '$assignmentId', count: { $sum: 1 } } },
    ]);
    const countMap = {};
    counts.forEach(c => { countMap[c._id.toString()] = c.count; });
    const result = assignments.map(a => ({
      ...a,
      submissionCount: countMap[a._id.toString()] || 0,
    }));

    res.json({ success: true, assignments: result });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── STUDENT: get all my assignments across enrolled courses ──────────────────
router.get('/my', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const studentId = toId(req.user.id);
    const enrollments = await Enrollment.find({ userId: studentId }).lean();
    const courseIds = enrollments.map(e => e.courseId);
    if (courseIds.length === 0) return res.json({ success: true, assignments: [] });

    const assignments = await Assignment.find({
      courseId: { $in: courseIds }, isPublished: true,
    }).sort({ dueDate: 1, createdAt: -1 }).lean();

    const assignmentIds = assignments.map(a => a._id);
    const submissions = await AssignmentSubmission.find({
      assignmentId: { $in: assignmentIds }, studentId,
    }).lean();
    const subMap = {};
    submissions.forEach(s => { subMap[s.assignmentId.toString()] = s; });

    const Course = require('../models/Course');
    const courses = await Course.find({ _id: { $in: courseIds } }, 'title').lean();
    const courseMap = {};
    courses.forEach(c => { courseMap[c._id.toString()] = c.title; });

    const result = assignments.map(a => ({
      ...a,
      submission: subMap[a._id.toString()] || null,
      courseName: courseMap[a.courseId?.toString()] || '',
    }));

    res.json({ success: true, assignments: result });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── INSTRUCTOR: get all submissions for an assignment ────────────────────────
router.get('/:assignmentId/submissions', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const subs = await AssignmentSubmission.find({ assignmentId: toId(req.params.assignmentId) })
      .populate('studentId', 'name username email').sort({ submittedAt: -1 }).lean();
    res.json({ success: true, submissions: subs });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── STUDENT: submit assignment (with optional file upload) ───────────────────
router.post('/:assignmentId/submit', authMiddleware, upload.single('file'), async (req, res) => {
  try {
    await connectMongoDB();
    const { content } = req.body;
    const assignmentId = toId(req.params.assignmentId);
    const studentId    = toId(req.user.id);
    if (!assignmentId) return res.status(400).json({ success: false, message: 'Invalid assignment ID' });

    const assignment = await Assignment.findById(assignmentId).lean();
    if (!assignment) return res.status(404).json({ success: false, message: 'Assignment not found' });

    let fileUrl = null, fileName = null;
    if (req.file) {
      const result = await uploadBuffer(req.file.buffer, 'icare/lms/submissions');
      fileUrl  = result.secure_url;
      fileName = req.file.originalname;
    }

    const status = assignment.dueDate && new Date() > new Date(assignment.dueDate) ? 'late' : 'submitted';

    const existing = await AssignmentSubmission.findOne({ assignmentId, studentId });
    let submission;
    if (existing) {
      existing.content = content || existing.content;
      if (fileUrl) { existing.fileUrl = fileUrl; existing.fileName = fileName; }
      existing.status = status;
      existing.submittedAt = new Date();
      await existing.save();
      submission = existing;
    } else {
      submission = await AssignmentSubmission.create({
        assignmentId, courseId: assignment.courseId, studentId,
        content: content || '', fileUrl, fileName, status,
      });
    }

    res.json({ success: true, submission });
  } catch (e) {
    if (e.code === 11000) return res.status(400).json({ success: false, message: 'Already submitted' });
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── INSTRUCTOR: grade a submission ───────────────────────────────────────────
router.put('/submissions/:submissionId/grade', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { marksObtained, feedback, rubricGrade, stars, comments } = req.body;
    if (marksObtained === undefined) return res.status(400).json({ success: false, message: 'marksObtained required' });
    const sub = await AssignmentSubmission.findById(toId(req.params.submissionId));
    if (!sub) return res.status(404).json({ success: false, message: 'Submission not found' });
    sub.marksObtained = Number(marksObtained);
    sub.feedback  = feedback || '';
    sub.status    = 'graded';
    sub.gradedAt  = new Date();
    sub.gradedBy  = toId(req.user.id);
    if (rubricGrade) sub.rubricGrade = rubricGrade;
    if (stars !== undefined) sub.stars = Number(stars);
    if (comments) sub.comments = comments;
    await sub.save();

    // Course completion sync: check if all published assignments are graded (non-blocking)
    const Notification = require('../models/Notification');
    Promise.resolve().then(async () => {
      try {
        const allAssignments = await Assignment.find({ courseId: sub.courseId, isPublished: true }).lean();
        if (allAssignments.length === 0) return;
        const allIds = allAssignments.map(a => a._id);
        const gradedSubs = await AssignmentSubmission.find({
          studentId: sub.studentId,
          assignmentId: { $in: allIds },
          status: 'graded',
        }).lean();
        if (gradedSubs.length < allAssignments.length) return;

        // Check passing: all assignments must meet passingMarks
        const assignmentMap = {};
        allAssignments.forEach(a => { assignmentMap[a._id.toString()] = a; });
        const allPassed = gradedSubs.every(s => {
          const a = assignmentMap[s.assignmentId.toString()];
          return a ? s.marksObtained >= (a.passingMarks || 50) : false;
        });

        // Mark enrollment completed (both top-level and progress.completed for compatibility)
        await Enrollment.findOneAndUpdate(
          { courseId: sub.courseId, userId: sub.studentId },
          { $set: { completedAt: new Date(), isCompleted: true,
                    'progress.completed': true, 'progress.completedAt': new Date() } },
        );

        // Notify student
        const Course = require('../models/Course');
        const course = await Course.findById(toId(sub.courseId.toString())).lean();
        await Notification.create({
          userId: sub.studentId,
          type: 'general',
          title: allPassed ? 'Course Completed!' : 'All Assignments Graded',
          message: allPassed
            ? `Congratulations! You've completed "${course?.title || 'the course'}". Your certificate is ready.`
            : `All assignments graded for "${course?.title || 'the course'}". Check your scores.`,
          data: { type: 'course_complete', courseId: sub.courseId.toString() },
        });
      } catch (_) {}
    });

    res.json({ success: true, submission: sub });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── STUDENT: my submission for an assignment ─────────────────────────────────
router.get('/:assignmentId/my-submission', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const sub = await AssignmentSubmission.findOne({
      assignmentId: toId(req.params.assignmentId),
      studentId:    toId(req.user.id),
    }).lean();
    res.json({ success: true, submission: sub });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── STUDENT: my grades across all enrolled courses ───────────────────────────
router.get('/my-grades', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const studentId = toId(req.user.id);
    const subs = await AssignmentSubmission.find({ studentId, status: 'graded' })
      .populate('assignmentId', 'title totalMarks courseId').sort({ gradedAt: -1 }).lean();
    res.json({ success: true, grades: subs });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── STUDENT: grades for a specific course ────────────────────────────────────
router.get('/course/:courseId/my-grades', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const studentId = toId(req.user.id);
    const courseId  = toId(req.params.courseId);
    const assignments = await Assignment.find({ courseId, isPublished: true }).lean();
    const assignmentIds = assignments.map(a => a._id);
    const subs = await AssignmentSubmission.find({ studentId, assignmentId: { $in: assignmentIds } }).lean();
    const subMap = {};
    subs.forEach(s => { subMap[s.assignmentId.toString()] = s; });
    const grades = assignments.map(a => ({
      assignment: { _id: a._id, title: a.title, totalMarks: a.totalMarks, dueDate: a.dueDate },
      submission: subMap[a._id.toString()] || null,
    }));
    res.json({ success: true, grades });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;
