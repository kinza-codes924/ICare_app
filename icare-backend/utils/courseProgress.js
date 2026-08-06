const Course = require('../models/Course');
const Quiz = require('../models/Quiz');
const QuizAttempt = require('../models/QuizAttempt');
const AssignmentSubmission = require('../models/AssignmentSubmission');
const { sendEmail } = require('./email');

// Re-evaluates whether `moduleId` (and, transitively, the whole course) should
// be marked complete for this enrollment. A module counts as complete only
// when ALL of the following hold:
//   - every real content lesson (module.lessons entries NOT of type
//     'assignment'/'live' — those are reference entries, not watchable
//     content) is in enrollment.lessonCompletions
//   - every assignment-type entry in module.lessons has a submitted
//     AssignmentSubmission from this student (previously not checked at
//     all here, which is why a module could "complete" via the manual
//     button without the assignment ever being submitted)
//   - every published quiz tied to the module (Quiz.moduleId) has a passed
//     QuizAttempt for this student
// Mutates enrollment.moduleCompletions / isCompleted / completedAt in place
// but does NOT save — callers save the enrollment themselves. Safe to call
// repeatedly; only appends when not already present (won't create duplicate
// completions or bump completedAt on an already-completed enrollment).
async function recheckModuleCompletion(enrollment, moduleId) {
  if (!moduleId) return;
  const course = await Course.findById(enrollment.courseId).lean();
  if (!course) return;
  const module = (course.modules || []).find(m => m._id?.toString() === moduleId);
  if (!module) return;

  const lessons = module.lessons || [];
  // Quiz-type entries are reference rows, not watchable/completable content —
  // passing one is tracked via QuizAttempt (checked below), never via
  // lessonCompletions. Without this exclusion, a quiz embedded in a module's
  // lessons[] counted as a required "content lesson" that could never be
  // satisfied (nothing ever calls complete-lesson for a quiz), so the module
  // stayed permanently incomplete even after the quiz was passed and every
  // real lesson was marked done.
  const contentLessonIds = lessons
    .filter(l => !['assignment', 'live', 'quiz'].includes(l.type || 'content'))
    .map(l => l._id?.toString()).filter(Boolean);
  const assignmentLessonIds = lessons
    .filter(l => l.type === 'assignment')
    .map(l => l._id?.toString()).filter(Boolean);
  // Live sessions can't require an explicit "Mark Complete" tap (there's no
  // watchable content to finish) so they'd otherwise block the module
  // forever. Once the scheduled slot has fully elapsed, auto-record it as
  // completed here — time-based, not attendance-based, matching how a
  // missed/skipped session still isn't meant to permanently lock a student
  // out of the rest of the course.
  const liveLessons = lessons.filter(l => l.type === 'live');
  const now = new Date();
  for (const l of liveLessons) {
    const lid = l._id?.toString();
    if (!lid) continue;
    const already = (enrollment.lessonCompletions || []).some(lc => lc.lessonId === lid);
    if (already) continue;
    const scheduledAt = l.liveSessionDateTime || l.scheduledAt;
    if (!scheduledAt) continue;
    const endTime = new Date(new Date(scheduledAt).getTime() + (Number(l.duration || l.duration_minutes) || 0) * 60000);
    if (endTime <= now) {
      if (!enrollment.lessonCompletions) enrollment.lessonCompletions = [];
      enrollment.lessonCompletions.push({ lessonId: lid, moduleId, completedAt: new Date() });
    }
  }

  const completedLessonIds = new Set((enrollment.lessonCompletions || []).map(lc => lc.lessonId));
  const liveLessonIds = liveLessons.map(l => l._id?.toString()).filter(Boolean);
  const allLessonsDone = contentLessonIds.every(id => completedLessonIds.has(id)) &&
    liveLessonIds.every(id => completedLessonIds.has(id));

  let allAssignmentsSubmitted = true;
  if (assignmentLessonIds.length) {
    const submissions = await AssignmentSubmission.find({
      assignmentId: { $in: assignmentLessonIds },
      studentId: enrollment.userId,
    }).select('assignmentId').lean();
    const submittedIds = new Set(submissions.map(s => s.assignmentId.toString()));
    allAssignmentsSubmitted = assignmentLessonIds.every(id => submittedIds.has(id));
  }

  const moduleQuizzes = await Quiz.find({ courseId: enrollment.courseId, moduleId, isPublished: true }).select('_id').lean();
  let allQuizzesPassed = true;
  if (moduleQuizzes.length) {
    const passedAttempts = await QuizAttempt.find({
      studentId: enrollment.userId,
      quizId: { $in: moduleQuizzes.map(q => q._id) },
      passed: true,
    }).select('quizId').lean();
    const passedQuizIds = new Set(passedAttempts.map(a => a.quizId.toString()));
    allQuizzesPassed = moduleQuizzes.every(q => passedQuizIds.has(q._id.toString()));
  }

  if (allLessonsDone && allAssignmentsSubmitted && allQuizzesPassed) {
    const alreadyCompleted = (enrollment.moduleCompletions || []).find(mc => mc.moduleId === moduleId);
    if (!alreadyCompleted) {
      if (!enrollment.moduleCompletions) enrollment.moduleCompletions = [];
      enrollment.moduleCompletions.push({ moduleId, completedAt: new Date() });
    }
  }

  const wasCompleted = enrollment.isCompleted === true;
  const allModuleIds = (course.modules || []).map(m => m._id?.toString()).filter(Boolean);
  const completedModuleIds = new Set((enrollment.moduleCompletions || []).map(mc => mc.moduleId));
  if (allModuleIds.length && allModuleIds.every(id => completedModuleIds.has(id))) {
    enrollment.isCompleted = true;
    enrollment.completedAt = enrollment.completedAt || new Date();
  }

  // Tells the caller whether the course JUST became fully complete on this
  // call (as opposed to having already been complete) — used to fire a
  // one-time "ready to certify" notification to the Lead Instructor instead
  // of re-notifying on every subsequent lesson/quiz touch.
  return { justCompletedCourse: !wasCompleted && enrollment.isCompleted === true };
}

