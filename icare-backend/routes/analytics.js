// ── LMS analytics ─────────────────────────────────────────────────────────────
// Student-facing learning metrics for the dashboard cards. Everything here is
// derived from data we already store (enrollments' lessonCompletions +
// QuizAttempt rows) — no new tracking fields, so it works retroactively for
// students who were already enrolled before this endpoint existed.
const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/auth');
const { connectMongoDB } = require('../config/mongodb');
const Enrollment = require('../models/Enrollment');
const Course = require('../models/Course');
const QuizAttempt = require('../models/QuizAttempt');

// Rough minutes-per-lesson used to turn "lessons completed" into a readable
// "time spent" figure. We don't record real watch time anywhere, so this is an
// explicit estimate rather than a fake precise number.
const MINUTES_PER_LESSON = 10;

// GET /api/analytics/student-stats
// Returns the three headline learning metrics plus the raw counts behind them
// (handy for debugging and for any future UI that wants the detail).
router.get('/student-stats', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const userId = req.user.id;

    const enrollments = await Enrollment.find({ userId }).lean();

    if (!enrollments.length) {
      return res.json({
        success: true,
        analytics: {
          engagementRate: '0%',
          avgQuizScore: '0%',
          timeSpent: '0 hrs',
          completedLessons: 0,
          totalLessons: 0,
          quizAttempts: 0,
          coursesEnrolled: 0,
        },
      });
    }

    // ── Engagement rate = lessons completed / lessons available, across every
    // course the student is enrolled in.
    const courseIds = enrollments.map((e) => e.courseId).filter(Boolean);
    const courses = await Course.find({ _id: { $in: courseIds } })
      .select('modules')
      .lean();

    let totalLessons = 0;
    for (const course of courses) {
      for (const mod of course.modules || []) {
        totalLessons += (mod.lessons || []).length;
      }
    }

    let completedLessons = 0;
    for (const enr of enrollments) {
      completedLessons += (enr.lessonCompletions || []).length;
    }

    const engagementRate =
      totalLessons > 0
        ? Math.min(100, Math.round((completedLessons / totalLessons) * 100))
        : 0;

    // ── Average quiz score across all of this student's graded attempts.
    const attempts = await QuizAttempt.find({ studentId: userId })
      .select('percentage')
      .lean();

    const scored = attempts.filter((a) => typeof a.percentage === 'number');
    const avgQuizScore = scored.length
      ? Math.round(scored.reduce((sum, a) => sum + a.percentage, 0) / scored.length)
      : 0;

    // ── Time spent — estimated from completed lessons (see MINUTES_PER_LESSON).
    const totalMinutes = completedLessons * MINUTES_PER_LESSON;
    const hours = totalMinutes / 60;
    const timeSpent =
      hours >= 1 ? `${hours.toFixed(1)} hrs` : `${totalMinutes} min`;

    res.json({
      success: true,
      analytics: {
        engagementRate: `${engagementRate}%`,
        avgQuizScore: `${avgQuizScore}%`,
        timeSpent,
        completedLessons,
        totalLessons,
        quizAttempts: attempts.length,
        coursesEnrolled: enrollments.length,
      },
    });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

// GET /api/analytics/instructor-stats
// The Flutter AnalyticsService already calls this path; it previously 404'd
// (silently swallowed into an empty map). Aggregates across the instructor's
// own courses.
router.get('/instructor-stats', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const instructorId = req.user.id;

    const courses = await Course.find({ instructor_id: instructorId })
      .select('_id title modules rating total_reviews')
      .lean();

    if (!courses.length) {
      return res.json({
        success: true,
        analytics: {
          totalCourses: 0,
          totalStudents: 0,
          avgCompletionRate: '0%',
          avgRating: '0.0',
        },
      });
    }

    const courseIds = courses.map((c) => c._id);
    const enrollments = await Enrollment.find({ courseId: { $in: courseIds } })
      .select('userId courseId lessonCompletions isCompleted')
      .lean();

    // Unique students across all of this instructor's courses.
    const uniqueStudents = new Set(enrollments.map((e) => e.userId?.toString()));

    // Completion rate = enrollments flagged complete / total enrollments.
    const completedCount = enrollments.filter((e) => e.isCompleted).length;
    const avgCompletionRate = enrollments.length
      ? Math.round((completedCount / enrollments.length) * 100)
      : 0;

    // Rating averaged over courses that actually have reviews.
    const rated = courses.filter((c) => (c.total_reviews || 0) > 0);
    const avgRating = rated.length
      ? (rated.reduce((sum, c) => sum + (c.rating || 0), 0) / rated.length).toFixed(1)
      : '0.0';

    res.json({
      success: true,
      analytics: {
        totalCourses: courses.length,
        totalStudents: uniqueStudents.size,
        avgCompletionRate: `${avgCompletionRate}%`,
        avgRating: String(avgRating),
        totalEnrollments: enrollments.length,
      },
    });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
});

module.exports = router;
