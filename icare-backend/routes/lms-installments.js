// ── CRON: Process LMS course installments ─────────────────────────────────────
// Called daily by Vercel cron (GET) or manually (POST, with ?secret= or the
// x-cron-secret header). Two responsibilities in one pass:
//   (A) send a "due" reminder (in-app + email) the first time an installment's
//       dueDate has arrived and it's still pending
//   (B) auto-lock a course 3 days after an installment's own due date passes
//       unpaid — short enough to not leave the course unlocked for weeks,
//       long enough to absorb a genuine bank/payment delay.
// Idempotent: dueReminderSentAt / installmentLocked flags are checked before
// acting, so re-running the same day never double-sends/double-locks.
const express = require('express');
const router = express.Router();
const { connectMongoDB } = require('../config/mongodb');
const Enrollment = require('../models/Enrollment');
const Course = require('../models/Course');
const User = require('../models/User');
const Notification = require('../models/Notification');
const { sendEmail } = require('../utils/email');

async function handleProcessInstallments(req, res) {
  const cronSecret = req.headers['x-cron-secret'] || req.query.secret;
  if (cronSecret !== process.env.CRON_SECRET && process.env.CRON_SECRET) {
    return res.status(403).json({ success: false, message: 'Forbidden' });
  }
  try {
    await connectMongoDB();
    const now = new Date();

    // ── Part A: due-date reminders ──────────────────────────────────────────
    const dueForReminder = await Enrollment.find({
      installmentPlanEnabled: true,
      installments: { $elemMatch: { status: 'pending', dueDate: { $lte: now }, dueReminderSentAt: null } },
    });

    let remindersSent = 0;
    for (const enr of dueForReminder) {
      const course = await Course.findById(enr.courseId).select('title').lean();
      const student = await User.findById(enr.userId).select('email name').lean();
      const pendingDue = enr.installments.filter(
        (i) => i.status === 'pending' && new Date(i.dueDate) <= now && !i.dueReminderSentAt
      );
      for (const inst of pendingDue) {
        await Notification.create({
          userId: enr.userId, type: 'payment',
          title: 'Installment Due',
          message: `Installment ${inst.index} of ${enr.installments.length} for "${course?.title || 'your course'}" is now due.`,
          data: { subType: 'installment_due', courseId: enr.courseId, enrollmentId: enr._id, installmentIndex: inst.index, amount: inst.amount },
        }).catch(() => {});
        if (student?.email) {
          sendEmail({
            to: student.email,
            subject: `Installment ${inst.index} due — ${course?.title || 'Your Course'}`,
            html: `<p>Hi ${student.name || 'Student'},</p><p>Installment ${inst.index} of ${enr.installments.length} (PKR ${inst.amount}) for <b>${course?.title || ''}</b> is now due. Please pay within 1 month to keep your course unlocked.</p>`,
          }).catch(() => {});
        }
        inst.dueReminderSentAt = now;
        remindersSent++;
      }
      await enr.save();
    }

    // ── Part B: auto-lock overdue installments ──────────────────────────────
    const candidates = await Enrollment.find({
      installmentPlanEnabled: true,
      installmentLocked: false,
      installments: { $elemMatch: { status: 'pending' } },
    });

    let locked = 0;
    for (const enr of candidates) {
      const pending = enr.installments.filter((i) => i.status === 'pending').sort((a, b) => a.index - b.index);
      if (!pending.length) continue;
      const firstPending = pending[0];
      // 3-day grace after the installment's own due date — covers genuine
      // bank/payment delays without leaving the course unlocked for a full
      // month past the due date.
      const graceDeadline = new Date(new Date(firstPending.dueDate).getTime() + 3 * 24 * 60 * 60 * 1000);
      if (now < graceDeadline) continue;

      firstPending.status = 'overdue';
      firstPending.overdueLockNotifiedAt = now;
      enr.installmentLocked = true;
      enr.installmentLockedAt = now;
      await enr.save();

      const course = await Course.findById(enr.courseId).select('title').lean();
      const student = await User.findById(enr.userId).select('email name').lean();
      await Notification.create({
        userId: enr.userId, type: 'payment',
        title: 'Course Locked — Installment Overdue',
        message: `Your access to "${course?.title || 'your course'}" has been paused because installment ${firstPending.index} was not paid in time. Pay now to unlock.`,
        data: { subType: 'installment_locked', courseId: enr.courseId, enrollmentId: enr._id, installmentIndex: firstPending.index },
      }).catch(() => {});
      if (student?.email) {
        sendEmail({
          to: student.email,
          subject: `Course locked — ${course?.title || 'installment overdue'}`,
          html: `<p>Hi ${student.name || 'Student'},</p><p>Your access to <b>${course?.title || ''}</b> has been paused because installment ${firstPending.index} was not paid within the grace period. Your progress is saved — pay the overdue installment to restore access immediately.</p>`,
        }).catch(() => {});
      }
      locked++;
    }

    res.json({ success: true, remindersSent, locked, checked: dueForReminder.length + candidates.length });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
}

router.get('/process', handleProcessInstallments);
router.post('/process', handleProcessInstallments);

module.exports = router;
