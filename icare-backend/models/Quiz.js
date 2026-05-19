const mongoose = require('mongoose');

const questionSchema = new mongoose.Schema({
  type: {
    type: String,
    enum: ['mcq', 'true_false', 'short_answer', 'essay', 'clinical_scenario', 'osce', 'clinical_image', 'clinical_video'],
    required: true
  },
  question: { type: String, required: true },
  options: [String], // for MCQ
  correctAnswer: mongoose.Schema.Types.Mixed, // String or Array
  points: { type: Number, default: 1 },
  explanation: String,
  order: { type: Number, default: 0 },
  // Clinical scenario fields
  scenarioText: { type: String }, // Patient scenario description
  imageUrl: { type: String }, // Clinical image (X-ray, CT scan, etc.)
  videoUrl: { type: String }, // Clinical video (patient acting, procedure, etc.)
  // OSCE/TOACS specific fields
  osceStations: [{ // Multiple stations for OSCE
    stationName: String,
    description: String,
    imageUrl: String,
    videoUrl: String,
    expectedActions: [String],
    scoringCriteria: [String],
  }],
});

const quizSchema = new mongoose.Schema({
  courseId: { type: mongoose.Schema.Types.ObjectId, ref: 'Course', required: true },
  moduleId: String,
  title: { type: String, required: true },
  description: String,
  questions: [questionSchema],
  timeLimit: Number, // minutes, null = no limit
  passingScore: { type: Number, default: 70 }, // percentage
  maxAttempts: { type: Number, default: 3 },
  shuffleQuestions: { type: Boolean, default: false },
  showCorrectAnswers: { type: Boolean, default: true },
  isPublished: { type: Boolean, default: true },
}, { timestamps: true });

module.exports = mongoose.models.Quiz || mongoose.model('Quiz', quizSchema);
