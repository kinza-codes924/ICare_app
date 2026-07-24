const mongoose = require('mongoose');

const lessonSchema = new mongoose.Schema({
  title: String,
  content: { type: String, default: '' },
  videoUrl: String,          // Flutter sends videoUrl
  video_url: String,         // legacy alias
  duration: { type: Number, default: 0 },
  duration_minutes: { type: Number, default: 0 }, // legacy alias
  order: { type: Number, default: 0 },
  resources: { type: Array, default: [] },
  documentUrl: String,       // attached document
  documentName: String,
  driveLink: String,         // optional Google Drive link shown alongside the video
  // Timeline for pragmatic courses — days this lesson takes within its module
  unlockAfterDays: { type: Number, default: 0 },
  // Feature 2: live session scheduled for this lesson (reminder only, not auto-start)
  liveSessionDateTime: { type: Date, default: null },
  liveSessionNote: { type: String, default: '' },
}, { strict: false });

const moduleSchema = new mongoose.Schema({
  title: String,
  description: { type: String, default: '' },
  order: { type: Number, default: 0 },
  lessons: [lessonSchema],
  quiz: { type: mongoose.Schema.Types.Mixed, default: null },
  // Timeline for pragmatic courses (e.g., unlock after X days/weeks)
  unlockAfterDays: { type: Number, default: 0 },
});

const courseSchema = new mongoose.Schema({
  title: { type: String, required: true },
  description: { type: String, default: '' },

  // Cached Google Drive subfolder id for this course's recordings (created
  // automatically, named after the course, on first recording) — avoids a
  // Drive API lookup on every upload.
  driveFolderId: String,

  // Thumbnail — accept both field names
  thumbnail: String,
  thumbnail_url: String,

  // Category & audience
  category: { type: String, default: 'HealthProgram' },
  targetAudience: { type: String, default: 'Patient' },
  difficulty: { type: String, default: null },
  healthConditions: { type: [String], default: [] },

  // Duration in hours
  duration: { type: Number, default: 0 },

  // Course type: self-paced (immediate progression) or pragmatic (timeline-based)
  courseType: {
    type: String,
    enum: ['self-paced', 'pragmatic'],
    default: 'self-paced',
  },

  // Start date for pragmatic courses (timeline calculation base)
  startDate: { type: Date, default: null },

  // Visibility / publish status
  visibility: {
    type: String,
    enum: ['public', 'private', 'assigned'],
    default: 'private',
  },
  isPublished: { type: Boolean, default: false },

  instructor_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  // Co-instructors with role: lead | normal
  coTeachers: [{
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    name: String,
    email: String,
    role: { type: String, enum: ['lead', 'normal'], default: 'normal' },
  }],
  // Mark as RM Health Solutions / RMS UK course for public home display
  isRmsCourse: { type: Boolean, default: false },
  modules: [moduleSchema],
  assigned_to: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  is_active: { type: Boolean, default: true },
  rating: { type: Number, default: 0 },
  total_reviews: { type: Number, default: 0 },
  certificateReleased: { type: Boolean, default: false },
  certificateTemplate: { type: String, default: 'classic' },
  price: { type: Number, default: 0 },
  isFree: { type: Boolean, default: false },
  discountPercent: { type: Number, default: 0 },
  discountedPrice: { type: Number, default: 0 },

  // Early Bird: flat PKR amount off (not percent), active only until earlyBirdDeadline.
  // Applied on top of discountedPrice at payment/schedule time — never persisted as
  // a second "discounted" field, to avoid double-discount ambiguity.
  earlyBirdEnabled: { type: Boolean, default: false },
  earlyBirdAmount: { type: Number, default: 0 },
  earlyBirdDeadline: { type: Date, default: null },

  // Installment plan: manual per-payment, no saved-card auto-charge. The
  // instructor defines each installment explicitly — its amount and how many
  // days after enrollment it's due. Installment 1 is the purchase itself
  // (daysAfterEnrollment = 0). The amounts must sum to the effective (after
  // early-bird) course price — enforced in routes/courses.js on save.
  installmentPlanEnabled: { type: Boolean, default: false },
  installmentPlan: [{
    amount: { type: Number, required: true },
    daysAfterEnrollment: { type: Number, default: 0 },
  }],
}, { timestamps: true });

// No pre-save hooks — sync logic is handled in route handlers

module.exports = mongoose.models.Course || mongoose.model('Course', courseSchema);
// Mon Apr 27 01:48:00 PST 2026
