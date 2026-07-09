const mongoose = require('mongoose');

const ratingSchema = new mongoose.Schema({
  reviewer_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  target_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  target_type: { type: String, enum: ['doctor', 'pharmacy', 'lab'], required: true },
  reference_id: String,
  reference_type: { type: String, enum: ['appointment', 'order', 'booking'] },
  rating: { type: Number, min: 1, max: 5, required: true },
  comment: String,
}, { timestamps: true });

module.exports = mongoose.models.Rating || mongoose.model('Rating', ratingSchema);
