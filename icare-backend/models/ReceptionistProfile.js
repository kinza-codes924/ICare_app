const mongoose = require('mongoose');

const receptionistProfileSchema = new mongoose.Schema({
  user_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, unique: true },
  // One or more doctors this receptionist handles walk-in front-desk work for.
  doctorIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  clinicName: String,
  phone: String,
}, { timestamps: true, strict: false });

module.exports = mongoose.models.ReceptionistProfile || mongoose.model('ReceptionistProfile', receptionistProfileSchema);
