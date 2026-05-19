const mongoose = require('mongoose');

const assignmentSchema = new mongoose.Schema({
  courseId:     { type: mongoose.Schema.Types.ObjectId, ref: 'Course', required: true },
  instructorId: { type: mongoose.Schema.Types.ObjectId, ref: 'User',   required: true },
  title:        { type: String, required: true },
  description:  { type: String, default: '' },
  dueDate:      { type: Date },
  totalMarks:   { type: Number, default: 100 },
  passingMarks: { type: Number, default: 50 },
  attachmentUrl:{ type: String },
  isPublished:  { type: Boolean, default: true },
  // Rubric criteria for grading
  rubric: {
    type: [String],
    default: ['Excellent', 'Satisfactory', 'Average', 'Needs Improvement'],
  },
}, { timestamps: true });

module.exports = mongoose.models.Assignment || mongoose.model('Assignment', assignmentSchema);
