const Course = require('../models/Course');
const Quiz = require('../models/Quiz');
const QuizAttempt = require('../models/QuizAttempt');

// Re-evaluates whether `moduleId` (and, transitively, the whole course) should
// be marked complete for this enrollment: every lesson in the module must be
// in enrollment.lessonCompletions AND every published quiz tied to the module
// (Quiz.moduleId) must have a passed QuizAttempt for this student. Mutates
// enrollment.moduleCompletions / isCompleted / completedAt in place but does
// NOT save — callers save the enrollment themselves. Safe to call repeatedly;
// only appends when not already present (won't create duplicate completions
// or bump completedAt on an already-completed enrollment).
async function recheckModuleCompletion(enrollment, moduleId) {
  if (!moduleId) return;
  const course = await Course.findById(enrollment.courseId).lean();
  if (!course) return;
  const module = (course.modules || []).find(m => m._id?.toString() === moduleId);
  if (!module) return;

  const moduleLessonIds = (module.lessons || []).map(l => l._id?.toString()).filter(Boolean);
  const completedLessonIds = new Set((enrollment.lessonCompletions || []).map(lc => lc.lessonId));
  const allLessonsDone = moduleLessonIds.every(id => completedLessonIds.has(id));

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

  if (allLessonsDone && allQuizzesPassed) {
    const alreadyCompleted = (enrollment.moduleCompletions || []).find(mc => mc.moduleId === moduleId);
    if (!alreadyCompleted) {
      if (!enrollment.moduleCompletions) enrollment.moduleCompletions = [];
      enrollment.moduleCompletions.push({ moduleId, completedAt: new Date() });
    }
  }

  const allModuleIds = (course.modules || []).map(m => m._id?.toString()).filter(Boolean);
  const completedModuleIds = new Set((enrollment.moduleCompletions || []).map(mc => mc.moduleId));
  if (allModuleIds.length && allModuleIds.every(id => completedModuleIds.has(id))) {
    enrollment.isCompleted = true;
    enrollment.completedAt = enrollment.completedAt || new Date();
  }
}

module.exports = { recheckModuleCompletion };
