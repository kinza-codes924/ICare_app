const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { connectMongoDB } = require('../config/mongodb');
const { authMiddleware } = require('../middleware/auth');
const Course = require('../models/Course');
const Enrollment = require('../models/Enrollment');
const Assignment = require('../models/Assignment');
const AssignmentSubmission = require('../models/AssignmentSubmission');
const Quiz = require('../models/Quiz');
const QuizAttempt = require('../models/QuizAttempt');
const { sendEmail } = require('../utils/email');
const LiveSession = require('../models/LiveSession');
const Attendance = require('../models/Attendance');
const CourseReview = require('../models/CourseReview');
const { Voucher, applyVoucherDiscount } = require('./vouchers');
const { recheckModuleCompletion, recheckCourseCompletion, notifyLeadInstructorCourseComplete } = require('../utils/courseProgress');
const { computeEffectivePrice, isEarlyBirdActive } = require('../utils/installments');

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

async function computeProgress(enrollment) {
  const course = await Course.findById(enrollment.courseId).lean();
  const totalLessons = (course?.modules || []).reduce((sum, m) => sum + (m.lessons?.length || 0), 0);
  const completedLessons = (enrollment.lessonCompletions || []).length;
  const totalModules = (course?.modules || []).length;
  const completedModules = (enrollment.moduleCompletions || []).length;

  const assignments = await Assignment.find({ courseId: enrollment.courseId, isPublished: true }).lean();
  const totalAssignments = assignments.length;
  let submittedAssignments = 0;
  if (totalAssignments > 0) {
    const subs = await AssignmentSubmission.find({
      assignmentId: { $in: assignments.map(a => a._id) },
      studentId: enrollment.userId,
    }).lean();
    submittedAssignments = subs.length;
  }

  const totalItems = totalLessons + totalAssignments;
  const completedItems = completedLessons + submittedAssignments;
  const progressPct = totalItems > 0 ? Math.round((completedItems / totalItems) * 100) : 0;

  return { progressPct, totalLessons, completedLessons, totalModules, completedModules,
           totalAssignments, submittedAssignments, course };
}

