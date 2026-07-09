const mongoose = require('mongoose');

const consultationMessageSchema = new mongoose.Schema({
  consultationId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Consultation',
    required: true
  },
  senderId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  senderName: {
    type: String,
    required: true
  },
  senderRole: {
    type: String,
    enum: ['doctor', 'patient'],
    required: true
  },
  message: {
    type: String,
    required: true
  },
  attachmentUrl: String,
  isSystemMessage: {
    type: Boolean,
    default: false
  },
  timestamp: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

// Index for faster queries
consultationMessageSchema.index({ consultationId: 1, timestamp: 1 });

module.exports = mongoose.model('ConsultationMessage', consultationMessageSchema);
