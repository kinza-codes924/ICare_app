const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const { connectMongoDB } = require('../config/mongodb');
const User = require('../models/User');
const PharmacyProfile = require('../models/PharmacyProfile');
const PharmacyOrder = require('../models/PharmacyOrder');
const { authMiddleware } = require('../middleware/auth');
const PDFDocument = require('pdfkit');

function toId(id) {
  try { return new mongoose.Types.ObjectId(id); } catch { return null; }
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
    const doc = new PDFDocument({ margin: 50, size: 'A4' });
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename=icare-invoice-${orderId}.pdf`);
    doc.pipe(res);

    // ─── HEADER ───────────────────────────────────────────────────────────────
    doc.fontSize(24).fillColor('#0036BC').text('iCare', 50, 50, { bold: true });
    doc.fontSize(10).fillColor('#666666').text('Your Trusted Healthcare Platform', 50, 80);
    doc.fontSize(20).fillColor('#0036BC').text('INVOICE', 400, 50, { align: 'right' });
    doc.fontSize(10).fillColor('#333333').text(`Invoice #${order.order_number || orderId}`, 400, 80, { align: 'right' });
    doc.fontSize(9).fillColor('#666666').text(`Date: ${new Date(order.createdAt).toLocaleDateString('en-PK')}`, 400, 95, { align: 'right' });

    doc.moveTo(50, 120).lineTo(550, 120).strokeColor('#E0E0E0').stroke();

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

module.exports = router;
