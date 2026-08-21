// Thermal-printer receipt layout (80mm roll) for reception/standalone
// invoices — client explicitly asked for this format (narrow strip, not
// A4) for invoices, while prescriptions stay A4. pdfkit supports a custom
// page size as [width, height] in points; 80mm = 226.77pt. Height is a
// generous fixed value (most thermal drivers auto-cut/feed to content —
// there is no reliable "auto height" in pdfkit, so this just needs to be
// tall enough that nothing on a normal-length receipt gets cut off).
const WIDTH = 227; // 80mm roll width in points
const HEIGHT = 900; // generous — thermal drivers trim trailing blank feed
const MARGIN = 10;
const CONTENT_WIDTH = WIDTH - MARGIN * 2;

function newReceiptDoc(res, filename) {
  const PDFDocument = require('pdfkit');
  const doc = new PDFDocument({ size: [WIDTH, HEIGHT], margin: MARGIN });
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename=${filename}`);
  doc.pipe(res);
  return doc;
}

// clinicAddress may be null (independent doctor with no address on file) —
// that line is simply omitted rather than printing a placeholder.
function drawReceiptHeader(doc, { invoiceNumber, date, clinicAddress }) {
  const path = require('path');
  const fs = require('fs');
  const logoPath = path.join(__dirname, '../assets/logo.png');
  const logoExists = fs.existsSync(logoPath);

  let y = MARGIN;
  if (logoExists) {
    const logoW = 40;
    doc.image(logoPath, (WIDTH - logoW) / 2, y, { width: logoW });
    y += logoW + 4;
  }
  doc.fontSize(13).fillColor('#0036BC').font('Helvetica-Bold')
    .text('iCare', MARGIN, y, { width: CONTENT_WIDTH, align: 'center' });
  y += 16;
  doc.fontSize(7).fillColor('#666666').font('Helvetica')
    .text('Your Trusted Healthcare Platform', MARGIN, y, { width: CONTENT_WIDTH, align: 'center' });
  y += 12;

  if (clinicAddress) {
    doc.fontSize(6.5).fillColor('#666666')
      .text(clinicAddress, MARGIN, y, { width: CONTENT_WIDTH, align: 'center' });
    y += doc.heightOfString(clinicAddress, { width: CONTENT_WIDTH }) + 4;
  }

  y += 4;
  doc.moveTo(MARGIN, y).lineTo(WIDTH - MARGIN, y).dash(1, { space: 1 }).strokeColor('#999999').stroke();
  doc.undash();
  y += 8;

  doc.fontSize(8).fillColor('#0F172A').font('Helvetica-Bold')
    .text('INVOICE', MARGIN, y, { width: CONTENT_WIDTH, align: 'center' });
  y += 12;
  doc.fontSize(7).fillColor('#333333').font('Helvetica')
    .text(`#${invoiceNumber}`, MARGIN, y, { width: CONTENT_WIDTH, align: 'center' })
    .text(date, MARGIN, y + 9, { width: CONTENT_WIDTH, align: 'center' });
  y += 24;

  doc.moveTo(MARGIN, y).lineTo(WIDTH - MARGIN, y).dash(1, { space: 1 }).strokeColor('#999999').stroke();
  doc.undash();
  return y + 8;
}

// One label:value line, small enough for the 80mm strip.
function drawInfoLine(doc, y, label, value) {
  doc.fontSize(7).fillColor('#666666').font('Helvetica').text(`${label}:`, MARGIN, y, { continued: false });
  const labelWidth = doc.widthOfString(`${label}: `);
  doc.fontSize(7).fillColor('#0F172A').font('Helvetica-Bold')
    .text(value, MARGIN + labelWidth, y, { width: CONTENT_WIDTH - labelWidth });
  return y + Math.max(10, doc.heightOfString(value, { width: CONTENT_WIDTH - labelWidth }) + 2);
}

// Items list — no table/grid on an 80mm strip, just name on one line and
// qty/price/line-total on the next, right-aligned. Returns the new y.
function drawItemsList(doc, y, items) {
  doc.moveTo(MARGIN, y).lineTo(WIDTH - MARGIN, y).dash(1, { space: 1 }).strokeColor('#999999').stroke();
  doc.undash();
  y += 6;

  if (items.length === 0) {
    doc.fontSize(7).fillColor('#666666').text('No items recorded', MARGIN, y, { width: CONTENT_WIDTH, align: 'center' });
    return y + 12;
  }

  items.forEach((item) => {
    doc.fontSize(7.5).fillColor('#0F172A').font('Helvetica-Bold')
      .text(item.name, MARGIN, y, { width: CONTENT_WIDTH });
    y += doc.heightOfString(item.name, { width: CONTENT_WIDTH }) + 1;

    const lineTotal = (item.price * item.quantity).toFixed(2);
    const qtyPriceStr = item.quantity > 1 ? `${item.quantity} x ${item.price.toFixed(2)}` : '';
    doc.fontSize(7).fillColor('#666666').font('Helvetica')
      .text(qtyPriceStr, MARGIN, y, { width: CONTENT_WIDTH / 2 })
      .fontSize(7.5).fillColor('#0F172A').font('Helvetica-Bold')
      .text(`PKR ${lineTotal}`, MARGIN, y, { width: CONTENT_WIDTH, align: 'right' });
    y += 12;
  });

  return y;
}

function drawReceiptTotals(doc, y, { subtotal, taxRate, taxAmount, totalAmount }) {
  doc.moveTo(MARGIN, y).lineTo(WIDTH - MARGIN, y).dash(1, { space: 1 }).strokeColor('#999999').stroke();
  doc.undash();
  y += 8;

  doc.fontSize(7).fillColor('#666666').font('Helvetica')
    .text('Subtotal', MARGIN, y, { width: CONTENT_WIDTH / 2 })
    .text(`PKR ${subtotal.toFixed(2)}`, MARGIN, y, { width: CONTENT_WIDTH, align: 'right' });
  y += 12;

  doc.text(`SRB Tax (${taxRate}%)`, MARGIN, y, { width: CONTENT_WIDTH / 2 })
    .text(`PKR ${taxAmount.toFixed(2)}`, MARGIN, y, { width: CONTENT_WIDTH, align: 'right' });
  y += 14;

  doc.moveTo(MARGIN, y).lineTo(WIDTH - MARGIN, y).strokeColor('#0F172A').stroke();
  y += 6;

  doc.fontSize(10).fillColor('#0036BC').font('Helvetica-Bold')
    .text('TOTAL', MARGIN, y, { width: CONTENT_WIDTH / 2 })
    .text(`PKR ${totalAmount.toFixed(2)}`, MARGIN, y, { width: CONTENT_WIDTH, align: 'right' });
  return y + 20;
}

function drawReceiptFooter(doc, y) {
  doc.moveTo(MARGIN, y).lineTo(WIDTH - MARGIN, y).dash(1, { space: 1 }).strokeColor('#999999').stroke();
  doc.undash();
  y += 10;
  doc.fontSize(6.5).fillColor('#999999').font('Helvetica')
    .text('Thank you for choosing iCare', MARGIN, y, { width: CONTENT_WIDTH, align: 'center' });
  y += 9;
  doc.text('support@icare.com', MARGIN, y, { width: CONTENT_WIDTH, align: 'center' });
  return y + 10;
}

module.exports = {
  WIDTH, HEIGHT, MARGIN, CONTENT_WIDTH,
  newReceiptDoc, drawReceiptHeader, drawInfoLine, drawItemsList, drawReceiptTotals, drawReceiptFooter,
};
