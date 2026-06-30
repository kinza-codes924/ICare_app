const mongoose = require('mongoose');

const assignmentSchema = new mongoose.Schema({
  courseId:     { type: mongoose.Schema.Types.ObjectId, ref: 'Course', required: true },
  instructorId: { type: mongoose.Schema.Types.ObjectId, ref: 'User',   required: true },
  title:        { type: String, required: true },
  description:  { type: String, default: '' },
  dueDate:      { type: Date },
  totalMarks:   { type: Number, default: 100 },
  passingMarks: { type: Number, default: 50 },
  attachmentUrl:  { type: String },
  attachmentName: { type: String },
  isPublished:  { type: Boolean, default: true },
  // Rubric criteria for grading
  rubric: {
    type: [String],
    default: ['Excellent', 'Satisfactory', 'Average', 'Needs Improvement'],
  },
  // Reminder tracking (Feature 6)
  reminderSent5Days: { type: Boolean, default: false },
  reminderSentOnDue:  { type: Boolean, default: false },
}, { timestamps: true });

module.exports = mongoose.models.Assignment || mongoose.model('Assignment', assignmentSchema);
