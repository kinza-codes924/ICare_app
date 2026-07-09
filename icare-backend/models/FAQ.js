const mongoose = require('mongoose');

const faqSchema = new mongoose.Schema({
  question: { type: String, required: true, trim: true },
  answer: { type: String, required: true, trim: true },
  accountType: {
    type: String,
    enum: ['general', 'patient', 'doctor', 'pharmacy', 'lab', 'instructor', 'student'],
    default: 'general',
  },
  order: { type: Number, default: 0 },
  isActive: { type: Boolean, default: true },
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
}, { timestamps: true });

module.exports = mongoose.model('FAQ', faqSchema);
