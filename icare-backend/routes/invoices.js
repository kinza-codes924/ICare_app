const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const User = require('../models/User');
const PharmacyProfile = require('../models/PharmacyProfile');
const PharmacyOrder = require('../models/PharmacyOrder');
const { authMiddleware } = require('../middleware/auth');
// pdfkit (~200ms) is required lazily: it is used only when generating an
// invoice PDF, but this route file loads on every cold start.

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
}

// Shared iCare-branded header (logo + name, "INVOICE" heading + number/date),
// mirroring prescription-v2.js's PDF header so every generated document
// looks consistent. Falls back to a text-only wordmark if the logo file is
// missing rather than failing the whole PDF.
function drawInvoiceHeader(doc, { invoiceNumber, date }) {
  const path = require('path');
  const fs = require('fs');
  const logoPath = path.join(__dirname, '../assets/logo.png');
  const logoExists = fs.existsSync(logoPath);

  if (logoExists) {
    doc.image(logoPath, 50, 40, { height: 44 });
    doc.fontSize(18).fillColor('#0036BC').text('iCare', 100, 46);
    doc.fontSize(8.5).fillColor('#666666').text('Your Trusted Healthcare Platform', 100, 68);
  } else {
    doc.fontSize(24).fillColor('#0036BC').text('iCare', 50, 50, { bold: true });
    doc.fontSize(10).fillColor('#666666').text('Your Trusted Healthcare Platform', 50, 80);
  }

  doc.fontSize(20).fillColor('#0036BC').text('INVOICE', 350, 40, { align: 'right', width: 200 });
  doc.fontSize(10).fillColor('#333333').text(`Invoice #${invoiceNumber}`, 350, 68, { align: 'right', width: 200 });
  doc.fontSize(9).fillColor('#666666').text(`Date: ${date}`, 350, 83, { align: 'right', width: 200 });

  doc.moveTo(50, 120).lineTo(550, 120).strokeColor('#E0E0E0').stroke();
}

