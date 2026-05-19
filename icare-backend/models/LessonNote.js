const mongoose = require('mongoose');

const lessonNoteSchema = new mongoose.Schema({
  studentId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  courseId: { type: mongoose.Schema.Types.ObjectId, ref: 'Course', required: true },
  moduleId: { type: String, required: true },
  lessonId: { type: String, required: true },
  content: { type: String, default: '' },
  lastEditedAt: { type: Date, default: Date.now },
}, { timestamps: true });

// One note per student per lesson
lessonNoteSchema.index({ studentId: 1, lessonId: 1 }, { unique: true });

module.exports = mongoose.models.LessonNote || mongoose.model('LessonNote', lessonNoteSchema);
