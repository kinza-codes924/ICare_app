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
});

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
  modules: [moduleSchema],
  assigned_to: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  is_active: { type: Boolean, default: true },
  rating: { type: Number, default: 0 },
  total_reviews: { type: Number, default: 0 },
  // Instructor must explicitly release certificate before students can download
  certificateReleased: { type: Boolean, default: false },
  certificateTemplate: { type: String, default: 'classic' },
}, { timestamps: true });

// No pre-save hooks — sync logic is handled in route handlers

module.exports = mongoose.models.Course || mongoose.model('Course', courseSchema);
// Mon Apr 27 01:48:00 PST 2026
