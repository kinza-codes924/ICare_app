const mongoose = require('mongoose');

const liveSessionPollSchema = new mongoose.Schema({
  sessionId: { type: mongoose.Schema.Types.ObjectId, ref: 'LiveSession', required: true },
  instructorId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  question: { type: String, required: true },
  options: [{ type: String, required: true }],
  responses: [{
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    optionIndex: { type: Number, required: true },
    respondedAt: { type: Date, default: Date.now },
  }],
  isActive: { type: Boolean, default: true },
  createdAt: { type: Date, default: Date.now },
  closedAt: { type: Date },
}, { timestamps: true });

module.exports = mongoose.models.LiveSessionPoll || mongoose.model('LiveSessionPoll', liveSessionPollSchema);
