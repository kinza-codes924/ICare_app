const mongoose = require('mongoose');

// A Payment is created BEFORE the user is redirected to Safepay.
// Amount is always calculated server-side (never trusted from the client).
// Status lifecycle: created -> pending -> paid | failed | expired | cancelled
// Records are never deleted — only status transitions are allowed.
const paymentSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },

  // What is being paid for
  type: { type: String, enum: ['course', 'appointment', 'lab', 'pharmacy'], required: true },
  refId: { type: mongoose.Schema.Types.ObjectId, required: true }, // courseId / appointmentId / labBookingId / orderId

  // Who receives the money — instructor (course), doctor (appointment),
  // lab (lab test) or pharmacy (order). Powers the admin per-entity report.
  payeeId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null, index: true },

  // How the payment is made: Safepay gateway (card/wallet/GPay) or cash
  // (lab: cash at collection; pharmacy: cash on delivery). Cash payments are
  // fulfilled when staff marks the cash as collected.
  method: { type: String, enum: ['safepay', 'cash'], default: 'safepay', index: true },
  cashCollectedAt: { type: Date, default: null },
  cashCollectedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },

  // Money — server-calculated. amount is in the lowest denomination sent to Safepay (paisa NOT used; Safepay PKR uses rupees x100? -> we store both)
  currency: { type: String, default: 'PKR' },
  amount: { type: Number, required: true },        // rupees actually charged (after discount)
  amountLowest: { type: Number, required: true },  // value sent to Safepay (lowest denomination)
  originalAmount: { type: Number, default: null }, // rupees before discount (null = no discount)
  discountAmount: { type: Number, default: 0 },    // originalAmount - amount

  // Voucher applied at creation time (discount already reflected in amount)
  voucherCode: { type: String, default: null },

  // Safepay references
  safepayTracker: { type: String, default: null, index: true }, // track_...
  safepayEnvironment: { type: String, default: null },          // sandbox | production
  safepayState: { type: String, default: null },                // TRACKER_STARTED, TRACKER_ENDED, ...
  safepayResponse: { type: Object, default: null },             // last verify/webhook payload snapshot

  status: {
    type: String,
    enum: ['created', 'pending', 'paid', 'failed', 'expired', 'cancelled'],
    default: 'created',
    index: true,
  },
  paidAt: { type: Date, default: null },

  // Set true once the business action (enrollment/order/etc.) has been executed.
  // Guarantees idempotency: duplicate webhooks can never double-fulfill.
  fulfilled: { type: Boolean, default: false },
  fulfilledAt: { type: Date, default: null },
  fulfillmentRef: { type: mongoose.Schema.Types.ObjectId, default: null }, // e.g. enrollmentId

  notes: { type: String, default: null },
}, { timestamps: true });

paymentSchema.index({ userId: 1, type: 1, refId: 1, status: 1 });

module.exports = mongoose.models.Payment || mongoose.model('Payment', paymentSchema);