// GET /api/courses/public — list active courses WITHOUT auth (for browsing)
router.get('/public', async (req, res) => {
  try {
    await connectMongoDB();
    // A student's own enrolled courses must still show here even if the
    // instructor later flipped the course to isPublished:false (editing
    // content sets visibility:'private' -> isPublished:false, see
    // instructors.js) — "My Courses" never filtered on isPublished, so a
    // course could be fully accessible there yet silently vanish from
    // Browse with no indication why. Auth is optional on this route (it's
    // the public catalog), so only widen the filter when a valid token is
    // actually present.
    const filter = { is_active: true, isPublished: true };
    if (req.query.q) filter.title = { $regex: req.query.q, $options: 'i' };
    if (req.query.category) filter.category = req.query.category;

    const token = req.headers.authorization?.split(' ')[1];
    if (token) {
      try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        const enrollments = await Enrollment.find({ userId: toId(decoded.id) }).select('courseId').lean();
        const enrolledCourseIds = enrollments.map(e => e.courseId).filter(Boolean);
        if (enrolledCourseIds.length) {
          const baseFilter = { is_active: true };
          if (req.query.q) baseFilter.title = { $regex: req.query.q, $options: 'i' };
          if (req.query.category) baseFilter.category = req.query.category;
          const courses = await Course.find({
            ...baseFilter,
            $or: [{ isPublished: true }, { _id: { $in: enrolledCourseIds } }],
          }).select('-modules').lean();
          return res.json({ success: true, courses, count: courses.length });
        }
      } catch (_) { /* invalid/expired token — fall through to the public-only filter */ }
    }

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
    const courseId = toId(req.params.courseId);
    const enrollments = await Enrollment.find({ courseId })
      .populate('userId', 'name email username').lean();

    const quizzes = await Quiz.find({ courseId, isPublished: true }).select('_id').lean();
    const quizIds = quizzes.map(q => q._id);

    const students = await Promise.all(enrollments.map(async (e) => {
      const { progressPct, totalAssignments, submittedAssignments } = await computeProgress(e);
      let quizzesAttempted = 0;
      if (quizIds.length > 0) {
        const distinctQuizzes = await QuizAttempt.distinct('quizId', {
          quizId: { $in: quizIds }, studentId: e.userId?._id,
        });
        quizzesAttempted = distinctQuizzes.length;
      }
      return {
        _id: e.userId?._id, name: e.userId?.name || e.userId?.username,
        email: e.userId?.email, enrolledAt: e.createdAt,
        progress: { ...e.progress, percent: progressPct },
        totalAssignments, submittedAssignments,
        totalQuizzes: quizIds.length, quizzesAttempted,
      };
    }));

    res.json({ success: true, students });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// DELETE /api/courses/:courseId/students/:studentId — instructor manually
// removes (unenrolls) a student from the course. Only the course owner or a
// co-teacher may do this. The enrollment record is deleted, which revokes
// content access via the existing enrollment-gating on GET /:id.
router.delete('/:courseId/students/:studentId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const courseId = toId(req.params.courseId);
    const studentId = toId(req.params.studentId);
    if (!courseId || !studentId) return res.status(400).json({ success: false, message: 'Invalid ids' });

    const course = await Course.findById(courseId).select('instructor_id coTeachers title').lean();
    if (!course) return res.status(404).json({ success: false, message: 'Course not found' });
    const uid = req.user.id?.toString();
    const isOwner = course.instructor_id?.toString() === uid
      || (course.coTeachers || []).some(t => t.userId?.toString() === uid && (t.status ?? 'accepted') === 'accepted');
    if (!isOwner) return res.status(403).json({ success: false, message: 'Only the instructor can remove students' });

    const result = await Enrollment.deleteOne({ courseId, userId: studentId });
    if (result.deletedCount === 0) {
      return res.status(404).json({ success: false, message: 'Student is not enrolled in this course' });
    }

    // Best-effort: tell the student (never blocks the removal)
    try {
      const Notification = require('../models/Notification');
      await Notification.create({
        userId: studentId,
        type: 'general',
        title: 'Removed from course',
        message: `You have been removed from "${course.title}" by the instructor.`,
        data: { type: 'course_removed', courseId: courseId.toString() },
      });
    } catch (_) {}

    res.json({ success: true, message: 'Student removed' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// GET /api/courses/:courseId/students/:studentId/assignments — instructor view of
// one student's assignment submissions across the course (Student Progress screen)
router.get('/:courseId/students/:studentId/assignments', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const courseId = toId(req.params.courseId);
    const studentId = toId(req.params.studentId);
    const assignments = await Assignment.find({ courseId, isPublished: true }).sort({ createdAt: -1 }).lean();
    const subs = await AssignmentSubmission.find({
      assignmentId: { $in: assignments.map(a => a._id) }, studentId,
    }).lean();
    const subMap = {};
    subs.forEach(s => { subMap[s.assignmentId.toString()] = s; });
    const result = assignments.map(a => ({
      _id: a._id, title: a.title, dueDate: a.dueDate, totalMarks: a.totalMarks,
      submission: subMap[a._id.toString()] || null,
    }));
    res.json({ success: true, assignments: result });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// GET /api/courses/:courseId/students/:studentId/quizzes — instructor view of one
// student's quiz attempts across the course (Student Progress screen)
router.get('/:courseId/students/:studentId/quizzes', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const courseId = toId(req.params.courseId);
    const studentId = toId(req.params.studentId);
    const quizzes = await Quiz.find({ courseId, isPublished: true }).sort({ createdAt: -1 }).lean();
    const attempts = await QuizAttempt.find({
      quizId: { $in: quizzes.map(q => q._id) }, studentId,
    }).sort({ createdAt: -1 }).lean();
    const attemptsByQuiz = {};
    attempts.forEach(a => {
      const k = a.quizId.toString();
      (attemptsByQuiz[k] = attemptsByQuiz[k] || []).push(a);
    });
    const result = quizzes.map(q => ({
      _id: q._id, title: q.title, passingScore: q.passingScore,
      attempts: attemptsByQuiz[q._id.toString()] || [],
    }));
    res.json({ success: true, quizzes: result });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// GET /api/courses/:courseId/engagement — instructor Course Analytics
// "Engagement Metrics" panel: total assignment submissions, total quiz
// attempts, and average live-session attendance % across the course.
router.get('/:courseId/engagement', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const courseId = toId(req.params.courseId);

    const assignments = await Assignment.find({ courseId, isPublished: true }).select('_id').lean();
    const totalSubmissions = await AssignmentSubmission.countDocuments({
      assignmentId: { $in: assignments.map(a => a._id) },
    });

    const quizzes = await Quiz.find({ courseId, isPublished: true }).select('_id').lean();
    const totalQuizAttempts = await QuizAttempt.countDocuments({
      quizId: { $in: quizzes.map(q => q._id) },
    });

    const sessions = await Attendance.find({ courseId }).lean();
    const enrollmentCount = await Enrollment.countDocuments({ courseId });
    let avgAttendancePct = 0;
    if (sessions.length > 0 && enrollmentCount > 0) {
      let presentTally = 0;
      sessions.forEach(s => {
        (s.records || []).forEach(r => {
          if (r.status === 'present') presentTally += 1;
          else if (r.status === 'late') presentTally += 0.5;
        });
      });
      avgAttendancePct = Math.round((presentTally / (sessions.length * enrollmentCount)) * 100);
    }

    res.json({
      success: true,
      totalAssignments: assignments.length,
      totalSubmissions,
      totalQuizzes: quizzes.length,
      totalQuizAttempts,
      totalSessions: sessions.length,
      avgAttendancePct,
    });
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
    const { courseId, voucherCode } = req.body;
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

    let amountPaid = course.isFree ? 0 : (course.discountedPrice || course.price || 0);
    let redeemedVoucher = null;

    if (voucherCode) {
      const voucher = await Voucher.findOne({ code: voucherCode.trim().toUpperCase() });
      if (!voucher) return res.status(400).json({ success: false, message: 'Invalid voucher code' });
      if (voucher.usedBy) return res.status(400).json({ success: false, message: 'This voucher has already been used' });
      if (voucher.expiresAt && new Date() > voucher.expiresAt) {
        return res.status(400).json({ success: false, message: 'Voucher has expired' });
      }
      if (voucher.courseId && voucher.courseId.toString() !== cId.toString()) {
        return res.status(400).json({ success: false, message: 'Voucher is not valid for this course' });
      }
      amountPaid = applyVoucherDiscount(voucher, course.price || 0);
      redeemedVoucher = voucher;
    }

    // ── SAFEPAY PAYMENT GATE ──────────────────────────────────────────────
    // Paid courses can ONLY be enrolled through a verified Safepay payment.
    // (Payment fulfillment in routes/payments.js creates the enrollment itself;
    //  this direct path is only for free courses / 100%-discount vouchers.)
    if (amountPaid > 0) {
      const Payment = require('../models/Payment');
      const paid = await Payment.findOne({
        userId: uId, type: 'course', refId: cId, status: 'paid',
      }).lean();
      if (!paid) {
        return res.status(402).json({
          success: false,
          paymentRequired: true,
          amount: amountPaid,
          message: 'Payment required. Create a payment via /api/payments/create first.',
        });
      }
    }

    const enrollment = await Enrollment.create({
      userId: uId,
      courseId: cId,
      amountPaid,
      voucherCode: redeemedVoucher ? redeemedVoucher.code : null,
    });

    if (redeemedVoucher) {
      redeemedVoucher.usedBy = uId;
      redeemedVoucher.usedAt = new Date();
      await redeemedVoucher.save();
    }

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
    // Populate course data — is_active: { $ne: false } excludes deleted/
    // deactivated courses (deletion sets is_active: false rather than
    // removing the document). Without this filter, an enrollment for a
    // course an instructor deleted kept showing up as a broken/unrelated
    // entry in the student's My Courses list.
    const courseIds = enrollments.map(e => e.courseId);
    const courses = await Course.find({ _id: { $in: courseIds }, is_active: { $ne: false } }).lean();
    const courseMap = {};
    courses.forEach(c => { courseMap[c._id.toString()] = c; });
    const items = await Promise.all(
      enrollments
        .filter(e => courseMap[e.courseId?.toString()])
        .map(async (e) => {
          const { progressPct } = await computeProgress(e);
          return {
            ...e,
            course: courseMap[e.courseId.toString()],
            progress: { ...e.progress, percent: progressPct },
          };
        })
    );
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

// GET /certificates/my — completed enrollments + issued Certificate docs, merged per course
router.get('/certificates/my', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const uId = toId(req.user.id);
    const enrollments = await Enrollment.find({ userId: uId, 'progress.completed': true }).lean();
    const Certificate = require('../models/Certificate');
    const issued = await Certificate.find({ studentId: uId, approvalStatus: 'approved' }).lean();

    const courseIds = [
      ...enrollments.map(e => e.courseId),
      ...issued.map(c => c.courseId),
    ];
    const courses = await Course.find({ _id: { $in: courseIds } }).lean();
    const courseMap = {};
    courses.forEach(c => { courseMap[c._id.toString()] = c; });

    const byCourse = {};
    // Issued certificates take priority — they carry the number + verification code
    issued.forEach(c => {
      byCourse[c.courseId.toString()] = {
        _id: c._id,
        completedAt: c.completionDate,
        createdAt: c.issuedAt || c.createdAt,
        certificateNumber: c.certificateNumber,
        verificationCode: c.verificationCode,
        studentName: c.studentName,
        instructorName: c.instructorName,
        template: c.template,
        enrollmentId: c.enrollmentId?.toString(),
        courseId: c.courseId?.toString(),
        course: courseMap[c.courseId.toString()] || { _id: c.courseId, title: c.courseName },
      };
    });
    enrollments.forEach(e => {
      const key = e.courseId.toString();
      if (!byCourse[key]) {
        byCourse[key] = {
          _id: e._id,
          completedAt: e.progress?.completedAt,
          createdAt: e.progress?.completedAt,
          course: courseMap[key] || null,
        };
      }
    });

    const certificates = Object.values(byCourse)
      .sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0));
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

// GET /courses/my-pending-invites — all co-teacher invites awaiting this
// user's response, across every course. Surfaced directly on the instructor
// Home tab (not just buried in a notification) so an invite can't be missed.
// MUST be registered before GET /:id, or Express matches "my-pending-invites"
// as an :id param and this route never gets hit.
router.get('/my-pending-invites', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const uid = req.user.id?.toString();
    // Also match legacy invites created before `status` existed on the
    // schema — Mongoose's `default: 'pending'` only applies to new docs,
    // it doesn't backfill rows already sitting in Mongo without the field.
    const courses = await Course.find({
      'coTeachers.userId': toId(uid),
      $or: [{ 'coTeachers.status': 'pending' }, { 'coTeachers.status': { $exists: false } }],
    })
      .select('title instructor_id coTeachers')
      .lean();

    const invites = [];
    for (const course of courses) {
      const entry = (course.coTeachers || []).find(t => t.userId?.toString() === uid && (t.status === 'pending' || !t.status));
      if (!entry) continue;
      const inviter = await require('../models/User').findById(course.instructor_id).select('name username').lean();
      invites.push({
        courseId: course._id,
        courseTitle: course.title,
        role: entry.role || 'normal',
        invitedAt: entry.invitedAt || null,
        inviterName: inviter?.name || inviter?.username || 'An instructor',
      });
    }

    res.json({ success: true, invites });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// GET /api/courses/:courseId/student-progress/:studentId — full progress
// breakdown for one student in one course (Lead Instructor / owner use).
// Registered before GET /:id so Express doesn't match "student-progress"
// as the :id param.
router.get('/:courseId/student-progress/:studentId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { courseId, studentId } = req.params;
    const course = await Course.findById(toId(courseId)).lean();
    if (!course) return res.status(404).json({ success: false, message: 'Course not found' });

    const uid = req.user.id?.toString();
    const isOwner = course.instructor_id?.toString() === uid
      || (course.coTeachers || []).some(t => t.userId?.toString() === uid && (t.status ?? 'accepted') === 'accepted');
    if (!isOwner) return res.status(403).json({ success: false, message: 'Not authorized' });

    // Not .lean() — recheckModuleCompletion needs a real document to push
    // subdocs onto and save(). This view previously only ever read
    // lessonCompletions/moduleCompletions as they already stood in the DB —
    // that self-heals on GET /courses/:id (called when the STUDENT opens
    // their own course), but the instructor's Student Progress dialog calls
    // this route directly and could easily be opened before the student
    // ever reopened the course after a session ended, showing a stale
    // "Not started" for something the student had, in reality, already
    // finished (e.g. a live session that ended, whose completion this same
    // recheck would have already recorded had it run).
    const enrollmentDoc = await Enrollment.findOne({ courseId: toId(courseId), userId: toId(studentId) });
    if (!enrollmentDoc) return res.status(404).json({ success: false, message: 'Student is not enrolled in this course' });
    let progressChanged = false;
    // Deliberately does NOT skip modules already in moduleCompletions —
    // recheckModuleCompletion's live-lesson auto-complete step
    // (lessonCompletions) runs unconditionally every call regardless of
    // whether the MODULE itself was already marked done; a live session
    // lesson added to an already-completed module (e.g. instructor adds
    // another live session after students already finished everything
    // else) would otherwise never get its own lessonCompletions entry —
    // the module-level "already done" skip meant this function simply
    // never ran again for that module, so the new lesson stayed "Not
    // started" forever even after it genuinely ended. The function itself
    // is idempotent (only ever appends when not already present), so
    // re-running it on an already-complete module is always safe.
    for (const mod of (course.modules || [])) {
      const modId = mod._id?.toString();
      if (!modId) continue;
      const beforeLessons = (enrollmentDoc.lessonCompletions || []).length;
      const beforeModules = (enrollmentDoc.moduleCompletions || []).length;
      // `course` is already in memory here — pass it so this loop doesn't
      // re-fetch the same document once per module.
      await recheckModuleCompletion(enrollmentDoc, modId, course);
      if ((enrollmentDoc.lessonCompletions || []).length > beforeLessons) progressChanged = true;
      if ((enrollmentDoc.moduleCompletions || []).length > beforeModules) progressChanged = true;
    }
    if (progressChanged) await enrollmentDoc.save();
    const enrollment = enrollmentDoc.toObject();

    const student = await require('../models/User').findById(toId(studentId)).select('name username email').lean();

    // Per-module breakdown: lessons/assignments/quizzes done vs total
    const completedLessonIds = new Set((enrollment.lessonCompletions || []).map(lc => lc.lessonId));
    const completedModuleIds = new Set((enrollment.moduleCompletions || []).map(mc => mc.moduleId));

    const allAssignmentLessonIds = [];
    const allQuizLessonIds = [];
    for (const mod of (course.modules || [])) {
      for (const l of (mod.lessons || [])) {
        if (l.type === 'assignment' && l._id) allAssignmentLessonIds.push(l._id);
        if (l.type === 'quiz' && l._id) allQuizLessonIds.push(l._id);
      }
    }
    const submissions = allAssignmentLessonIds.length
      ? await AssignmentSubmission.find({ assignmentId: { $in: allAssignmentLessonIds }, studentId: toId(studentId) }).lean()
      : [];
    const submissionByAssignmentId = Object.fromEntries(submissions.map(s => [s.assignmentId.toString(), s.status]));
    const passedAttempts = allQuizLessonIds.length
      ? await QuizAttempt.find({ quizId: { $in: allQuizLessonIds }, studentId: toId(studentId), passed: true }).lean()
      : [];
    const passedQuizIds = new Set(passedAttempts.map(a => a.quizId.toString()));

    // Live-lesson completion (see recheckModuleCompletion) is intentionally
    // time-based, not attendance-based — a missed session still isn't
    // meant to block the rest of the course, so it still gets marked
    // "done" once its time has passed regardless of who showed up. That's
    // correct for unlock/module-completion purposes, but it made this
    // progress view claim a student "Completed" a live session they never
    // actually attended. Reporting-only fix: report 'not_attended' instead
    // of 'completed' when the student wasn't present, without touching
    // lessonCompletions/moduleCompletions/unlock logic at all.
    //
    // Source of truth is the Attendance collection (records[].status, with
    // real joinedAt/leftAt/durationMinutes written by record-join/leave) —
    // the same data the student's own Grades > Attendance tab renders, so
    // both sides always agree. LiveSession.attendees is NOT reliable here:
    // it isn't consistently populated on join, so keying off it reported
    // "Not Attended" for students the Attendance collection correctly had
    // as Present.
    const liveSessionsForAttendance = await LiveSession.find({ courseId: toId(courseId) })
      .select('_id').lean();
    const attendanceDocs = await Attendance.find({ courseId: toId(courseId) })
      .select('liveSessionId records').lean();
    // liveSessionId -> true when this student has a present/late record
    const attendedSessionIds = new Set(
      attendanceDocs
        .filter(a => (a.records || []).some(r =>
          r?.studentId?.toString() === studentId && (r.status === 'present' || r.status === 'late')))
        .map(a => a.liveSessionId?.toString())
        .filter(Boolean)
    );
    // Map attended sessions back to module lessons via the LESSON's own
    // liveSessionId field, not LiveSession.linkedLessonId. Only the former
    // is reliably written (end-and-save sets
    // 'modules.$[].lessons.$[lesson].liveSessionId'); linkedLessonId is
    // only ever set by syncLiveSessions for pre-scheduled sessions, so
    // going session -> lesson silently matched nothing for sessions
    // started straight from a module lesson tile — which is why a student
    // with correct 13/15 attendance still showed "Not Attended" on the
    // individual lesson row.
    const attendedLessonIds = new Set();
    for (const mod of (course.modules || [])) {
      for (const l of (mod.lessons || [])) {
        const sid = l.liveSessionId?.toString();
        if (sid && attendedSessionIds.has(sid)) attendedLessonIds.add(l._id?.toString());
      }
    }

    const modules = (course.modules || []).map(mod => {
      const lessons = (mod.lessons || []).map(l => {
        const lid = l._id?.toString();
        let itemStatus = 'not_started';
        if (l.type === 'assignment') {
          const s = submissionByAssignmentId[lid];
          itemStatus = s === 'graded' ? 'graded' : (s ? 'submitted' : 'not_started');
        } else if (l.type === 'quiz') {
          itemStatus = passedQuizIds.has(lid) ? 'completed' : 'not_started';
        } else if (l.type === 'live') {
          if (!completedLessonIds.has(lid)) itemStatus = 'not_started';
          else itemStatus = attendedLessonIds.has(lid) ? 'completed' : 'not_attended';
        } else {
          itemStatus = completedLessonIds.has(lid) ? 'completed' : 'not_started';
        }
        return { _id: l._id, title: l.title, type: l.type || 'content', status: itemStatus };
      });
      return {
        _id: mod._id,
        title: mod.title,
        isCompleted: completedModuleIds.has(mod._id?.toString()),
        lessons,
      };
    });

    // Standalone assignments/quizzes not embedded in any module
    const standaloneAssignments = await Assignment.find({ courseId: toId(courseId), isPublished: true }).lean();
    const standaloneAssignmentIds = new Set(standaloneAssignments.map(a => a._id.toString()));
    const embeddedAssignmentIds = new Set(allAssignmentLessonIds.map(id => id.toString()));
    const extraAssignments = standaloneAssignments.filter(a => !embeddedAssignmentIds.has(a._id.toString()));
    let extraAssignmentStatuses = [];
    if (extraAssignments.length) {
      const extraSubs = await AssignmentSubmission.find({
        assignmentId: { $in: extraAssignments.map(a => a._id) }, studentId: toId(studentId),
      }).lean();
      const subMap = Object.fromEntries(extraSubs.map(s => [s.assignmentId.toString(), s.status]));
      extraAssignmentStatuses = extraAssignments.map(a => ({
        _id: a._id, title: a.title, type: 'assignment',
        status: subMap[a._id.toString()] === 'graded' ? 'graded' : (subMap[a._id.toString()] ? 'submitted' : 'not_started'),
      }));
    }

    // Attendance summary for this student in this course — same Attendance
    // collection source as the per-lesson status above (and as the
    // student's own Attendance tab), not LiveSession.attendees, which
    // isn't reliably populated. This is why the header previously showed
    // "0 / N" attendance for a student the student-side view correctly
    // reported as having attended most sessions.
    const totalSessions = liveSessionsForAttendance.length;
    const attendedSessions = liveSessionsForAttendance.filter(s =>
      attendedSessionIds.has(s._id?.toString())
    ).length;

    const totalModules = modules.length;
    const completedModulesCount = modules.filter(m => m.isCompleted).length;

    res.json({
      success: true,
      progress: {
        student: { _id: studentId, name: student?.name || student?.username || 'Student', email: student?.email || '' },
        isCourseCompleted: enrollment.isCompleted === true,
        totalModules,
        completedModules: completedModulesCount,
        modules,
        extraAssignments: extraAssignmentStatuses,
        attendance: { attended: attendedSessions, total: totalSessions },
        enrolledAt: enrollment.createdAt || null,
        completedAt: enrollment.completedAt || null,
      },
    });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// GET /api/courses/:id — get single course
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const course = await Course.findById(toId(req.params.id))
      .populate('modules.lessons.createdBy', 'name username')
      .lean();
    if (!course) return res.status(404).json({ success: false, message: 'Course not found' });

    // Attach module unlock info for student view
    const now = new Date();
    // Not .lean() — recheckModuleCompletion needs a real document to push
    // subdocs onto and save(). This also self-heals stale progress: some
    // older lessonCompletions rows were saved with moduleId:null (a since-
    // fixed frontend bug), which meant a fully-watched module's completion
    // was never (re)computed because complete-lesson's `if (moduleId)`
    // guard skipped it — the student was stuck with every lesson checked
    // off but the next module still locked, with no action left to take
    // that would ever re-trigger the check. Re-running it here, on every
    // course fetch, means simply opening the course fixes it.
    const enrollmentDoc = await Enrollment.findOne({ userId: toId(req.user.id), courseId: course._id });
    if (enrollmentDoc) {
      let changed = false;
      let justCompletedCourse = false;
      // Deliberately does NOT skip modules already in moduleCompletions —
      // see the matching comment on the /student-progress route above for
      // why: recheckModuleCompletion's live-lesson auto-complete step
      // needs to keep running even for an already-"done" module, since a
      // NEW live-session lesson can be added to it later (e.g. instructor
      // schedules another live class after the module was first
      // completed), and that lesson's own lessonCompletions entry would
      // otherwise never get written — the function is idempotent, so
      // this is always safe to re-run.
      for (const mod of (course.modules || [])) {
        const modId = mod._id?.toString();
        if (!modId) continue;
        const beforeLessons = (enrollmentDoc.lessonCompletions || []).length;
        const beforeModules = (enrollmentDoc.moduleCompletions || []).length;
        // Same as the GET /:id loop — reuse the course already loaded above.
        const result = await recheckModuleCompletion(enrollmentDoc, modId, course);
        if ((enrollmentDoc.lessonCompletions || []).length > beforeLessons) changed = true;
        if ((enrollmentDoc.moduleCompletions || []).length > beforeModules) changed = true;
        if (result?.justCompletedCourse) justCompletedCourse = true;
      }
      // Covers the case where every module was already individually marked
      // complete across earlier visits — the loop above then calls
      // recheckModuleCompletion zero times this pass (its per-module
      // `alreadyDone` skip), so the whole-course isCompleted flag (only
      // ever set inside that function) never got a chance to fire even
      // though the student had genuinely finished everything. This was the
      // actual reason "Issue Certificate" never appeared for some students.
      if (!justCompletedCourse) {
        const courseResult = await recheckCourseCompletion(enrollmentDoc);
        if (courseResult?.justCompletedCourse) { changed = true; justCompletedCourse = true; }
      }
      if (changed) {
        await enrollmentDoc.save();
        if (justCompletedCourse) notifyLeadInstructorCourseComplete(enrollmentDoc);
      }
    }
    const enrollment = enrollmentDoc ? enrollmentDoc.toObject() : null;
    const completedModuleIds = new Set((enrollment?.moduleCompletions || []).map(m => m.moduleId));

    // Gate full module/lesson content behind enrollment (or ownership) —
    // browsing the catalog / course-detail preview only needs title,
    // description, pricing, etc.; the actual modules array (videos,
    // documents, live-session links) should only go to the instructor who
    // owns the course or a student who has actually enrolled.
    const uid = req.user.id?.toString();
    const isOwner = course.instructor_id?.toString() === uid
      || (course.coTeachers || []).some(t => t.userId?.toString() === uid && (t.status ?? 'accepted') === 'accepted');
    if (!enrollment && !isOwner) {
      return res.json({ success: true, course: { ...course, modules: [], enrollmentId: null, locked: true } });
    }

    // Soft lock: an installment became overdue past its grace period. Content
    // is hidden exactly like the "never enrolled" case, but progress/the
    // enrollment itself is untouched, and a distinct lockReason lets the UI
    // show "pay now to unlock" instead of "buy this course".
    if (enrollment?.installmentLocked && !isOwner) {
      return res.json({
        success: true,
        course: {
          ...course, modules: [], enrollmentId: enrollment._id.toString(),
          locked: true, lockReason: 'installment_overdue',
          installmentPlanEnabled: enrollment.installmentPlanEnabled || false,
          installments: enrollment.installments || [],
        },
      });
    }

    // Lesson-level completion flag — without this, LessonDetailPage's
    // initState() (widget.lesson['isCompleted']) always saw undefined/false
    // regardless of what was actually saved in enrollment.lessonCompletions,
    // so a lesson the student had already marked complete looked unchecked
    // again the moment they reopened it (the POST to complete-lesson had
    // actually succeeded — this GET just never reported it back).
    const completedLessonIds = new Set((enrollment?.lessonCompletions || []).map(lc => lc.lessonId));

    // Assignment/quiz-type lesson entries reuse the real Assignment/Quiz
    // _id (see instructor_create_assignment_screen.dart / create_quiz_screen
    // — the created doc's own _id is what gets pushed into module.lessons),
    // so submission/attempt status can be looked up directly for the
    // module-embedded tile too, not just the standalone Grades tab.
    let submissionStatusByAssignmentId = {};
    let quizPassedByQuizId = {};
    if (enrollment) {
      const assignmentLessonIds = [];
      const quizLessonIds = [];
      for (const mod of (course.modules || [])) {
        for (const l of (mod.lessons || [])) {
          if (l.type === 'assignment' && l._id) assignmentLessonIds.push(l._id);
          if (l.type === 'quiz' && l._id) quizLessonIds.push(l._id);
        }
      }
      if (assignmentLessonIds.length) {
        const subs = await AssignmentSubmission.find({
          assignmentId: { $in: assignmentLessonIds }, studentId: enrollment.userId,
        }).select('assignmentId status').lean();
        submissionStatusByAssignmentId = Object.fromEntries(subs.map(s => [s.assignmentId.toString(), s.status]));
      }
      if (quizLessonIds.length) {
        const attempts = await QuizAttempt.find({
          quizId: { $in: quizLessonIds }, studentId: enrollment.userId, passed: true,
        }).select('quizId').lean();
        quizPassedByQuizId = Object.fromEntries(attempts.map(a => [a.quizId.toString(), true]));
      }
    }

    // Defensive floor: modules/lessons are meant to render in the order the
    // instructor arranged them (see PUT /:id, which stamps `order` = array
    // index on every save) — sort explicitly here too so display order stays
    // correct even if some older document predates that stamping.
    course.modules = (course.modules || [])
      .slice()
      .sort((a, b) => (a.order ?? 0) - (b.order ?? 0))
      .map(mod => ({
        ...mod,
        lessons: Array.isArray(mod.lessons)
          ? mod.lessons.slice().sort((a, b) => (a.order ?? 0) - (b.order ?? 0))
          : mod.lessons,
      }));

    course.modules = course.modules.map((mod, idx) => {
      let isLocked = false;
      let unlockDate = null;

      if (course.courseType === 'pragmatic' && course.startDate) {
        // Pragmatic: unlock needs BOTH the scheduled date to have arrived
        // AND (for modules after the first) the previous module actually
        // completed — reaching the date alone used to unlock it regardless
        // of whether lessons/quiz/assignment were ever finished.
        const days = mod.unlockAfterDays || 0;
        const unlock = new Date(course.startDate);
        unlock.setDate(unlock.getDate() + days);
        unlockDate = unlock.toISOString();
        const dateLocked = now < unlock;
        const prevMod = idx > 0 ? course.modules[idx - 1] : null;
        const prevId = prevMod?._id?.toString();
        const completionLocked = prevId ? !completedModuleIds.has(prevId) : false;
        isLocked = dateLocked || completionLocked;
      } else if (course.courseType === 'self-paced' && idx > 0) {
        // Self-paced: previous module must be completed
        const prevMod = course.modules[idx - 1];
        const prevId = prevMod?._id?.toString();
        isLocked = prevId ? !completedModuleIds.has(prevId) : false;
      }

      const lessons = (mod.lessons || []).map(l => {
        const lid = l._id?.toString();
        if (l.type === 'assignment') {
          const submissionStatus = submissionStatusByAssignmentId[lid] || null;
          return { ...l, submissionStatus, isCompleted: submissionStatus === 'graded' };
        }
        if (l.type === 'quiz') {
          return { ...l, isCompleted: quizPassedByQuizId[lid] === true };
        }
        return { ...l, isCompleted: completedLessonIds.has(lid) };
      });

      return { ...mod, lessons, isLocked, unlockDate };
    });

    course.enrollmentId = enrollment?._id?.toString() || null;
    course.completedModuleIds = [...completedModuleIds];
    course.installmentPlanEnabled = enrollment?.installmentPlanEnabled || false;
    course.installments = enrollment?.installments || [];
    course.installmentLocked = enrollment?.installmentLocked || false;
    course.effectivePrice = computeEffectivePrice(course);
    course.earlyBirdActive = isEarlyBirdActive(course);
    // Real per-course ownership (instructor_id match or accepted co-teacher),
    // computed above for the content gate — surfaced here too so the client
    // can stop inferring "is this an instructor view" from the caller's
    // account role. Role alone is wrong: a doctor account (role=='doctor')
    // was being treated as an instructor on every course, so a doctor who
    // was neither enrolled in nor teaching a course still got the Go Live /
    // edit Course Content / Student Progress controls, which then 403'd the
    // instant they were used, since the backend correctly checks ownership.
    course.isOwner = isOwner;
    res.json({ success: true, course });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// Shared validation for the Early Bird + Installment fields on create/update.
// Returns an error message string, or null if valid.
function validatePricingFields(body) {
  if (body.earlyBirdEnabled) {
    const amount = Number(body.earlyBirdAmount);
    const price = Number(body.discountedPrice || body.price || 0);
    if (!(amount > 0)) return 'Early Bird amount must be greater than 0';
    if (!body.earlyBirdDeadline) return 'Early Bird deadline is required';
    if (amount >= price) return 'Early Bird amount must be less than the course price';
  }
  if (body.installmentPlanEnabled) {
    const plan = body.installmentPlan;
    if (!Array.isArray(plan) || plan.length < 2) {
      return 'Add at least 2 installments';
    }
    let prevDays = -1;
    for (let i = 0; i < plan.length; i++) {
      const amt = Number(plan[i]?.amount);
      const days = Number(plan[i]?.daysAfterEnrollment);
      if (!(amt > 0)) return `Installment ${i + 1}: amount must be greater than 0`;
      if (i === 0 && days !== 0) return 'First installment must be due on enrollment (0 days)';
      if (!Number.isInteger(days) || days < 0) return `Installment ${i + 1}: invalid days`;
      if (i > 0 && days <= prevDays) {
        return `Installment ${i + 1}: days must be greater than the previous installment`;
      }
      prevDays = days;
    }
  }
  return null;
}

// POST /api/courses — create course (instructor)
// Create LiveSession docs for any lessons that have a liveSessionDateTime.
// IMPORTANT: `modules` must be the SAVED course.modules (real Mongoose
// subdocument _ids), not the raw request body — see the two call sites.
async function syncLiveSessions(courseId, instructorId, modules) {
  if (!Array.isArray(modules)) return;
  for (const mod of modules) {
    for (const lesson of (mod.lessons || [])) {
      if (!lesson.liveSessionDateTime) continue;
      const scheduledAt = new Date(lesson.liveSessionDateTime);
      if (isNaN(scheduledAt)) continue;
      const lessonId = lesson._id?.toString() || lesson.id?.toString() || null;
      const modId = mod._id?.toString() || mod.id?.toString() || null;
      if (!lessonId || !modId) continue; // no stable id to link against — skip rather than fall back to a title match that can never resolve client-side
      // Upsert by courseId + linkedLessonId so we don't create duplicates on edit
      const filter = { courseId: toId(courseId), linkedLessonId: lessonId };
      const update = {
        $set: {
          courseId: toId(courseId),
          instructorId: toId(instructorId),
          title: lesson.liveSessionNote?.trim() || `Live: ${lesson.title || 'Session'}`,
          scheduledAt,
          linkedLessonId: lessonId,
          linkedModuleId: modId,
          status: 'scheduled',
          ...(lesson.meetingLink ? { meetingLink: lesson.meetingLink } : {}),
        },
        $setOnInsert: { duration: 60, maxParticipants: 100, isRecorded: true },
      };
      await LiveSession.findOneAndUpdate(filter, update, { upsert: true, new: true });
    }
  }
}

router.post('/', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const pricingError = validatePricingFields(req.body);
    if (pricingError) return res.status(400).json({ success: false, message: pricingError });
    const course = await Course.create({ ...req.body, instructor_id: toId(req.user.id) });
    // Use course.modules (the saved document), NOT req.body.modules (the raw
    // client payload) — Mongoose only assigns each module/lesson subdocument
    // its real _id once it's actually saved. syncLiveSessions links a live
    // session to its module via that _id (linkedModuleId); passing the raw
    // body meant every module was still missing an _id at this point, so the
    // link silently fell back to the module's title and could never match
    // when the Course Content screen later looked up sessions by module._id.
    await syncLiveSessions(course._id, req.user.id, course.modules);
    res.status(201).json({ success: true, course });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// PUT /api/courses/:id — update course
router.put('/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const pricingError = validatePricingFields(req.body);
    if (pricingError) return res.status(400).json({ success: false, message: pricingError });
    // Stamp order = array position on every save so module/lesson display
    // order is explicit and authoritative instead of relying on Mongo array
    // position alone surviving every future edit path unchanged.
    if (Array.isArray(req.body.modules)) {
      req.body.modules = req.body.modules.map((mod, mIdx) => ({
        ...mod,
        order: mIdx,
        lessons: Array.isArray(mod.lessons)
          ? mod.lessons.map((lesson, lIdx) => ({
              ...lesson,
              order: lIdx,
              // Stamp who created this lesson (session/assignment/quiz/content
              // item), for the "Created by" label — only on first save, so
              // re-editing an existing lesson never overwrites the original
              // creator with whoever happens to save next.
              createdBy: lesson.createdBy || req.user.id,
            }))
          : mod.lessons,
      }));
    }
    const course = await Course.findByIdAndUpdate(toId(req.params.id), { $set: req.body }, { new: true });
    if (!course) return res.status(404).json({ success: false, message: 'Not found' });
    // Same reasoning as POST / above — use the saved course.modules (real
    // subdocument _ids) rather than the raw req.body.modules.
    await syncLiveSessions(course._id, req.user.id, course.modules);
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

// POST /enrollments/:id/complete-module — mark module as complete.
// This is the manual "Mark Module as Complete" button — it does NOT force
// completion. It re-validates via recheckModuleCompletion (same rule the
// automatic per-lesson/per-assignment/per-quiz completion uses: every
// lesson watched, every assignment submitted, every quiz passed) and only
// actually marks it done if that validation passes. Previously this pushed
// a completion unconditionally, so a student could "complete" a module —
// and unlock the next one — without ever submitting its assignment.
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

    const result = await recheckModuleCompletion(enrollment, moduleId);
    const nowCompleted = enrollment.moduleCompletions.find(mc => mc.moduleId === moduleId);
    if (!nowCompleted) {
      return res.status(400).json({
        success: false,
        message: 'This module is not fully complete yet — finish all lessons, assignments, and quizzes first.',
      });
    }
    await enrollment.save();
    if (result?.justCompletedCourse) notifyLeadInstructorCourseComplete(enrollment);

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

// POST /enrollments/:id/complete-lesson — mark individual lesson as complete + auto-complete module
router.post('/enrollments/:id/complete-lesson', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { lessonId, moduleId } = req.body;
    if (!lessonId) return res.status(400).json({ success: false, message: 'lessonId required' });

    const enrollment = await Enrollment.findById(toId(req.params.id));
    if (!enrollment) return res.status(404).json({ success: false, message: 'Enrollment not found' });

    // Add lesson completion if not already
    const existingLesson = enrollment.lessonCompletions?.find(lc => lc.lessonId === lessonId);
    if (!existingLesson) {
      if (!enrollment.lessonCompletions) enrollment.lessonCompletions = [];
      enrollment.lessonCompletions.push({ lessonId, moduleId: moduleId || null, completedAt: new Date() });
    }

    // Auto-complete module (and course) if all lessons AND all published quizzes in it are done
    let justCompletedCourse = false;
    if (moduleId) {
      const result = await recheckModuleCompletion(enrollment, moduleId);
      justCompletedCourse = result?.justCompletedCourse === true;
    }

    await enrollment.save();
    if (justCompletedCourse) notifyLeadInstructorCourseComplete(enrollment);

    const p = await computeProgress(enrollment);
    res.json({ success: true, progressPct: p.progressPct, isCompleted: enrollment.isCompleted || false,
               totalAssignments: p.totalAssignments, submittedAssignments: p.submittedAssignments });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// GET /enrollments/:id/progress — get detailed lesson/module progress for a student
router.get('/enrollments/:id/progress', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const enrollment = await Enrollment.findById(toId(req.params.id)).lean();
    if (!enrollment) return res.status(404).json({ success: false, message: 'Enrollment not found' });
    const p = await computeProgress(enrollment);
    res.json({
      success: true,
      progressPct: p.progressPct,
      totalLessons: p.totalLessons,
      completedLessons: p.completedLessons,
      totalModules: p.totalModules,
      completedModules: p.completedModules,
      totalAssignments: p.totalAssignments,
      submittedAssignments: p.submittedAssignments,
      lessonCompletions: enrollment.lessonCompletions || [],
      moduleCompletions: enrollment.moduleCompletions || [],
      isCompleted: enrollment.isCompleted || false,
    });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// POST /courses/:id/invite-teacher — invite co-teacher by email with a role label.
// role is free text (e.g. "Coordinator"); 'lead' is the one reserved value
// that grants certificate-issuing authority. The invite is added as
// status:'pending' — the invited teacher must accept it (see accept/reject
// routes below) before they get real access to the course.
router.post('/:id/invite-teacher', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { email, role } = req.body;
    if (!email) return res.status(400).json({ success: false, message: 'Email required' });

    const course = await Course.findById(toId(req.params.id)).lean();
    if (!course) return res.status(404).json({ success: false, message: 'Course not found' });

    const User = require('../models/User');
    const invitedUser = await User.findOne({ email: email.toLowerCase().trim() }).lean();

    if (!invitedUser) {
      return res.status(404).json({ success: false, message: `No user found with email: ${email}. They must register on iCare first.` });
    }

    const teacherRole = ((role || '') + '').trim() || 'normal';
    const roleLabel = teacherRole.toLowerCase() === 'lead' ? 'Lead Instructor' : teacherRole === 'normal' ? 'Co-Instructor' : teacherRole;

    // Add as co-teacher with role if not already
    const existingEntry = (course.coTeachers || []).find(t => {
      const tid = t.userId ? t.userId.toString() : t.toString();
      return tid === invitedUser._id.toString();
    });
    if (existingEntry) return res.json({ success: true, message: 'This teacher is already in the course.' });

    await Course.findByIdAndUpdate(toId(req.params.id), {
      $addToSet: { coTeachers: { userId: invitedUser._id, role: teacherRole, status: 'pending', name: invitedUser.name, email: invitedUser.email, invitedAt: new Date() } }
    });

    // Send notification to invited teacher
    const Notification = require('../models/Notification');
    const inviter = await User.findById(req.user.id).lean();
    await Notification.create({
      userId: invitedUser._id,
      type: 'general',
      title: 'Co-Teacher Invitation',
      message: `${inviter?.name || 'An instructor'} has invited you as ${roleLabel} for "${course.title}". Accept to join.`,
      data: { courseId: course._id, courseName: course.title, subType: 'coteacher_invite' },
    }).catch(() => {});

    // Email the invited teacher
    sendEmail({
      to: invitedUser.email,
      subject: `You're invited to co-teach on iCare: ${course.title}`,
      html: `<p>Hi ${invitedUser.name || 'there'},</p>
             <p><b>${inviter?.name || 'An instructor'}</b> has invited you as <b>${roleLabel}</b> for the course <b>"${course.title}"</b> on iCare LMS.</p>
             <p>Log in to your iCare instructor account and accept the invitation — the course will then appear in your <b>My Courses</b> list.</p>
             <p>— iCare Team</p>`,
    }).catch(e => console.error('Co-teacher invite email failed:', e.message));

    res.json({ success: true, message: `Invitation sent to ${invitedUser.name || email}` });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// POST /courses/:id/co-teacher/accept — invited teacher accepts the invite
router.post('/:id/co-teacher/accept', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const course = await Course.findById(toId(req.params.id));
    if (!course) return res.status(404).json({ success: false, message: 'Course not found' });

    const entry = (course.coTeachers || []).find(t => t.userId?.toString() === req.user.id);
    if (!entry) return res.status(404).json({ success: false, message: 'No pending invite found for this user' });

    entry.status = 'accepted';
    await course.save();
    res.json({ success: true, message: 'Invitation accepted' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// POST /courses/:id/co-teacher/reject — invited teacher declines the invite
router.post('/:id/co-teacher/reject', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const course = await Course.findById(toId(req.params.id));
    if (!course) return res.status(404).json({ success: false, message: 'Course not found' });

    const before = (course.coTeachers || []).length;
    course.coTeachers = (course.coTeachers || []).filter(t => t.userId?.toString() !== req.user.id);
    if (course.coTeachers.length === before) {
      return res.status(404).json({ success: false, message: 'No pending invite found for this user' });
    }
    await course.save();
    res.json({ success: true, message: 'Invitation declined' });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// Only the course owner or a co-teacher with role 'lead'/'lead instructor'
// may manage other co-teachers (remove, change role).
async function assertCanManageCoTeachers(courseId, userId) {
  const course = await Course.findById(courseId).select('instructor_id coTeachers').lean();
  if (!course) return { ok: false, status: 404, message: 'Course not found' };
  const uid = userId.toString();
  if (course.instructor_id?.toString() === uid) return { ok: true, course };
  const self = (course.coTeachers || []).find(t => t.userId?.toString() === uid);
  const isLead = (self?.role || '').toLowerCase() === 'lead' || (self?.role || '').toLowerCase() === 'lead instructor';
  if (isLead && (self.status ?? 'accepted') === 'accepted') return { ok: true, course };
  return { ok: false, status: 403, message: 'Only the course owner or Lead Instructor can manage co-teachers' };
}

// DELETE /courses/:id/co-teacher/:userId — remove a co-teacher
router.delete('/:id/co-teacher/:userId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const check = await assertCanManageCoTeachers(req.params.id, req.user.id);
    if (!check.ok) return res.status(check.status).json({ success: false, message: check.message });
    await Course.findByIdAndUpdate(toId(req.params.id), {
      $pull: { coTeachers: { userId: toId(req.params.userId) } },
    });
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// PUT /courses/:id/co-teacher/:userId/role — grant/change a co-teacher's role
// (e.g. promote to 'lead' so they can issue certificates and manage other co-teachers)
router.put('/:id/co-teacher/:userId/role', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const check = await assertCanManageCoTeachers(req.params.id, req.user.id);
    if (!check.ok) return res.status(check.status).json({ success: false, message: check.message });

    const role = ((req.body.role || '') + '').trim();
    if (!role) return res.status(400).json({ success: false, message: 'role is required' });

    const course = await Course.findById(toId(req.params.id));
    const entry = (course.coTeachers || []).find(t => t.userId?.toString() === req.params.userId);
    if (!entry) return res.status(404).json({ success: false, message: 'Co-teacher not found' });

    entry.role = role;
    await course.save();

    const Notification = require('../models/Notification');
    await Notification.create({
      userId: entry.userId,
      type: 'general',
      title: 'Role Updated',
      message: `Your role for "${course.title}" was changed to ${role}.`,
      data: { courseId: course._id, courseName: course.title },
    }).catch(() => {});

    res.json({ success: true, message: `Role updated to ${role}` });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// GET /courses/:id/instructors — list co-teachers for a course
router.get('/:id/instructors', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const course = await Course.findById(toId(req.params.id)).lean();
    if (!course) return res.status(404).json({ success: false, message: 'Not found' });
    const instructors = (course.coTeachers || []).map(t => ({
      _id: t.userId || t,
      name: t.name || '',
      email: t.email || '',
      role: t.role || 'normal',
    }));
    res.json({ success: true, instructors });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── COURSE FEEDBACK / REVIEWS ────────────────────────────────────────────────
// POST /courses/:id/reviews — enrolled student submits (or updates) a
// rating + written review for the course/instructor.
router.post('/:id/reviews', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const courseId = toId(req.params.id);
    if (!courseId) return res.status(400).json({ success: false, message: 'Invalid courseId' });

    const { rating, comment } = req.body;
    const stars = Math.round(Number(rating));
    if (!stars || stars < 1 || stars > 5) {
      return res.status(400).json({ success: false, message: 'Rating must be 1–5' });
    }

    const studentId = toId(req.user.id);
    const enrollment = await Enrollment.findOne({ userId: studentId, courseId }).lean();
    if (!enrollment) {
      return res.status(403).json({ success: false, message: 'You must be enrolled in this course to leave feedback' });
    }

    const course = await Course.findById(courseId).lean();
    if (!course) return res.status(404).json({ success: false, message: 'Course not found' });

    await CourseReview.findOneAndUpdate(
      { courseId, studentId },
      { courseId, studentId, instructorId: course.instructor_id, rating: stars, comment: comment || '' },
      { upsert: true, new: true }
    );

    // Notify instructor (best-effort — never blocks feedback submission)
    if (course.instructor_id) {
      try {
        const Notification = require('../models/Notification');
        const User = require('../models/User');
        const student = await User.findById(studentId).select('name username').lean();
        await Notification.create({
          userId: course.instructor_id,
          type: 'general',
          title: 'New Course Feedback',
          message: `${student?.name || student?.username || 'A student'} rated "${course.title}" ${stars}★`,
          data: { type: 'course_feedback', courseId: courseId.toString(), rating: stars },
        });
      } catch (_) {}
    }

    // Recompute the course's aggregate rating/count for display on course cards.
    const agg = await CourseReview.aggregate([
      { $match: { courseId } },
      { $group: { _id: null, avg: { $avg: '$rating' }, count: { $sum: 1 } } },
    ]);
    const avg = agg[0]?.avg || 0;
    const count = agg[0]?.count || 0;
    await Course.findByIdAndUpdate(courseId, { rating: Math.round(avg * 10) / 10, total_reviews: count });

    res.json({ success: true, message: 'Feedback submitted', rating: avg, totalReviews: count });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// GET /courses/:id/reviews — public: list reviews for a course
router.get('/:id/reviews', async (req, res) => {
  try {
    await connectMongoDB();
    const courseId = toId(req.params.id);
    if (!courseId) return res.json({ success: true, reviews: [] });

    const reviews = await CourseReview.find({ courseId })
      .populate('studentId', 'name username')
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();

    res.json({
      success: true,
      reviews: reviews.map(r => ({
        _id: r._id,
        studentName: r.studentId?.name || r.studentId?.username || 'Student',
        rating: r.rating,
        comment: r.comment,
        createdAt: r.createdAt,
      })),
      count: reviews.length,
    });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// GET /courses/reviews/my-courses — instructor: all feedback across their own courses
router.get('/reviews/my-courses', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const instructorId = toId(req.user.id);

    const reviews = await CourseReview.find({ instructorId })
      .populate('studentId', 'name username')
      .populate('courseId', 'title')
      .sort({ createdAt: -1 })
      .lean();

    res.json({
      success: true,
      reviews: reviews.map(r => ({
        _id: r._id,
        courseId: r.courseId?._id,
        courseTitle: r.courseId?.title || 'Course',
        studentName: r.studentId?.name || r.studentId?.username || 'Student',
        rating: r.rating,
        comment: r.comment,
        createdAt: r.createdAt,
      })),
      count: reviews.length,
    });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// ── Admin: manually lock / unlock a student's installment course ──────────────
// Lets an admin override the automatic installment lock (e.g. after a student
// pays out-of-band, or to freeze access). Progress/enrollment untouched — only
// the installmentLocked flag flips, exactly like the cron auto-lock.
async function setEnrollmentLock(req, res, locked) {
  try {
    await connectMongoDB();
    if ((req.user.role || '').toLowerCase() !== 'admin') {
      return res.status(403).json({ success: false, message: 'Admin only' });
    }
    const enrollment = await Enrollment.findById(req.params.id);
    if (!enrollment) return res.status(404).json({ success: false, message: 'Enrollment not found' });

    enrollment.installmentLocked = locked;
    enrollment.installmentLockedAt = locked ? new Date() : null;
    await enrollment.save();

    // Notify the student either way.
    try {
      const Notification = require('../models/Notification');
      const course = await Course.findById(enrollment.courseId).select('title').lean();
      await Notification.create({
        userId: enrollment.userId,
        type: 'payment',
        title: locked ? 'Course Locked' : 'Course Unlocked',
        message: locked
          ? `Your access to "${course?.title || 'your course'}" has been paused by the admin.`
          : `Your access to "${course?.title || 'your course'}" has been restored by the admin.`,
        data: { subType: locked ? 'admin_locked' : 'admin_unlocked', courseId: enrollment.courseId, enrollmentId: enrollment._id },
      });
    } catch (_) {}

    res.json({ success: true, installmentLocked: enrollment.installmentLocked });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
}

router.post('/admin/enrollment/:id/lock', authMiddleware, (req, res) => setEnrollmentLock(req, res, true));
router.post('/admin/enrollment/:id/unlock', authMiddleware, (req, res) => setEnrollmentLock(req, res, false));

// POST /api/courses/admin/reset-student-progress
// Admin-only bulk reset used when a cohort must retake a course: deletes their
// certificates and zeroes progress, keeping the enrollment so students can
// restart immediately without re-purchasing.
//
// Defaults to a DRY RUN. Nothing is written unless the caller passes
// confirm:true, so the exact set of affected records can be reviewed first —
// certificates and progress are not recoverable once deleted.
//
// Body: {
//   emails: string[],              // students to reset
//   resetCourseTitle: string,      // course whose progress+certificate is cleared
//   unenrollCourseTitles?: string[],// courses to remove the student from entirely
//   confirm?: boolean              // false/absent = dry run
// }
router.post('/admin/reset-student-progress', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    if ((req.user.role || '').toLowerCase() !== 'admin') {
      return res.status(403).json({ success: false, message: 'Admin only' });
    }

    const { emails, resetCourseTitle, unenrollCourseTitles, unenrollCourseIds, confirm } = req.body || {};
    if (!Array.isArray(emails) || emails.length === 0) {
      return res.status(400).json({ success: false, message: 'emails[] is required' });
    }
    if (!resetCourseTitle) {
      return res.status(400).json({ success: false, message: 'resetCourseTitle is required' });
    }

    const User = require('../models/User');
    const Certificate = require('../models/Certificate');

    const esc = (s) => String(s).trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const findCourseByTitle = async (title) => Course.findOne({
      title: { $regex: `^${esc(title)}$`, $options: 'i' },
    }).select('_id title').lean();

    const resetCourse = await findCourseByTitle(resetCourseTitle);
    if (!resetCourse) {
      return res.status(404).json({ success: false, message: `Course not found: ${resetCourseTitle}` });
    }

    // Titles are not unique — the same name can exist on several Course
    // documents (a re-created or duplicated course keeps its old name). A
    // findOne here matched only one of them, so a student enrolled in a
    // different course of the SAME name was reported "not enrolled" and
    // silently skipped. Match every course sharing the title instead.
    const unenrollCourses = [];
    for (const t of (unenrollCourseTitles || [])) {
      const matches = await Course.find({
        title: { $regex: `^${esc(t)}$`, $options: 'i' },
      }).select('_id title').lean();
      if (matches.length) unenrollCourses.push(...matches);
      else unenrollCourses.push({ _id: null, title: t, notFound: true });
    }
    // Explicit ids win over title guessing when the caller already knows
    // exactly which course document to detach.
    for (const id of (unenrollCourseIds || [])) {
      const cid = toId(id);
      if (!cid) { unenrollCourses.push({ _id: null, title: String(id), notFound: true }); continue; }
      const c = await Course.findById(cid).select('_id title').lean();
      unenrollCourses.push(c || { _id: cid, title: `(course ${id} — no longer exists)` });
    }

    const report = [];
    for (const rawEmail of emails) {
      const email = String(rawEmail).trim().toLowerCase();
      const user = await User.findOne({ email: { $regex: `^${email.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, $options: 'i' } })
        .select('_id name email').lean();
      if (!user) {
        report.push({ email, found: false, note: 'No user with this email' });
        continue;
      }

      const enrollment = await Enrollment.findOne({ userId: user._id, courseId: resetCourse._id })
        .select('_id progress moduleCompletions lessonCompletions isCompleted').lean();
      const certs = await Certificate.find({ studentId: user._id, courseId: resetCourse._id })
        .select('_id certificateNumber approvalStatus issuedAt').lean();

      const unenrollHits = [];
      for (const c of unenrollCourses) {
        if (!c._id) { unenrollHits.push({ title: c.title, notFound: true }); continue; }
        const e = await Enrollment.findOne({ userId: user._id, courseId: c._id }).select('_id').lean();
        unenrollHits.push({ title: c.title, enrolled: !!e, enrollmentId: e?._id });
      }

      const entry = {
        email: user.email,
        name: user.name,
        userId: user._id,
        resetCourse: {
          title: resetCourse.title,
          enrolled: !!enrollment,
          currentProgress: enrollment
            ? {
                completedVideos: enrollment.progress?.completedVideos ?? 0,
                quizResults: (enrollment.progress?.quizResults || []).length,
                modulesCompleted: (enrollment.moduleCompletions || []).length,
                lessonsCompleted: (enrollment.lessonCompletions || []).length,
                isCompleted: !!enrollment.isCompleted,
              }
            : null,
        },
        certificatesToDelete: certs.map(c => ({
          id: c._id,
          number: c.certificateNumber,
          approvalStatus: c.approvalStatus,
          issuedAt: c.issuedAt,
        })),
        unenrollFrom: unenrollHits,
      };

      if (confirm === true) {
        const actions = [];
        if (certs.length) {
          await Certificate.deleteMany({ studentId: user._id, courseId: resetCourse._id });
          actions.push(`deleted ${certs.length} certificate(s)`);
        }
        if (enrollment) {
          await Enrollment.updateOne(
            { _id: enrollment._id },
            {
              $set: {
                'progress.completedVideos': 0,
                'progress.quizResults': [],
                'progress.completed': false,
                moduleCompletions: [],
                lessonCompletions: [],
                isCompleted: false,
              },
              $unset: { completedAt: '' },
            },
          );
          actions.push('progress reset to 0');
        }
        for (const h of unenrollHits) {
          if (h.enrolled && h.enrollmentId) {
            await Enrollment.deleteOne({ _id: h.enrollmentId });
            actions.push(`unenrolled from "${h.title}"`);
          }
        }
        entry.applied = actions;
      }

      report.push(entry);
    }

    res.json({
      success: true,
      dryRun: confirm !== true,
      message: confirm === true
        ? 'Changes applied.'
        : 'DRY RUN — nothing was changed. Re-send with confirm:true to apply.',
      resetCourse: resetCourse.title,
      report,
    });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// POST /api/courses/admin/list-student-enrollments
// Admin-only, read-only. Lists every course each given student is enrolled in,
// so unwanted enrollments can be identified before anything is deleted —
// unlike the reset route, this never needs course titles supplied up front.
// Body: { emails: string[] }
router.post('/admin/list-student-enrollments', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    if ((req.user.role || '').toLowerCase() !== 'admin') {
      return res.status(403).json({ success: false, message: 'Admin only' });
    }
    const { emails } = req.body || {};
    if (!Array.isArray(emails) || emails.length === 0) {
      return res.status(400).json({ success: false, message: 'emails[] is required' });
    }

    const User = require('../models/User');
    const esc = (s) => String(s).trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const report = [];

    for (const rawEmail of emails) {
      const email = String(rawEmail).trim().toLowerCase();
      const user = await User.findOne({ email: { $regex: `^${esc(email)}$`, $options: 'i' } })
        .select('_id name email').lean();
      if (!user) {
        report.push({ email, found: false, note: 'No user with this email' });
        continue;
      }
      const enrollments = await Enrollment.find({ userId: user._id })
        .select('_id courseId isCompleted moduleCompletions lessonCompletions createdAt').lean();
      const courses = await Course.find({ _id: { $in: enrollments.map(e => e.courseId) } })
        .select('_id title').lean();
      const titleById = new Map(courses.map(c => [c._id.toString(), c.title]));

      report.push({
        email: user.email,
        name: user.name,
        userId: user._id,
        enrollmentCount: enrollments.length,
        enrollments: enrollments.map(e => ({
          enrollmentId: e._id,
          courseId: e.courseId,
          courseTitle: titleById.get(e.courseId?.toString()) || '(course deleted)',
          isCompleted: !!e.isCompleted,
          modulesCompleted: (e.moduleCompletions || []).length,
          lessonsCompleted: (e.lessonCompletions || []).length,
          enrolledAt: e.createdAt,
        })),
      });
    }

    res.json({ success: true, report });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// POST /api/courses/admin/purge-orphan-enrollments
// Admin-only. Deletes enrollments whose course no longer exists. These can't
// be removed by title (the Course document is gone, so there is no title to
// match), yet they still count toward a student's course list. Dry run by
// default, same as the reset route.
// Body: { emails: string[], confirm?: boolean }
router.post('/admin/purge-orphan-enrollments', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    if ((req.user.role || '').toLowerCase() !== 'admin') {
      return res.status(403).json({ success: false, message: 'Admin only' });
    }
    const { emails, confirm } = req.body || {};
    if (!Array.isArray(emails) || emails.length === 0) {
      return res.status(400).json({ success: false, message: 'emails[] is required' });
    }

    const User = require('../models/User');
    const esc = (s) => String(s).trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const report = [];

    for (const rawEmail of emails) {
      const email = String(rawEmail).trim().toLowerCase();
      const user = await User.findOne({ email: { $regex: `^${esc(email)}$`, $options: 'i' } })
        .select('_id name email').lean();
      if (!user) {
        report.push({ email, found: false, note: 'No user with this email' });
        continue;
      }
      const enrollments = await Enrollment.find({ userId: user._id }).select('_id courseId').lean();
      const existing = await Course.find({ _id: { $in: enrollments.map(e => e.courseId) } })
        .select('_id').lean();
      const existingIds = new Set(existing.map(c => c._id.toString()));
      const orphans = enrollments.filter(e => !existingIds.has(e.courseId?.toString()));

      const entry = {
        email: user.email,
        name: user.name,
        orphanCount: orphans.length,
        orphans: orphans.map(o => ({ enrollmentId: o._id, missingCourseId: o.courseId })),
      };
      if (confirm === true && orphans.length) {
        await Enrollment.deleteMany({ _id: { $in: orphans.map(o => o._id) } });
        entry.applied = `deleted ${orphans.length} orphan enrollment(s)`;
      }
      report.push(entry);
    }

    res.json({
      success: true,
      dryRun: confirm !== true,
      message: confirm === true ? 'Orphans deleted.' : 'DRY RUN — re-send with confirm:true to apply.',
      report,
    });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;
