const mongoose = require('mongoose');

const consultationSchema = new mongoose.Schema({
  appointmentId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Appointment'
  },
  // Optional — a walk-in front-desk consultation (isWalkIn:true) has no
  // patient User account at all (guest entry, identity carried entirely by
  // patientName/patientAge/patientGender below). Required for every other
  // consultation type, which always has a real logged-in patient.
  patientId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
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
  },
  // Walk-in front-desk fields — a receptionist creates these directly with
  // no video Appointment behind them (appointmentId/channelName stay null).
  isWalkIn: {
    type: Boolean,
    default: false
  },
  receptionistId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
  },
  // Doctor's base visit fee, snapshotted at walk-in creation time so later
  // consultation_fee changes on the doctor's profile don't alter past bills.
  consultationFee: {
    type: Number,
    default: 0
  },
  procedures: [{
    name: { type: String, required: true },
    price: { type: Number, default: 0 },
    addedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    addedAt: { type: Date, default: Date.now },
  }],
  paymentStatus: {
    type: String,
    enum: ['unpaid', 'paid'],
    default: 'unpaid'
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
