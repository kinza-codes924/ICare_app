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
  rating: { type: Number, default: 0 },
  total_reviews: { type: Number, default: 0 },
  degrees: [String],
  clinic_name: String,
  clinic_address: String,
  consultation_type: String,
  languages: [String],
}, { timestamps: true, strict: false });

module.exports = mongoose.models.DoctorProfile || mongoose.model('DoctorProfile', doctorProfileSchema);
