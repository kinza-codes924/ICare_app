const mongoose = require('mongoose');

const attendanceSchema = new mongoose.Schema({
  courseId:     { type: mongoose.Schema.Types.ObjectId, ref: 'Course', required: true },
  instructorId: { type: mongoose.Schema.Types.ObjectId, ref: 'User',   required: true },
  sessionTitle: { type: String, default: 'Class Session' },
  sessionDate:  { type: Date,   required: true },
  liveSessionId: String, // set when auto-created from a live session join
  records: [{
    studentId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    status:    { type: String, enum: ['present', 'absent', 'late'], default: 'absent' },
    joinedAt:  { type: Date, default: null },
    leftAt:    { type: Date, default: null },
    durationMinutes: { type: Number, default: null },
  }],
}, { timestamps: true });

module.exports = mongoose.models.Attendance || mongoose.model('Attendance', attendanceSchema);
