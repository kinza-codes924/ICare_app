const mongoose = require('mongoose');

const callSignalSchema = new mongoose.Schema({
  channelName: { type: String, required: true },
  callerId: { type: String, required: true },
  callerName: { type: String, required: true },
  receiverId: { type: String, required: true },
  // 'reception' — a walk-in front-desk call (reception_prescription_screen.dart):
  // channelName is the walk-in Consultation's id, and the doctor's incoming-
  // call screen shows the prescription form split alongside the video, same
  // as the receptionist's own screen already does.
  callType: { type: String, enum: ['video', 'audio', 'consultation', 'reception'], default: 'video' },
  status: {
    type: String,
    enum: ['pending', 'accepted', 'rejected', 'ended', 'missed'],
    default: 'pending',
  },
  createdAt: { type: Date, default: Date.now, expires: 60 }, // auto-delete after 60s
});

module.exports = mongoose.model('CallSignal', callSignalSchema);
