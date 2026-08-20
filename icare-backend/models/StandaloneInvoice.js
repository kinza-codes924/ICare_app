const mongoose = require('mongoose');

// A standalone invoice — created directly by a receptionist, not tied to
// any walk-in Consultation/doctor/patient. Exists so Payment.refId (always
// required) has a real document to point at, and so the client billed here
// doesn't need any account on the platform at all.
const standaloneInvoiceSchema = new mongoose.Schema({
  receptionistId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  clientName: { type: String, required: true },
  items: [{
    name: { type: String, required: true },
    price: { type: Number, default: 0 },
  }],
  // SRB (Sindh Revenue Board) sales tax on services — not FBR. Optional:
  // receptionist can disable it entirely, or pick 8%/15%/custom when on.
  taxEnabled: { type: Boolean, default: true },
  taxRate: { type: Number, default: 15 },
  subtotal: { type: Number, default: 0 },
  taxAmount: { type: Number, default: 0 },
  totalAmount: { type: Number, default: 0 },
  paymentStatus: { type: String, enum: ['unpaid', 'paid'], default: 'unpaid' },
}, { timestamps: true });

module.exports = mongoose.models.StandaloneInvoice || mongoose.model('StandaloneInvoice', standaloneInvoiceSchema);
