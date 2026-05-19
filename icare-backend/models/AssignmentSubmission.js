const mongoose = require('mongoose');

const submissionSchema = new mongoose.Schema({
  assignmentId: { type: mongoose.Schema.Types.ObjectId, ref: 'Assignment', required: true },
  courseId:     { type: mongoose.Schema.Types.ObjectId, ref: 'Course',     required: true },
  studentId:    { type: mongoose.Schema.Types.ObjectId, ref: 'User',       required: true },
  content:      { type: String, default: '' },       // text answer
  fileUrl:      { type: String },                    // uploaded file (Cloudinary)
  fileName:     { type: String },
  marksObtained:{ type: Number, default: null },
  feedback:     { type: String, default: '' },
  status:       { type: String, enum: ['submitted', 'graded', 'late'], default: 'submitted' },
  submittedAt:  { type: Date, default: Date.now },
  gradedAt:     { type: Date },
  gradedBy:     { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  // Rubric-based grading
  rubricGrade:  { type: String, default: null }, // e.g., "Excellent", "Satisfactory"
  stars:        { type: Number, min: 1, max: 5, default: null }, // 1-5 star rating
  comments:     { type: String, default: '' }, // Additional instructor comments
}, { timestamps: true });

submissionSchema.index({ assignmentId: 1, studentId: 1 }, { unique: true });

module.exports = mongoose.models.AssignmentSubmission || mongoose.model('AssignmentSubmission', submissionSchema);
