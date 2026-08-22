const mongoose = require('mongoose');

const receptionistProfileSchema = new mongoose.Schema({
  user_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, unique: true },
  // One or more doctors this receptionist handles walk-in front-desk work for.
  doctorIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  // NOTE: despite the field name, this stores the clinic *id* (e.g.
  // 'dental'), not a display name — matches DoctorProfile.clinicId's
  // convention. Kept named clinicName for backward compatibility with the
  // pre-existing (previously unused) field name. Unset = not part of a
  // standalone clinic.
  clinicName: String,
  phone: String,
  // Free-text speciality/department this receptionist handles intake for
  // (e.g. "Dental Intake") — client's explicit ask, separate from clinicName.
  speciality: String,
}, { timestamps: true, strict: false });

module.exports = mongoose.models.ReceptionistProfile || mongoose.model('ReceptionistProfile', receptionistProfileSchema);
