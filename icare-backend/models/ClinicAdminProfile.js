const mongoose = require('mongoose');

// Links a User (role: 'admin') to one of the static standalone iCare Clinics
// (ids match lib/data/icare_clinics_data.dart: 'dental', 'derma',
// 'mother_child', 'physio', 'psychiatry', 'lifestyle_wellness'). This is how
// a clinic-level admin sees/gets notified about bookings for every doctor
// under their clinic, instead of each doctor only seeing their own.
const clinicAdminProfileSchema = new mongoose.Schema({
  user_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, unique: true },
  clinicId: { type: String, required: true },
}, { timestamps: true });

module.exports = mongoose.models.ClinicAdminProfile || mongoose.model('ClinicAdminProfile', clinicAdminProfileSchema);
