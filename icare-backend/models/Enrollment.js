const mongoose = require('mongoose');

const enrollmentSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  courseId: { type: mongoose.Schema.Types.ObjectId, ref: 'Course', required: true },
  progress: {
    completedVideos: { type: Number, default: 0 },
    quizResults: { type: Array, default: [] },
    completed: { type: Boolean, default: false },
    completedAt: { type: Date },
  },
  // Track module completions with timestamps
  moduleCompletions: [{
    moduleId: { type: String, required: true },
    completedAt: { type: Date, default: Date.now },
  }],
  // Track individual lesson completions for per-lesson progress
  lessonCompletions: [{
    lessonId: { type: String, required: true },
    moduleId: { type: String },
    completedAt: { type: Date, default: Date.now },
  }],
  isCompleted: { type: Boolean, default: false },
  completedAt: { type: Date },
  certificateUrl: { type: String },
  // Payment/voucher tracking — set when a voucher was applied at checkout
  voucherCode: { type: String, default: null },
  amountPaid: { type: Number, default: null },

  // Installment plan state — populated once at first purchase if the course had
  // installmentPlanEnabled at that time. Immutable per-enrollment even if the
  // instructor later changes the course's plan (in-flight students keep their
  // original schedule).
  installmentPlanEnabled: { type: Boolean, default: false },
  installments: [{
    index: { type: Number, required: true },
    amount: { type: Number, required: true },
    dueDate: { type: Date, required: true },
    status: { type: String, enum: ['pending', 'paid', 'overdue'], default: 'pending' },
    paidAt: { type: Date, default: null },
    paymentId: { type: mongoose.Schema.Types.ObjectId, ref: 'Payment', default: null },
    // Cron idempotency flags — never re-send the same reminder/lock notice twice.
    dueReminderSentAt: { type: Date, default: null },
    overdueLockNotifiedAt: { type: Date, default: null },
  }],
  installmentLocked: { type: Boolean, default: false },
  installmentLockedAt: { type: Date, default: null },
}, { timestamps: true });

// One enrollment per user per course
enrollmentSchema.index({ userId: 1, courseId: 1 }, { unique: true });

module.exports = mongoose.models.Enrollment || mongoose.model('Enrollment', enrollmentSchema);