// GET /courses/:id's refresh loop only calls recheckModuleCompletion for
// modules NOT already in moduleCompletions (skipping ones already marked
// done) — so if every module had already been individually completed
// across earlier visits, the loop calls recheckModuleCompletion zero times
// on this pass, and the whole-course isCompleted flag (only set inside that
// function) never gets (re)evaluated even though every module genuinely is
// done. That silently blocked "Issue Certificate" from ever appearing for
// such a student. This does the same cross-module check standalone, so the
// caller can run it unconditionally after the loop regardless of whether
// any individual module needed rechecking this pass.
async function recheckCourseCompletion(enrollment) {
  if (enrollment.isCompleted === true) return { justCompletedCourse: false };
  const course = await Course.findById(enrollment.courseId).select('modules').lean();
  if (!course) return { justCompletedCourse: false };
  const allModuleIds = (course.modules || []).map(m => m._id?.toString()).filter(Boolean);
  if (!allModuleIds.length) return { justCompletedCourse: false };
  const completedModuleIds = new Set((enrollment.moduleCompletions || []).map(mc => mc.moduleId));
  if (allModuleIds.every(id => completedModuleIds.has(id))) {
    enrollment.isCompleted = true;
    enrollment.completedAt = enrollment.completedAt || new Date();
    return { justCompletedCourse: true };
  }
  return { justCompletedCourse: false };
}

// Notifies the Lead Instructor (course owner, or the co-teacher with role
// 'lead'/'lead instructor') that a student finished every module and is
// ready to be issued a certificate. Fired once, right when the course
// transitions to isCompleted — see recheckModuleCompletion's
// justCompletedCourse flag, which callers pass in here. Shared by both the
// lesson-completion and quiz-submission routes (courses.js, quizzes.js) —
// a course can just as easily finish on its last quiz as its last lesson.
async function notifyLeadInstructorCourseComplete(enrollment) {
  try {
    const course = await Course.findById(enrollment.courseId).select('title instructor_id coTeachers').lean();
    if (!course) return;
    const User = require('../models/User');
    const Notification = require('../models/Notification');
    const student = await User.findById(enrollment.userId).select('name username').lean();

    const leadCoTeacher = (course.coTeachers || []).find(t => {
      const roleLower = (t.role || '').toLowerCase();
      return (roleLower === 'lead' || roleLower === 'lead instructor') && (t.status ?? 'accepted') === 'accepted';
    });
    const leadUserId = leadCoTeacher?.userId || course.instructor_id;
    if (!leadUserId) return;

    const lead = await User.findById(leadUserId).select('name email').lean();
    const studentName = student?.name || student?.username || 'A student';

    await Notification.create({
      userId: leadUserId,
      type: 'general',
      title: 'Certificate Ready to Issue',
      message: `${studentName} completed all modules in "${course.title}" — issue their certificate.`,
      data: { type: 'certificate_ready', courseId: course._id, enrollmentId: enrollment._id, studentId: enrollment.userId },
    });

    if (lead?.email) {
      sendEmail({
        to: lead.email,
        subject: `Certificate ready to issue: ${course.title}`,
        html: `<p>Hi ${lead.name || 'Instructor'},</p>
               <p><b>${studentName}</b> has completed every module in <b>"${course.title}"</b> and is ready for their certificate.</p>
               <p>Log in to iCare to review and issue it.</p>
               <p>— iCare LMS Team</p>`,
      }).catch(() => {});
    }
  } catch (_) { /* notification failure should not break the response */ }
}

module.exports = { recheckModuleCompletion, recheckCourseCompletion, notifyLeadInstructorCourseComplete };
