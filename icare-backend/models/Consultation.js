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
  // SRB (Sindh Revenue Board) sales tax on services — not FBR. Optional per
  // client request: receptionist can turn it off entirely, or pick 8%/15%
  // (or any custom rate) when on. taxAmount is recomputed server-side
  // whenever the payment is calculated, and is forced to 0 when disabled.
  taxEnabled: {
    type: Boolean,
    default: true
  },
  taxRate: {
    type: Number,
    default: 15
  },
  taxAmount: {
    type: Number,
    default: 0
  },
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

// Also had nothing but _id. The appointments route looks consultations up by
// appointmentId and by participant on every maintenance sweep.
consultationSchema.index({ appointmentId: 1 });
consultationSchema.index({ status: 1 });
consultationSchema.index({ patientId: 1, createdAt: -1 });
consultationSchema.index({ doctorId: 1, createdAt: -1 });

module.exports = mongoose.model('Consultation', consultationSchema);
