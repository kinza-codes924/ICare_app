const mongoose = require('mongoose');

// Admin-maintained list of controlled drug generic/INN names
// When a product's generic_name matches any entry here, it is auto-classified as Controlled
const controlledDrugSchema = new mongoose.Schema({
  genericName: { type: String, required: true, unique: true, trim: true },
  innName: { type: String, default: '' },
  schedule: { type: String, default: '' }, // e.g. Schedule II, IV
  notes: { type: String, default: '' },
  addedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
}, { timestamps: true });

module.exports = mongoose.models.ControlledDrug || mongoose.model('ControlledDrug', controlledDrugSchema);
