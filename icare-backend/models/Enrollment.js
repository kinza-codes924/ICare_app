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
  certificateUrl: { type: String },
}, { timestamps: true });

// One enrollment per user per course
enrollmentSchema.index({ userId: 1, courseId: 1 }, { unique: true });

module.exports = mongoose.models.Enrollment || mongoose.model('Enrollment', enrollmentSchema);
