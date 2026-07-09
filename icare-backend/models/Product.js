const mongoose = require('mongoose');

const productSchema = new mongoose.Schema({
  pharmacy_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  name: { type: String, required: true },
  generic_name: String,
  description: { type: String, default: '' },
  category: { type: String, default: 'general' },
  medicine_category: { type: String, enum: ['OTC', 'Controlled', 'Vaccine'], default: 'OTC' },
  price: { type: Number, default: 0 },
  stock_quantity: { type: Number, default: 0 },
  manufacturer: String,
  requires_prescription: { type: Boolean, default: false },
  is_active: { type: Boolean, default: true },
}, { timestamps: true });

module.exports = mongoose.models.Product || mongoose.model('Product', productSchema);
