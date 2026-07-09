const mongoose = require('mongoose');

const consultationSchema = new mongoose.Schema({
  appointmentId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Appointment'
  },
  patientId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  doctorId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  reason: {
    type: String,
    required: false
  },
  isForSelf: {
    type: Boolean,
    default: true
  },
  patientName: String,
  patientAge: String,
  patientGender: String,
  status: {
    type: String,
    enum: ['pending', 'active', 'completed', 'cancelled'],
    default: 'pending'
  },
  startTime: {
    type: Date,
    default: Date.now
  },
  endTime: Date,
  duration: Number, // in seconds
  channelName: String,
  prescriptionId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'EnhancedPrescription'
  },
  hasPrescription: {
    type: Boolean,
    default: false
  },
  doctorNotes: {
    type: String,
    default: ''
  }
}, {
  timestamps: true
});

// Calculate duration when consultation ends (Mongoose 9 async-style hook)
consultationSchema.pre('save', async function() {
  if (this.endTime && this.startTime) {
    this.duration = Math.floor((this.endTime - this.startTime) / 1000);
  }
});

module.exports = mongoose.model('Consultation', consultationSchema);
