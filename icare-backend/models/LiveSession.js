const mongoose = require('mongoose');

const liveSessionSchema = new mongoose.Schema({
  courseId: { type: mongoose.Schema.Types.ObjectId, ref: 'Course', required: true },
  instructorId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  title: { type: String, required: true },
  description: String,
  scheduledAt: { type: Date, required: true },
  duration: { type: Number, default: 60 }, // minutes
  meetingLink: String,
  meetingId: String,
  meetingPassword: String,
  recordingUrl: String,
  status: {
    type: String,
    enum: ['scheduled', 'live', 'completed', 'cancelled'],
    default: 'scheduled'
  },
  attendees: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  maxParticipants: { type: Number, default: 100 },
  isRecorded: { type: Boolean, default: true },
  recordingStartedAt: Date,
  recordingEndedAt: Date,
  recordingDuration: Number,        // seconds
  recordingResourceId: String,      // Agora Cloud Recording resource ID
  recordingSid: String,             // Agora Cloud Recording SID
  // Chat messages during live session
  chatMessages: [{
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    userName: String,
    message: String,
    timestamp: { type: Date, default: Date.now },
  }],
  // Raised hands tracking
  raisedHands: [{
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    userName: String,
    raisedAt: { type: Date, default: Date.now },
  }],
  // Waiting room
  waitingRoom: { type: Boolean, default: false },
  waitingStudents: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  // Linked lesson (for auto-saving recording)
  linkedLessonId: String,
  linkedModuleId: String,
}, { timestamps: true });

module.exports = mongoose.models.LiveSession || mongoose.model('LiveSession', liveSessionSchema);