// ─── GENERATE INVOICE PDF ─────────────────────────────────────────────────────
router.get('/:orderId/pdf', authMiddleware, async (req, res) => {
  try {
    await connectMongoDB();
    const { orderId } = req.params;
    const userId = toId(req.user.id);

    const order = await PharmacyOrder.findOne({
      _id: toId(orderId),
      $or: [{ patient_id: userId }, { pharmacy_id: userId }],
    }).lean();

    if (!order) {
      return res.status(404).json({ success: false, message: 'Order not found or access denied' });
    }

    const [patient, pharmacyUser, pharmacyProfile] = await Promise.all([
      User.findById(order.patient_id).lean(),
      User.findById(order.pharmacy_id).lean(),
      PharmacyProfile.findOne({ user_id: order.pharmacy_id }).lean(),
    ]);

    const items = order.items || [];

    // Create PDF
    const PDFDocument = require('pdfkit');
    const doc = new PDFDocument({ margin: 50, size: 'A4' });
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename=icare-invoice-${orderId}.pdf`);
    doc.pipe(res);

    // ─── HEADER ───────────────────────────────────────────────────────────────
    drawInvoiceHeader(doc, {
      invoiceNumber: order.order_number || orderId,
      date: new Date(order.createdAt).toLocaleDateString('en-PK'),
    });

    // ─── PATIENT & PHARMACY INFO ──────────────────────────────────────────────
    let yPos = 140;

    doc.fontSize(11).fillColor('#0036BC').text('PATIENT INFORMATION', 50, yPos);
    yPos += 20;
    doc.fontSize(10).fillColor('#333333').text(`Name: ${patient?.username || patient?.name || 'N/A'}`, 50, yPos);
    yPos += 15;
    doc.text(`Email: ${patient?.email || 'N/A'}`, 50, yPos);
    yPos += 15;
    doc.text(`Phone: ${patient?.phone || 'N/A'}`, 50, yPos);
    yPos += 15;
    doc.fontSize(9).fillColor('#666666').text('Delivery Address:', 50, yPos);
    yPos += 12;
    doc.text(order.delivery_address || 'N/A', 50, yPos, { width: 200 });

    yPos = 140;
    doc.fontSize(10).fillColor('#666666').text('Pharmacy:', 350, yPos);
    yPos += 15;
    doc.fontSize(9).fillColor('#333333').text(pharmacyProfile?.pharmacy_name || pharmacyUser?.username || pharmacyUser?.name || 'N/A', 350, yPos);
    if (pharmacyProfile?.address) { yPos += 12; doc.text(pharmacyProfile.address, 350, yPos); }
    if (pharmacyProfile?.city) { yPos += 12; doc.text(pharmacyProfile.city, 350, yPos); }

    // ─── ORDER ITEMS TABLE ────────────────────────────────────────────────────
    yPos = 280;

    doc.rect(50, yPos, 500, 25).fillAndStroke('#0036BC', '#0036BC');
    doc.fontSize(10).fillColor('#FFFFFF')
      .text('Item', 60, yPos + 8, { width: 200 })
      .text('Qty', 280, yPos + 8, { width: 50 })
      .text('Price (PKR)', 350, yPos + 8, { width: 80 })
      .text('Total (PKR)', 450, yPos + 8, { width: 90, align: 'right' });
    yPos += 25;

    if (items.length === 0) {
      doc.rect(50, yPos, 500, 30).fillAndStroke('#F9F9F9', '#E0E0E0');
      doc.fontSize(9).fillColor('#666666').text('No items recorded', 60, yPos + 10, { width: 480 });
      yPos += 30;
    } else {
      items.forEach((item, index) => {
        const bgColor = index % 2 === 0 ? '#F9F9F9' : '#FFFFFF';
        doc.rect(50, yPos, 500, 30).fillAndStroke(bgColor, '#E0E0E0');
        const itemName = item.product_name || 'Product';
        const genericName = item.generic_name ? ` (${item.generic_name})` : '';
        doc.fontSize(9).fillColor('#333333')
          .text(itemName + genericName, 60, yPos + 10, { width: 200 })
          .text(String(item.quantity || 1), 280, yPos + 10, { width: 50 })
          .text(parseFloat(item.price || 0).toFixed(2), 350, yPos + 10, { width: 80 })
          .text((parseFloat(item.price || 0) * (item.quantity || 1)).toFixed(2), 450, yPos + 10, { width: 90, align: 'right' });
        yPos += 30;
      });
    }

    // ─── TOTALS ───────────────────────────────────────────────────────────────
    yPos += 10;

    if (order.delivery_fee && parseFloat(order.delivery_fee) > 0) {
      doc.fontSize(10).fillColor('#666666')
        .text('Delivery Fee:', 350, yPos)
        .text(`PKR ${parseFloat(order.delivery_fee).toFixed(2)}`, 450, yPos, { width: 90, align: 'right' });
      yPos += 20;
    }

    doc.fontSize(12).fillColor('#0036BC')
      .text('Total Amount:', 350, yPos, { bold: true })
      .text(`PKR ${parseFloat(order.total_amount || 0).toFixed(2)}`, 450, yPos, { width: 90, align: 'right', bold: true });

    // ─── FOOTER ───────────────────────────────────────────────────────────────
    doc.fontSize(8).fillColor('#999999')
      .text('Thank you for choosing iCare - Your Trusted Healthcare Platform', 50, 700, { align: 'center', width: 500 })
      .text('For support, contact: support@icare.com', 50, 715, { align: 'center', width: 500 });

    doc.end();
  } catch (error) {
    console.error('Generate invoice PDF error:', error);
    res.status(500).json({ success: false, message: 'Failed to generate invoice' });
  }
});

// ─── GENERATE RECEPTION (WALK-IN VISIT) INVOICE PDF ───────────────────────────
// Public (no authMiddleware) — same trust model as the existing prescription
// PDF route (prescription-v2.js): an unguessable Mongo ObjectId in the URL is
// the access control, so the app can open it directly via url_launcher
// without needing to carry an Authorization header into a new browser tab.
router.get('/reception/:consultationId/pdf', async (req, res) => {
  try {
    await connectMongoDB();
    const Consultation = require('../models/Consultation');
    const DoctorProfile = require('../models/DoctorProfile');
    const { resolveClinicAddress } = require('../utils/clinicAddresses');
    const {
      newReceiptDoc, drawReceiptHeader, drawInfoLine, drawItemsList, drawReceiptTotals, drawReceiptFooter,
    } = require('../utils/thermalReceipt');
    const { consultationId } = req.params;

    const consultation = await Consultation.findById(toId(consultationId)).lean();
    if (!consultation) {
      return res.status(404).json({ success: false, message: 'Consultation not found' });
    }

    const [doctor, doctorProfile] = await Promise.all([
      User.findById(consultation.doctorId).lean(),
      DoctorProfile.findOne({ user_id: consultation.doctorId }).lean(),
    ]);
    const clinicAddress = resolveClinicAddress(doctorProfile);

    // items = the doctor's base consultation fee (if set) + any billable
    // procedures added by reception — deliberately allowed to be empty/zero,
    // this must render as a valid "blank" invoice for a payment-only visit.
    const items = [];
    if (consultation.consultationFee > 0) {
      items.push({ name: 'Consultation Fee', quantity: 1, price: consultation.consultationFee });
    }
    for (const p of (consultation.procedures || [])) {
      items.push({ name: p.name, quantity: 1, price: p.price || 0 });
    }
    const subtotal = items.reduce((sum, i) => sum + (i.price * i.quantity), 0);
    const taxRate = Number(consultation.taxRate) || 0;
    // Prefer the persisted taxAmount (set at payment time by
    // calculateAmount() in payments.js, the authoritative charged figure)
    // — fall back to a fresh computation for an unpaid/not-yet-charged visit
    // so the invoice is still previewable before payment.
    const taxAmount = consultation.taxAmount > 0 ? consultation.taxAmount : subtotal * (taxRate / 100);
    const totalAmount = subtotal + taxAmount;

    // Thermal-printer receipt (80mm roll) — client's explicit format
    // request for invoices, as opposed to prescriptions which stay A4.
    const doc = newReceiptDoc(res, `icare-invoice-${consultationId}.pdf`);

    let y = drawReceiptHeader(doc, {
      invoiceNumber: consultationId.slice(-8).toUpperCase(),
      date: new Date(consultation.createdAt).toLocaleDateString('en-PK'),
      clinicAddress,
    });

    y = drawInfoLine(doc, y, 'Patient', consultation.patientName || 'Walk-in Patient');
    if (consultation.patientAge) y = drawInfoLine(doc, y, 'Age', String(consultation.patientAge));
    if (consultation.patientGender) y = drawInfoLine(doc, y, 'Gender', consultation.patientGender);
    y = drawInfoLine(doc, y, 'Doctor', doctor?.name || doctor?.username || 'N/A');
    y += 4;

    y = drawItemsList(doc, y, items);
    y = drawReceiptTotals(doc, y, { subtotal, taxRate, taxAmount, totalAmount });
    drawReceiptFooter(doc, y);

    doc.end();
  } catch (error) {
    console.error('Generate reception invoice PDF error:', error);
    res.status(500).json({ success: false, message: 'Failed to generate invoice' });
  }
});

// ─── GENERATE STANDALONE INVOICE PDF ────────────────────────────────────────
// Public (no authMiddleware) — same unguessable-ObjectId trust model as the
// reception invoice route above.
router.get('/standalone/:invoiceId/pdf', async (req, res) => {
  try {
    await connectMongoDB();
    const StandaloneInvoice = require('../models/StandaloneInvoice');
    const ReceptionistProfile = require('../models/ReceptionistProfile');
    const DoctorProfile = require('../models/DoctorProfile');
    const { resolveClinicAddress } = require('../utils/clinicAddresses');
    const {
      newReceiptDoc, drawReceiptHeader, drawInfoLine, drawItemsList, drawReceiptTotals, drawReceiptFooter,
    } = require('../utils/thermalReceipt');
    const { invoiceId } = req.params;

    const invoice = await StandaloneInvoice.findById(toId(invoiceId)).lean();
    if (!invoice) {
      return res.status(404).json({ success: false, message: 'Invoice not found' });
    }

    // No direct doctor/clinic link on a standalone invoice — resolve via
    // the receptionist's own assigned doctor(s) (a receptionist works for
    // one clinic in practice, so the first assigned doctor's clinicId is
    // the invoice's clinic).
    let clinicAddress = null;
    const receptionistProfile = await ReceptionistProfile.findOne({ user_id: invoice.receptionistId }).lean();
    const firstDoctorId = receptionistProfile?.doctorIds?.[0];
    if (firstDoctorId) {
      const doctorProfile = await DoctorProfile.findOne({ user_id: firstDoctorId }).lean();
      clinicAddress = resolveClinicAddress(doctorProfile);
    }

    const items = (invoice.items || []).map(i => ({ name: i.name, quantity: 1, price: i.price || 0 }));
    const subtotal = invoice.subtotal ?? items.reduce((sum, i) => sum + i.price, 0);
    const taxRate = Number(invoice.taxRate) || 0;
    const taxAmount = invoice.taxAmount ?? subtotal * (taxRate / 100);
    const totalAmount = invoice.totalAmount ?? subtotal + taxAmount;

    // Thermal-printer receipt (80mm roll) — same format as the reception
    // invoice above, per client's explicit request for invoices.
    const doc = newReceiptDoc(res, `icare-invoice-${invoiceId}.pdf`);

    let y = drawReceiptHeader(doc, {
      invoiceNumber: invoiceId.slice(-8).toUpperCase(),
      date: new Date(invoice.createdAt).toLocaleDateString('en-PK'),
      clinicAddress,
    });

    y = drawInfoLine(doc, y, 'Billed To', invoice.clientName);
    y += 4;

    y = drawItemsList(doc, y, items);
    y = drawReceiptTotals(doc, y, { subtotal, taxRate, taxAmount, totalAmount });
    drawReceiptFooter(doc, y);

    doc.end();
  } catch (error) {
    console.error('Generate standalone invoice PDF error:', error);
    res.status(500).json({ success: false, message: 'Failed to generate invoice' });
  }
});

module.exports = router;
