const mongoose = require('mongoose');

const doctorProfileSchema = new mongoose.Schema({
  user_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, unique: true },
  specialization: String,
  experience_years: { type: Number, default: 0 },
  license_number: String,
  licenseValidTill: Date,
  consultation_fee: { type: Number, default: 0 },
  available_days: [String],
  available_hours: { type: mongoose.Schema.Types.Mixed },
  // Per-day working slots, e.g. { Monday: [{ start: '09:00', end: '14:30' }] }.
  // The booking screen builds its time slots from these, so a doctor working
  // mornings and evenings doesn't get offered right through the middle of the
  // day. available_hours stays as the outer envelope / fallback.
  weeklySlots: { type: mongoose.Schema.Types.Mixed },
  // Minutes per appointment. Distinct from bufferTime (the gap between them).
  slotDuration: { type: Number, default: 15 },
  rating: { type: Number, default: 0 },
  total_reviews: { type: Number, default: 0 },
  degrees: [String],
  clinic_name: String,
  clinic_address: String,
  consultation_type: String,
  languages: [String],
  // Which standalone iCare Clinic this doctor belongs to, if any — matches
  // the static clinic ids in lib/data/icare_clinics_data.dart ('dental',
  // 'derma', 'mother_child', 'physio', 'psychiatry', 'lifestyle_wellness').
  // Drives clinic-admin notifications/dashboard visibility. Doctors not
  // part of a standalone clinic (independent telehealth doctors) leave
  // this unset.
  clinicId: String,
  // Whether the doctor sees the Walk-In Patients card on their dashboard.
  // Front-desk walk-ins only make sense for doctors who physically sit at a
  // clinic, so this is admin-granted per doctor rather than on for everyone.
  // Unset is treated as false — see routes/doctors.js walkinEnabled.
  walkinEnabled: { type: Boolean, default: false },
}, { timestamps: true, strict: false });

module.exports = mongoose.models.DoctorProfile || mongoose.model('DoctorProfile', doctorProfileSchema);
