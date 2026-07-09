const mongoose = require('mongoose');

const labProfileSchema = new mongoose.Schema({
  user_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, unique: true },
  lab_name: String,
  license_number: String,
  accreditation: String,
  services: [String],
  operating_hours: String,
  address: String,
  city: String,
  latitude: { type: Number, default: null },
  longitude: { type: Number, default: null },
  drap_compliance: { type: Boolean, default: false },
  rating: { type: Number, default: 0 },
  total_reviews: { type: Number, default: 0 },
}, { timestamps: true, strict: false });

module.exports = mongoose.models.LabProfile || mongoose.model('LabProfile', labProfileSchema);
