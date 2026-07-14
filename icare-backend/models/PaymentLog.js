const mongoose = require('mongoose');

// Append-only audit trail. One entry per step of every payment.
// level ALERT = something suspicious (signature mismatch, amount mismatch, etc.)
const paymentLogSchema = new mongoose.Schema({
  paymentId: { type: mongoose.Schema.Types.ObjectId, ref: 'Payment', default: null, index: true },
  safepayTracker: { type: String, default: null, index: true },
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },

  step: { type: String, required: true },
  // e.g. PAYMENT_CREATE_REQUESTED, AMOUNT_CALCULATED, SAFEPAY_SESSION_CREATED,
  // CHECKOUT_URL_GENERATED, WEBHOOK_RECEIVED, WEBHOOK_SIGNATURE_VALID,
  // WEBHOOK_SIGNATURE_INVALID, VERIFY_REQUESTED, VERIFY_RESULT,
  // AMOUNT_MISMATCH, STATUS_CHANGED, FULFILLED, DUPLICATE_IGNORED, ERROR

  level: { type: String, enum: ['INFO', 'WARN', 'ALERT', 'ERROR'], default: 'INFO', index: true },
  message: { type: String, default: null },
  payload: { type: Object, default: null }, // request/response snapshot (sanitized)
}, { timestamps: true });

paymentLogSchema.index({ createdAt: -1 });

module.exports = mongoose.models.PaymentLog || mongoose.model('PaymentLog', paymentLogSchema);
