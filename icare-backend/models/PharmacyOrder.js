const mongoose = require('mongoose');

const orderItemSchema = new mongoose.Schema({
  product_id:   { type: mongoose.Schema.Types.ObjectId, ref: 'Product' },
  product_name: String,
  generic_name: String,
  quantity:     { type: Number, default: 1 },
  price:        { type: Number, default: 0 },
}, { _id: false });

const pharmacyOrderSchema = new mongoose.Schema({
  patient_id:       { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  pharmacy_id:      { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  prescription_id:  String,
  delivery_address: { type: String, default: '' },
  total_amount:     { type: Number, default: 0 },
  delivery_fee:     { type: Number, default: 0 },
  status: {
    type: String,
    enum: ['pending', 'confirmed', 'preparing', 'out-for-delivery', 'delivered', 'cancelled', 'completed', 'rejected'],
    default: 'pending',
  },
  order_number:           { type: String },
  expected_delivery_time: String,
  cancellation_reason:    { type: String, default: '' },
  rejection_reason:       { type: String, default: '' },
  items:                  [orderItemSchema],
  // Walk-in order fields
  orderType:       { type: String, enum: ['cart', 'prescription', 'walk-in'], default: 'cart' },
  patientName:     { type: String, default: '' },
  contact:         { type: String, default: '' },
  medicines:       { type: String, default: '' },
  deliveryOption:  { type: String, enum: ['pickup', 'delivery'], default: 'pickup' },
  notes:           { type: String, default: '' },
}, { timestamps: true });

// ── Self-healing: drop the stale unique index on orderNumber that causes
//    E11000 duplicate key errors.  Safe to call many times — fails silently
//    when the index is already gone.
async function dropStaleIndexes() {
  try {
    const coll = mongoose.connection.db?.collection('pharmacyorders');
    if (!coll) return;
    // Drop both camelCase and snake_case variants that may have been created
    for (const idxName of ['orderNumber_1', 'order_number_1']) {
      await coll.dropIndex(idxName).catch(() => {});
    }
  } catch (_) { /* db not ready yet — ignore */ }
}

if (mongoose.connection.readyState === 1) {
  dropStaleIndexes();
} else {
  mongoose.connection.once('connected', dropStaleIndexes);
}

module.exports = mongoose.models.PharmacyOrder || mongoose.model('PharmacyOrder', pharmacyOrderSchema);
