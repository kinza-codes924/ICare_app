const mongoose = require('mongoose');

const precautionSchema = new mongoose.Schema({
  title: { type: String, required: true },
  description: String,
  category: String,
  instructor_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  is_active: { type: Boolean, default: true },
}, { timestamps: true });

module.exports = mongoose.models.Precaution || mongoose.model('Precaution', precautionSchema);
