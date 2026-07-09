const mongoose = require('mongoose');

const callSignalSchema = new mongoose.Schema({
  channelName: { type: String, required: true },
  callerId: { type: String, required: true },
  callerName: { type: String, required: true },
  receiverId: { type: String, required: true },
  callType: { type: String, enum: ['video', 'audio', 'consultation'], default: 'video' },
  status: {
    type: String,
    enum: ['pending', 'accepted', 'rejected', 'ended', 'missed'],
    default: 'pending',
  },
  createdAt: { type: Date, default: Date.now, expires: 60 }, // auto-delete after 60s
});

module.exports = mongoose.model('CallSignal', callSignalSchema);
