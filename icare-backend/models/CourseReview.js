const mongoose = require('mongoose');

const courseReviewSchema = new mongoose.Schema({
  courseId: { type: mongoose.Schema.Types.ObjectId, ref: 'Course', required: true },
  studentId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  instructorId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  rating: { type: Number, required: true, min: 1, max: 5 },
  comment: { type: String, default: '' },
}, { timestamps: true });

// One review per student per course — resubmitting updates the existing one.
courseReviewSchema.index({ courseId: 1, studentId: 1 }, { unique: true });

module.exports = mongoose.models.CourseReview || mongoose.model('CourseReview', courseReviewSchema);
