const mongoose = require('mongoose');

const appointmentSchema = new mongoose.Schema({
  patient_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  doctor_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  appointment_date: { type: String },
  appointment_time: { type: String },
  consultation_type: { type: String, default: 'in-person' },
  // Which iCare Clinic the patient booked through, if any. Unset means a
  // direct/telehealth booking. Pricing reads this to decide whether the
  // online-payment discount applies — the clinic department accounts don't
  // all carry a clinicId of their own, so the booking route is the signal.
  clinicId: String,
  notes: { type: String, default: '' },
  channel_name: { type: String }, // for video consultations
  status: {
    type: String,
    enum: ['pending', 'confirmed', 'completed', 'cancelled', 'in_progress', 'missed'],
    default: 'pending',
  },
  // Set to 'paid' by the payments flow once the consultation fee clears.
  paymentStatus: { type: String, enum: ['unpaid', 'paid'], default: 'unpaid' },
  // Patient rating after completed consultation (optional)
  rating: { type: Number, min: 1, max: 5 },
  ratingComment: { type: String, default: '' },
  ratedAt: { type: Date },
  // Reminder tracking — set true once each reminder has been sent so the
  // cron job never double-sends on repeated runs.
  reminderSent1hr: { type: Boolean, default: false },
  reminderSent10min: { type: Boolean, default: false },
}, { timestamps: true });

module.exports = mongoose.models.Appointment || mongoose.model('Appointment', appointmentSchema);
