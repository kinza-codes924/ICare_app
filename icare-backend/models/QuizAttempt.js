const mongoose = require('mongoose');

const quizAttemptSchema = new mongoose.Schema({
  quizId: { type: mongoose.Schema.Types.ObjectId, ref: 'Quiz', required: true },
  studentId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  answers: [{
    questionId: String,
    answer: mongoose.Schema.Types.Mixed, // String or Array
    isCorrect: Boolean,
    pointsEarned: Number
  }],
  score: { type: Number, default: 0 },
  totalPoints: { type: Number, default: 0 },
  passingMarks: { type: Number, default: 0 }, // computed from quiz.passingScore % at submit time
  percentage: { type: Number, default: 0 },
  passed: { type: Boolean, default: false },
  startedAt: { type: Date, default: Date.now },
  submittedAt: Date,
  attemptNumber: { type: Number, default: 1 },
  timeSpent: Number, // seconds
  // Instructor review — rubric level, star rating, written feedback
  rubricGrade: { type: String, enum: ['excellent', 'satisfactory', 'average', 'needs_improvement', null], default: null },
  stars: { type: Number, min: 1, max: 5 },
  feedback: { type: String, default: '' },
  gradedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  gradedAt: Date,
}, { timestamps: true });

quizAttemptSchema.index({ quizId: 1, studentId: 1, attemptNumber: 1 }, { unique: true });

module.exports = mongoose.models.QuizAttempt || mongoose.model('QuizAttempt', quizAttemptSchema);
