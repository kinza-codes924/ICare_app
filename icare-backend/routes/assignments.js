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
    const { courseId, title, description, instructions, submissionType, dueDate, totalMarks, passingMarks, attachmentUrl, attachmentName } = req.body;
    if (!courseId || !title) return res.status(400).json({ success: false, message: 'courseId and title required' });
    const a = await Assignment.create({
      courseId, title, description, instructions: instructions || '', submissionType: submissionType || 'file',
      dueDate,
      totalMarks: totalMarks || 100,
      passingMarks: passingMarks || 50,
      instructorId: req.user.id,
      ...(attachmentUrl && { attachmentUrl }),
      ...(attachmentName && { attachmentName }),
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

    // Attach submission + graded counts to each assignment (so the
    // instructor "To Review" list can compute pending = submitted - graded)
    const assignmentIds = assignments.map(a => a._id);
    const counts = await AssignmentSubmission.aggregate([
      { $match: { assignmentId: { $in: assignmentIds } } },
      { $group: { _id: '$assignmentId', count: { $sum: 1 } } },
    ]);
    const gradedCounts = await AssignmentSubmission.aggregate([
      { $match: { assignmentId: { $in: assignmentIds }, status: 'graded' } },
      { $group: { _id: '$assignmentId', count: { $sum: 1 } } },
    ]);
    const countMap = {};
    counts.forEach(c => { countMap[c._id.toString()] = c.count; });
    const gradedMap = {};
    gradedCounts.forEach(c => { gradedMap[c._id.toString()] = c.count; });
    const result = assignments.map(a => ({
      ...a,
      submissionCount: countMap[a._id.toString()] || 0,
      gradedCount: gradedMap[a._id.toString()] || 0,
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
      // Multipart upload directly to this endpoint
      const result = await uploadBuffer(req.file.buffer, 'icare/lms/submissions');
      fileUrl  = result.secure_url;
      fileName = req.file.originalname;
    } else if (req.body.fileUrl) {
      // File was already uploaded client-side (e.g. via /upload/blob-doc)
      // and only the resulting URL is sent here as JSON.
      fileUrl  = req.body.fileUrl;
      fileName = req.body.fileName || null;
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

    // ── Feature 7: Submission notifications ─────────────────────────────────
    Promise.resolve().then(async () => {
      try {
        const Notification = require('../models/Notification');
        const Course = require('../models/Course');
        const course = await Course.findById(toId(assignment.courseId.toString())).lean();
        const student = await User.findById(studentId).lean();
        const instructor = await User.findById(toId(assignment.instructorId.toString())).lean();

        const dueDateStr = assignment.dueDate
          ? new Date(assignment.dueDate).toLocaleDateString('en-PK')
          : 'No deadline';
        const isLate = status === 'late';

        // In-app + email to student
        await Notification.create({
          userId: studentId,
          type: 'general',
          title: isLate ? 'Assignment Submitted (Late)' : 'Assignment Submitted',
          message: `Your submission for "${assignment.title}" in "${course?.title || 'your course'}" has been received.${isLate ? ' Note: This was submitted after the due date.' : ''}`,
          data: { type: 'assignment_submitted', assignmentId: assignment._id.toString(), courseId: assignment.courseId.toString() },
        });

        // Email to student (uses Resend HTTP API — works on Vercel serverless)
        if (student?.email) {
          const { sendEmail } = require('../utils/email');
          sendEmail({
            to: student.email,
            subject: `Assignment Submitted: ${assignment.title}`,
            html: `<p>Hi ${student.name || 'Student'},</p>
                   <p>Your assignment <b>"${assignment.title}"</b> in the course <b>"${course?.title || ''}"</b> has been successfully submitted.</p>
                   ${isLate ? `<p style="color:orange;"><b>Note:</b> This submission was received after the due date (${dueDateStr}).</p>` : ''}
                   <p>Your instructor will review and grade it soon.</p>
                   <p>— iCare LMS Team</p>`,
          }).catch(() => {});
        }

        // In-app + email to instructor
        if (instructor) {
          await Notification.create({
            userId: toId(assignment.instructorId.toString()),
            type: 'general',
            title: 'New Assignment Submission',
            message: `${student?.name || 'A student'} submitted "${assignment.title}"${isLate ? ' (late)' : ''} in "${course?.title || 'your course'}"`,
            data: { type: 'assignment_submission_received', assignmentId: assignment._id.toString(), courseId: assignment.courseId.toString(), studentId: studentId.toString() },
          });

          if (instructor.email) {
            const { sendEmail } = require('../utils/email');
            sendEmail({
              to: instructor.email,
              subject: `New Submission: ${assignment.title}`,
              html: `<p>Hi ${instructor.name || 'Instructor'},</p>
                     <p><b>${student?.name || 'A student'}</b> submitted <b>"${assignment.title}"</b> in the course <b>"${course?.title || ''}"</b>${isLate ? ' (submitted after the due date)' : ''}.</p>
                     <p>Log in to iCare to review and grade it.</p>
                     <p>— iCare LMS Team</p>`,
            }).catch(() => {});
          }
        }
      } catch (_) {}
    });

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

        // Idempotency guard: this block re-runs on EVERY grading action once all
        // assignments happen to be graded (e.g. an instructor re-grading/editing a
        // mark later), not just the one action that first completes the course.
        // Without this check it would re-stamp completedAt and re-send the
        // "Course Completed!" notification on every subsequent regrade.
        const existingEnrollment = await Enrollment.findOne(
          { courseId: sub.courseId, userId: sub.studentId },
          { isCompleted: 1 },
        ).lean();
        if (existingEnrollment?.isCompleted) return;

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

// ── INSTRUCTOR: delete assignment ────────────────────────────────────────────
router.delete('/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const assignment = await Assignment.findById(toId(req.params.id));
    if (!assignment) return res.status(404).json({ success: false, message: 'Assignment not found' });
    if (assignment.instructorId.toString() !== req.user.id.toString() && req.user.role !== 'admin') {
      return res.status(403).json({ success: false, message: 'Not authorized' });
    }
    await Assignment.findByIdAndDelete(toId(req.params.id));
    await AssignmentSubmission.deleteMany({ assignmentId: toId(req.params.id) });
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── CRON: Send assignment due-date reminders ─────────────────────────────────
// Called daily by Vercel cron at 08:00 UTC (GET) or manually (POST)
// Sends: (1) reminder 5 days before due date  (2) reminder on due date
async function handleSendReminders(req, res) {
  // Allow cron secret or admin auth
  const cronSecret = req.headers['x-cron-secret'] || req.query.secret;
  if (cronSecret !== process.env.CRON_SECRET && process.env.CRON_SECRET) {
    return res.status(403).json({ success: false, message: 'Forbidden' });
  }
  try {
    await connectMongoDB();
    const Notification = require('../models/Notification');
    const Course = require('../models/Course');
    const { sendEmail } = require('../utils/email');

    const now = new Date();
    // Day boundaries
    const todayStart = new Date(now); todayStart.setHours(0, 0, 0, 0);
    const todayEnd   = new Date(now); todayEnd.setHours(23, 59, 59, 999);
    const in5Start   = new Date(todayStart); in5Start.setDate(in5Start.getDate() + 5);
    const in5End     = new Date(todayEnd);   in5End.setDate(in5End.getDate() + 5);

    // Assignments due today (not yet reminded on due date)
    const dueToday = await Assignment.find({
      isPublished: true,
      dueDate: { $gte: todayStart, $lte: todayEnd },
      reminderSentOnDue: { $ne: true },
    }).lean();

    // Assignments due in 5 days (not yet sent 5-day reminder)
    const dueIn5 = await Assignment.find({
      isPublished: true,
      dueDate: { $gte: in5Start, $lte: in5End },
      reminderSent5Days: { $ne: true },
    }).lean();

    let sent = 0;

    async function sendReminder(assignment, type) {
      const course = await Course.findById(toId(assignment.courseId.toString())).lean();
      const enrollments = await Enrollment.find({ courseId: toId(assignment.courseId.toString()) }).lean();
      if (!enrollments.length) return;

      const dueStr = new Date(assignment.dueDate).toLocaleDateString('en-PK', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' });
      const label  = type === 'today' ? 'Due TODAY' : 'Due in 5 days';

      const notifs = enrollments.map(e => ({
        userId: e.userId,
        type: 'general',
        title: `⏰ Assignment Reminder: ${label}`,
        message: `"${assignment.title}" in "${course?.title || 'your course'}" is ${label.toLowerCase()}. Due: ${dueStr}`,
        data: { type: 'assignment_reminder', assignmentId: assignment._id.toString(), courseId: assignment.courseId.toString() },
      }));
      await Notification.insertMany(notifs);

      // Email enrolled students (Resend HTTP API — works on Vercel serverless)
      try {
        const studentIds = enrollments.map(e => e.userId);
        const students = await User.find({ _id: { $in: studentIds }, email: { $exists: true, $ne: '' } }).select('email name').lean();
        for (const student of students) {
          sendEmail({
            to: student.email,
            subject: `Reminder: Assignment "${assignment.title}" is ${label}`,
            html: `<p>Hi ${student.name || 'Student'},</p>
                   <p>This is a reminder that your assignment <b>"${assignment.title}"</b> in <b>"${course?.title || ''}"</b> is <b>${label}</b>.</p>
                   <p><b>Due Date:</b> ${dueStr}</p>
                   <p>Please submit before the deadline.</p>
                   <p>— iCare LMS Team</p>`,
          }).catch(() => {});
        }
      } catch (_) {}

      // Mark reminder sent
      const flag = type === 'today' ? { reminderSentOnDue: true } : { reminderSent5Days: true };
      await Assignment.findByIdAndUpdate(assignment._id, { $set: flag });
      sent++;
    }

    for (const a of dueToday)  await sendReminder(a, 'today');
    for (const a of dueIn5)    await sendReminder(a, '5days');

    res.json({ success: true, message: `Reminders sent for ${sent} assignments`, dueToday: dueToday.length, dueIn5: dueIn5.length });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
}
router.get('/send-reminders', handleSendReminders);
router.post('/send-reminders', handleSendReminders);

// ── Get single assignment by ID ──────────────────────────────────────────────
router.get('/:assignmentId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const a = await Assignment.findById(req.params.assignmentId).lean();
    if (!a) return res.status(404).json({ success: false, message: 'Assignment not found' });
    res.json({ success: true, assignment: a });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── Update assignment ────────────────────────────────────────────────────────
router.put('/:assignmentId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { title, description, instructions, submissionType, dueDate, totalMarks, passingMarks, isPublished, attachmentUrl, attachmentName } = req.body;
    const update = {};
    if (title !== undefined)         update.title         = title;
    if (description !== undefined)   update.description   = description;
    if (instructions !== undefined)  update.instructions  = instructions;
    if (submissionType !== undefined) update.submissionType = submissionType;
    if (dueDate !== undefined)       update.dueDate       = dueDate;
    if (totalMarks !== undefined)    update.totalMarks    = totalMarks;
    if (passingMarks !== undefined)  update.passingMarks  = passingMarks;
    if (isPublished !== undefined)   update.isPublished   = isPublished;
    if (attachmentUrl !== undefined) update.attachmentUrl = attachmentUrl;
    if (attachmentName !== undefined) update.attachmentName = attachmentName;
    const a = await Assignment.findByIdAndUpdate(req.params.assignmentId, { $set: update }, { new: true, lean: true });
    if (!a) return res.status(404).json({ success: false, message: 'Assignment not found' });
    res.json({ success: true, assignment: a });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;
