const mongoose = require('mongoose');

const pharmacyProfileSchema = new mongoose.Schema({
  user_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, unique: true },
  pharmacy_name: String,
  license_number: String,
  operating_hours: String,
  delivery_available: { type: Boolean, default: false },
  delivery_fee: { type: Number, default: 0 },
  address: String,
  city: String,
  latitude: { type: Number, default: null },
  longitude: { type: Number, default: null },
  drap_compliance: { type: Boolean, default: false },
  rating: { type: Number, default: 0 },
  total_reviews: { type: Number, default: 0 },
}, { timestamps: true, strict: false });

module.exports = mongoose.models.PharmacyProfile || mongoose.model('PharmacyProfile', pharmacyProfileSchema);
