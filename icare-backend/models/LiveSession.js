const mongoose = require('mongoose');

const liveSessionSchema = new mongoose.Schema({
  courseId: { type: mongoose.Schema.Types.ObjectId, ref: 'Course', required: true },
  instructorId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  title: { type: String, required: true },
  description: String,
  scheduledAt: { type: Date, required: true },
  startedAt: Date, // set each time the instructor goes live (scheduledAt may be reused/old)
  duration: { type: Number, default: 60 }, // minutes
  meetingLink: String,
  meetingId: String,
  meetingPassword: String,
  recordingUrl: String,
  recordings: [{ url: String, createdAt: { type: Date, default: Date.now } }],
  driveBackupUrl: String, // Google Drive archival copy (client's own folder) — backup only, not used for in-app playback
  status: {
    type: String,
    enum: ['scheduled', 'live', 'completed', 'cancelled', 'ended', 'rescheduled'],
    default: 'scheduled'
  },
  attendees: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  // Effectively unlimited — any number of students may join a session.
  maxParticipants: { type: Number, default: 1000000 },
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
  // Instructor heartbeat — updated every 30s while instructor is in session.
  // If older than 90s, session is treated as stale (instructor left without ending).
  instructorHeartbeat: { type: Date, default: null },
  // Whiteboard
  whiteboardStrokes: [{ type: mongoose.Schema.Types.Mixed }],
  whiteboardPermissions: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  // Instructor's whiteboard visibility — students follow this to auto-open
  whiteboardOpen: { type: Boolean, default: false },
  // Whoever is currently screen-sharing (Agora numeric uid, as a string) —
  // other participants poll this to switch to the big-main-view layout.
  // null/empty means nobody is sharing.
  screenSharingUid: { type: String, default: null },
  // Maps each participant's backend User to the Agora numeric uid Agora
  // assigned them for THIS call (uid:0 join means Agora picks a random one
  // server-side — there is no formula from userId to uid, so without this
  // explicit report/lookup the client has no reliable way to know which
  // remote video tile belongs to which participant). Each participant
  // reports their own uid right after joining via POST /:id/set-my-uid.
  participantUids: [{
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    agoraUid: String,
  }],
}, { timestamps: true });

module.exports = mongoose.models.LiveSession || mongoose.model('LiveSession', liveSessionSchema);
