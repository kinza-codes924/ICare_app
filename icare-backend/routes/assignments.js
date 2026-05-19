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
    const { courseId, title, description, dueDate, totalMarks } = req.body;
    if (!courseId || !title) return res.status(400).json({ success: false, message: 'courseId and title required' });
    const a = await Assignment.create({
      courseId, title, description, dueDate, totalMarks: totalMarks || 100,
      instructorId: req.user.id,
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
    res.json({ success: true, assignments });
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
    // Rubric-based grading
    if (rubricGrade) sub.rubricGrade = rubricGrade;
    if (stars !== undefined) sub.stars = Number(stars);
    if (comments) sub.comments = comments;
    await sub.save();
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
