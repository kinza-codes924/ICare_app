const mongoose = require('mongoose');

const courseQuestionSchema = new mongoose.Schema({
  courseId: { type: mongoose.Schema.Types.ObjectId, ref: 'Course', required: true },
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  question: { type: String, required: true },
  answer: { type: String },
  answeredBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  answeredAt: { type: Date },
  isAnswered: { type: Boolean, default: false },
}, { timestamps: true });

module.exports = mongoose.models.CourseQuestion || mongoose.model('CourseQuestion', courseQuestionSchema);
