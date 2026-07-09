const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
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
const CourseReview = require('../models/CourseReview');
const { Voucher, applyVoucherDiscount } = require('./vouchers');

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

    const Attendance = require('../models/Attendance');
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
    // Populate course data
    const courseIds = enrollments.map(e => e.courseId);
    const courses = await Course.find({ _id: { $in: courseIds } }).lean();
    const courseMap = {};
    courses.forEach(c => { courseMap[c._id.toString()] = c; });
    const items = await Promise.all(enrollments.map(async (e) => {
      const { progressPct } = await computeProgress(e);
      return {
        ...e,
        course: courseMap[e.courseId.toString()] || null,
        progress: { ...e.progress, percent: progressPct },
      };
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

// GET /api/courses/:id — get single course
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const course = await Course.findById(toId(req.params.id)).lean();
    if (!course) return res.status(404).json({ success: false, message: 'Course not found' });

    // Attach module unlock info for student view
    const now = new Date();
    const enrollment = await Enrollment.findOne({ userId: toId(req.user.id), courseId: course._id }).lean();
    const completedModuleIds = new Set((enrollment?.moduleCompletions || []).map(m => m.moduleId));

    // Gate full module/lesson content behind enrollment (or ownership) —
    // browsing the catalog / course-detail preview only needs title,
    // description, pricing, etc.; the actual modules array (videos,
    // documents, live-session links) should only go to the instructor who
    // owns the course or a student who has actually enrolled.
    const uid = req.user.id?.toString();
    const isOwner = course.instructor_id?.toString() === uid
      || (course.coTeachers || []).some(t => t.userId?.toString() === uid);
    if (!enrollment && !isOwner) {
      return res.json({ success: true, course: { ...course, modules: [], enrollmentId: null, locked: true } });
    }

    course.modules = (course.modules || []).map((mod, idx) => {
      let isLocked = false;
      let unlockDate = null;

      if (course.courseType === 'pragmatic' && course.startDate) {
        // Pragmatic: unlock only on scheduled date
        const days = mod.unlockAfterDays || 0;
        const unlock = new Date(course.startDate);
        unlock.setDate(unlock.getDate() + days);
        unlockDate = unlock.toISOString();
        isLocked = now < unlock;
      } else if (course.courseType === 'self-paced' && idx > 0) {
        // Self-paced: previous module must be completed
        const prevMod = course.modules[idx - 1];
        const prevId = prevMod?._id?.toString();
        isLocked = prevId ? !completedModuleIds.has(prevId) : false;
      }

      return { ...mod, isLocked, unlockDate };
    });

    course.enrollmentId = enrollment?._id?.toString() || null;
    course.completedModuleIds = [...completedModuleIds];
    res.json({ success: true, course });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// POST /api/courses — create course (instructor)
// Create LiveSession docs for any lessons that have a liveSessionDateTime
async function syncLiveSessions(courseId, instructorId, modules) {
  if (!Array.isArray(modules)) return;
  for (const mod of modules) {
    for (const lesson of (mod.lessons || [])) {
      if (!lesson.liveSessionDateTime) continue;
      const scheduledAt = new Date(lesson.liveSessionDateTime);
      if (isNaN(scheduledAt)) continue;
      const lessonId = lesson._id?.toString() || lesson.id?.toString() || null;
      const modId = mod._id?.toString() || mod.id?.toString() || null;
      // Upsert by courseId + linkedLessonId so we don't create duplicates on edit
      const filter = { courseId: toId(courseId), linkedLessonId: lessonId || lesson.title };
      const update = {
        $set: {
          courseId: toId(courseId),
          instructorId: toId(instructorId),
          title: lesson.liveSessionNote?.trim() || `Live: ${lesson.title || 'Session'}`,
          scheduledAt,
          linkedLessonId: lessonId || lesson.title,
          linkedModuleId: modId || mod.title,
          status: 'scheduled',
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
    const course = await Course.create({ ...req.body, instructor_id: toId(req.user.id) });
    await syncLiveSessions(course._id, req.user.id, req.body.modules);
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
    await syncLiveSessions(course._id, req.user.id, req.body.modules);
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

    // Auto-complete module if all lessons in it are done
    if (moduleId) {
      const course = await Course.findById(enrollment.courseId).lean();
      if (course) {
        const module = (course.modules || []).find(m => m._id?.toString() === moduleId);
        if (module) {
          const moduleLessonIds = (module.lessons || []).map(l => l._id?.toString()).filter(Boolean);
          const completedLessonIds = new Set((enrollment.lessonCompletions || []).map(lc => lc.lessonId));
          const allDone = moduleLessonIds.every(id => completedLessonIds.has(id));
          if (allDone) {
            const alreadyCompleted = (enrollment.moduleCompletions || []).find(mc => mc.moduleId === moduleId);
            if (!alreadyCompleted) {
              if (!enrollment.moduleCompletions) enrollment.moduleCompletions = [];
              enrollment.moduleCompletions.push({ moduleId, completedAt: new Date() });
            }
          }

          // Auto-complete course if all modules done
          const allModuleIds = (course.modules || []).map(m => m._id?.toString()).filter(Boolean);
          const completedModuleIds = new Set((enrollment.moduleCompletions || []).map(mc => mc.moduleId));
          if (allModuleIds.every(id => completedModuleIds.has(id))) {
            enrollment.isCompleted = true;
            enrollment.completedAt = enrollment.completedAt || new Date();
          }
        }
      }
    }

    await enrollment.save();

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

// POST /courses/:id/invite-teacher — invite co-teacher by email with role
router.post('/:id/invite-teacher', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { email, role } = req.body; // role: 'lead' | 'normal'
    if (!email) return res.status(400).json({ success: false, message: 'Email required' });

    const course = await Course.findById(toId(req.params.id)).lean();
    if (!course) return res.status(404).json({ success: false, message: 'Course not found' });

    const User = require('../models/User');
    const invitedUser = await User.findOne({ email: email.toLowerCase().trim() }).lean();

    if (!invitedUser) {
      return res.status(404).json({ success: false, message: `No user found with email: ${email}. They must register on iCare first.` });
    }

    const teacherRole = role === 'lead' ? 'lead' : 'normal';

    // Add as co-teacher with role if not already
    const existingEntry = (course.coTeachers || []).find(t => {
      const tid = t.userId ? t.userId.toString() : t.toString();
      return tid === invitedUser._id.toString();
    });
    if (existingEntry) return res.json({ success: true, message: 'This teacher is already in the course.' });

    await Course.findByIdAndUpdate(toId(req.params.id), {
      $addToSet: { coTeachers: { userId: invitedUser._id, role: teacherRole, name: invitedUser.name, email: invitedUser.email } }
    });

    // Send notification to invited teacher
    const Notification = require('../models/Notification');
    const inviter = await User.findById(req.user.id).lean();
    await Notification.create({
      userId: invitedUser._id,
      type: 'general',
      title: `${teacherRole === 'lead' ? 'Lead' : 'Co'}-Teacher Invitation`,
      message: `${inviter?.name || 'An instructor'} has invited you as ${teacherRole === 'lead' ? 'Lead' : 'Normal'} Instructor for "${course.title}"`,
      data: { courseId: course._id, courseName: course.title },
    }).catch(() => {});

    // Email the invited teacher
    sendEmail({
      to: invitedUser.email,
      subject: `You're invited to co-teach on iCare: ${course.title}`,
      html: `<p>Hi ${invitedUser.name || 'there'},</p>
             <p><b>${inviter?.name || 'An instructor'}</b> has invited you as <b>${teacherRole === 'lead' ? 'Lead' : 'Co'}-Teacher</b> for the course <b>"${course.title}"</b> on iCare LMS.</p>
             <p>Log in to your iCare instructor account — the course will now appear in your <b>My Courses</b> list.</p>
             <p>— iCare Team</p>`,
    }).catch(e => console.error('Co-teacher invite email failed:', e.message));

    res.json({ success: true, message: `Invitation sent to ${invitedUser.name || email}` });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// DELETE /courses/:id/co-teacher/:userId — remove a co-teacher
router.delete('/:id/co-teacher/:userId', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    await Course.findByIdAndUpdate(toId(req.params.id), {
      $pull: { coTeachers: { userId: toId(req.params.userId) } },
    });
    res.json({ success: true });
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

module.exports = router;
