const mongoose = require('mongoose');

const cartItemSchema = new mongoose.Schema({
  user_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  product_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Product', required: true },
  quantity: { type: Number, default: 1, min: 1 },
  prescription_id: String,
}, { timestamps: true });

cartItemSchema.index({ user_id: 1 });
cartItemSchema.index({ user_id: 1, product_id: 1 }, { unique: true });

module.exports = mongoose.models.CartItem || mongoose.model('CartItem', cartItemSchema);
