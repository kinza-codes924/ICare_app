const mongoose = require('mongoose');

const questionSchema = new mongoose.Schema({
  type: {
    type: String,
    enum: ['mcq', 'true_false', 'short_answer', 'essay', 'clinical_scenario', 'osce', 'clinical_image', 'clinical_video', 'osce_station'],
    required: true
  },
  question: { type: String, required: true },
  options: [String], // for MCQ
  correctAnswer: mongoose.Schema.Types.Mixed, // String or Array
  points: { type: Number, default: 1 },
  explanation: String,
  order: { type: Number, default: 0 },
  // Clinical scenario fields
  scenarioText: { type: String },
  imageUrl: { type: String },
  videoUrl: { type: String },
  videoFileUrl: { type: String },   // uploaded video file (Cloudinary)
  documentUrl: { type: String },    // attached document (any type)
  documentName: { type: String },   // original filename
  // OSCE station fields
  instructions: { type: String },
  rubric: { type: String },
  // OSCE/TOACS specific fields
  osceStations: [{
    stationName: String,
    description: String,
    imageUrl: String,
    videoUrl: String,
    expectedActions: [String],
    scoringCriteria: [String],
  }],
}, { strict: false });

const quizSchema = new mongoose.Schema({
  courseId: { type: mongoose.Schema.Types.ObjectId, ref: 'Course', required: true },
  moduleId: String,
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
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
