import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfInvoiceGenerator {
  static Future<void> generatePharmacyInvoice({
    required String orderNumber,
    required String patientName,
    required String patientPhone,
    required String patientAddress,
    required List<Map<String, dynamic>> items,
    required double deliveryFee,
    required double totalAmount,
    required DateTime orderDate,
    required String pharmacyName,
    String patientEmail = '',
  }) async {
    final logoBytes = (await rootBundle.load('assets/images/logo.png')).buffer.asUint8List();
    final logoImage = pw.MemoryImage(logoBytes);
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // iCare Header
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Image(logoImage, height: 64, width: 64),
                  pw.SizedBox(width: 16),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'iCare',
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#0036BC'),
                        ),
                      ),
                      pw.Text(
                        'Your Trusted Healthcare Platform',
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(color: PdfColor.fromHex('#0036BC'), thickness: 2),
              pw.SizedBox(height: 16),

              // Invoice Title
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'ORDER INVOICE',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#0F172A'),
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Order #$orderNumber',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        DateFormat('MMM dd, yyyy').format(orderDate),
                        style: const pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 24),

              // Patient Details
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8FAFC'),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PATIENT DETAILS',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      patientName,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Phone: $patientPhone',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                    if (patientEmail.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Email: $patientEmail',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Address: $patientAddress',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // Items Table
              pw.Text(
                'ORDER ITEMS',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColor.fromHex('#E2E8F0')),
                children: [
                  // Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F1F5F9'),
                    ),
                    children: [
                      _buildTableCell('ITEM', isHeader: true),
                      _buildTableCell('QTY', isHeader: true),
                      _buildTableCell('PRICE', isHeader: true),
                      _buildTableCell('TOTAL', isHeader: true),
                    ],
                  ),
                  // Items
                  ...items.map((item) {
                    final qty = item['quantity'] ?? 1;
                    final price = (item['price'] ?? 0).toDouble();
                    final total = qty * price;
                    return pw.TableRow(
                      children: [
                        _buildTableCell(item['name'] ?? 'Unknown'),
                        _buildTableCell('$qty'),
                        _buildTableCell('PKR ${price.toStringAsFixed(0)}'),
                        _buildTableCell('PKR ${total.toStringAsFixed(0)}'),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 24),

              // Totals
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8FAFC'),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    _buildTotalRow('Subtotal', totalAmount - deliveryFee),
                    pw.SizedBox(height: 8),
                    _buildTotalRow('Delivery Fee', deliveryFee),
                    pw.Divider(color: PdfColor.fromHex('#E2E8F0')),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'TOTAL',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'PKR ${totalAmount.toStringAsFixed(0)}',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#10B981'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.Spacer(),

              // Footer
              pw.Divider(color: PdfColor.fromHex('#E2E8F0')),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Fulfilled by: $pharmacyName',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    'Powered by iCare',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#0036BC'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  static Future<void> generateLabInvoice({
    required String bookingNumber,
    required String patientName,
    required String patientPhone,
    required String testName,
    required double testPrice,
    required DateTime bookingDate,
    required String labName,
    String? sampleType,
    String? turnaroundTime,
    String? sampleCollectedBy,
    List<Map<String, dynamic>>? doctors,
    String? approvedDoctorLine,
    List<dynamic>? results,
    String? resultNotes,
  }) async {
    final logoBytes = (await rootBundle.load('assets/images/logo.png')).buffer.asUint8List();
    final logoImage = pw.MemoryImage(logoBytes);
    final pdf = pw.Document();

    final navyBlue = PdfColor.fromHex('#0B2D6E');
    final lightBlue = PdfColor.fromHex('#EFF6FF');
    final borderGrey = PdfColor.fromHex('#E2E8F0');
    final textDark = PdfColor.fromHex('#0F172A');
    final textMuted = PdfColors.grey700;
    final redColor = PdfColor.fromHex('#DC2626');
    final greenColor = PdfColor.fromHex('#059669');

    // Split comma-separated test names into individual lines
    final testList = testName
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final hasResults = results != null && results.isNotEmpty;
    final hasNotes = resultNotes != null && resultNotes.trim().isNotEmpty;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        build: (context) => [
          // ── Header ───────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Image(logoImage, height: 52, width: 52),
                  pw.SizedBox(width: 12),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('iCare',
                          style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: navyBlue)),
                      pw.Text('Your Trusted Healthcare Platform',
                          style: pw.TextStyle(fontSize: 9, color: textMuted)),
                    ],
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: navyBlue,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text('LABORATORY REPORT',
                        style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white)),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text('Report No: $bookingNumber',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold, color: textDark)),
                  pw.Text('Date: ${DateFormat('dd MMM yyyy').format(bookingDate)}',
                      style: pw.TextStyle(fontSize: 9, color: textMuted)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Divider(color: navyBlue, thickness: 2),
          pw.SizedBox(height: 16),

          // ── Patient + Lab Info (two columns) ─────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: lightBlue,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: borderGrey),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('PATIENT INFORMATION',
                          style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: navyBlue,
                              letterSpacing: 0.8)),
                      pw.SizedBox(height: 8),
                      _labInfoRow('Name', patientName),
                      _labInfoRow('Phone', patientPhone.isNotEmpty ? patientPhone : '—'),
                      if (sampleCollectedBy != null && sampleCollectedBy.isNotEmpty)
                        _labInfoRow('Collected By', sampleCollectedBy),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: lightBlue,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: borderGrey),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('LABORATORY INFORMATION',
                          style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: navyBlue,
                              letterSpacing: 0.8)),
                      pw.SizedBox(height: 8),
                      _labInfoRow('Lab', labName),
                      _labInfoRow('Report Date', DateFormat('dd MMM yyyy').format(bookingDate)),
                      if (turnaroundTime != null && turnaroundTime.isNotEmpty)
                        _labInfoRow('TAT', turnaroundTime),
                      if (sampleType != null && sampleType.isNotEmpty)
                        _labInfoRow('Sample', sampleType),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),

          // ── Tests Ordered ─────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F8FAFC'),
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: borderGrey),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('TESTS ORDERED',
                    style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: navyBlue,
                        letterSpacing: 0.8)),
                pw.SizedBox(height: 8),
                ...testList.asMap().entries.map((entry) {
                  final i = entry.key;
                  final t = entry.value;
                  return pw.Padding(
                    padding: pw.EdgeInsets.only(bottom: i < testList.length - 1 ? 4 : 0),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          width: 18,
                          height: 18,
                          alignment: pw.Alignment.center,
                          decoration: pw.BoxDecoration(
                            color: navyBlue,
                            borderRadius: pw.BorderRadius.circular(3),
                          ),
                          child: pw.Text('${i + 1}',
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white)),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Expanded(
                          child: pw.Text(t,
                              style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  color: textDark)),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          pw.SizedBox(height: 18),

          // ── Results Table ──────────────────────────────────────────
          if (hasResults) ...[
            pw.Text('TEST RESULTS',
                style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: navyBlue,
                    letterSpacing: 0.8)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: borderGrey, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(2.5),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: navyBlue),
                  children: [
                    _resultCell('TEST PARAMETER', isHeader: true),
                    _resultCell('RESULT', isHeader: true),
                    _resultCell('UNIT', isHeader: true),
                    _resultCell('REFERENCE RANGE', isHeader: true),
                  ],
                ),
                // Data rows
                ...results.asMap().entries.map((entry) {
                  final i = entry.key;
                  final row = entry.value as Map<String, dynamic>? ?? {};
                  final isAbn = row['isAbnormal'] == true ||
                      row['is_abnormal'] == true ||
                      row['abnormal'] == true;
                  final bg = i.isEven
                      ? PdfColor.fromHex('#FAFAFA')
                      : PdfColors.white;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: bg),
                    children: [
                      _resultCell(row['testParameter']?.toString() ?? row['parameter']?.toString() ?? '—', rowBg: bg),
                      _resultCell(row['value']?.toString() ?? '—', isAbnormal: isAbn, rowBg: bg),
                      _resultCell(row['unit']?.toString() ?? '—', rowBg: bg),
                      _resultCell(row['referenceRange']?.toString() ?? row['reference_range']?.toString() ?? '—', small: true, rowBg: bg),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Row(children: [
              pw.Container(width: 10, height: 10, color: redColor),
              pw.SizedBox(width: 6),
              pw.Text('Values outside reference range are flagged',
                  style: pw.TextStyle(fontSize: 8, color: textMuted)),
            ]),
            pw.SizedBox(height: 18),
          ] else ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#FFFBEB'),
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColor.fromHex('#FDE68A')),
              ),
              child: pw.Text(
                'Detailed test results will be updated by the laboratory. '
                'Please contact the laboratory for individual parameter values.',
                style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#92400E')),
              ),
            ),
            pw.SizedBox(height: 18),
          ],

          // ── Remarks / Notes ────────────────────────────────────────
          if (hasNotes) ...[
            pw.Text('REMARKS / NOTES',
                style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: navyBlue,
                    letterSpacing: 0.8)),
            pw.SizedBox(height: 8),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: borderGrey),
              ),
              child: pw.Text(resultNotes,
                  style: pw.TextStyle(fontSize: 11, color: textDark, lineSpacing: 2)),
            ),
            pw.SizedBox(height: 18),
          ],

          // ── Verification (doctors) ────────────────────────────────
          if (doctors != null && doctors.isNotEmpty) ...[
            pw.Text('VERIFIED BY',
                style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: navyBlue,
                    letterSpacing: 0.8)),
            pw.SizedBox(height: 8),
            pw.Row(
              children: doctors.map((d) {
                final name = d['name']?.toString() ?? '';
                final edu = d['education']?.toString() ?? '';
                final desig = d['designation']?.toString() ?? '';
                return pw.Expanded(
                  child: pw.Container(
                    margin: const pw.EdgeInsets.only(right: 10),
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: borderGrey),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(name,
                            style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: textDark)),
                        if (desig.isNotEmpty)
                          pw.Text(desig,
                              style: pw.TextStyle(fontSize: 9, color: textMuted)),
                        if (edu.isNotEmpty)
                          pw.Text(edu,
                              style: pw.TextStyle(fontSize: 9, color: textMuted)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            pw.SizedBox(height: 14),
          ],

          // ── Footer ────────────────────────────────────────────────
          pw.Divider(color: borderGrey),
          pw.SizedBox(height: 8),
          // Sample collected by
          if (sampleCollectedBy != null && sampleCollectedBy.isNotEmpty) ...[
            pw.Text('Sample Collected By: $sampleCollectedBy',
                style: pw.TextStyle(fontSize: 9, color: textMuted)),
            pw.SizedBox(height: 4),
          ],
          // Verified by specific approved doctor
          if (approvedDoctorLine != null && approvedDoctorLine.isNotEmpty) ...[
            pw.Text(
              'This is an electronically generated report verified by: $approvedDoctorLine',
              style: pw.TextStyle(fontSize: 9, color: textMuted),
            ),
            pw.SizedBox(height: 4),
          ] else ...[
            pw.Text('This is an electronically generated report.',
                style: pw.TextStyle(fontSize: 9, color: textMuted)),
            pw.SizedBox(height: 4),
          ],
          // All registered doctors at the footer
          if (doctors != null && doctors.isNotEmpty) ...[
            pw.Text('Registered Doctors:',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: textMuted)),
            pw.SizedBox(height: 2),
            ...doctors.map((d) {
              final name = d['name']?.toString() ?? '';
              final edu = d['education']?.toString() ?? '';
              final desig = d['designation']?.toString() ?? '';
              final parts = [name, edu, desig].where((s) => s.isNotEmpty).join(', ');
              return pw.Text(parts, style: pw.TextStyle(fontSize: 8, color: textMuted));
            }),
            pw.SizedBox(height: 4),
          ],
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Processed by: $labName',
                  style: pw.TextStyle(fontSize: 8, color: textMuted)),
              pw.Text('Powered by iCare',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: navyBlue)),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  static pw.Widget _labInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 72,
            child: pw.Text('$label:',
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700)),
          ),
          pw.Expanded(
            child: pw.Text(value,
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey900)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _resultCell(String text,
      {bool isHeader = false,
      bool isAbnormal = false,
      bool small = false,
      PdfColor? rowBg}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 8 : (small ? 9 : 10),
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader
              ? PdfColors.white
              : (isAbnormal ? PdfColor.fromHex('#DC2626') : PdfColors.grey900),
        ),
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 12,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.grey700 : PdfColors.black,
        ),
      ),
    );
  }

  static pw.Widget _buildTotalRow(String label, double amount) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(
            fontSize: 14,
            color: PdfColors.grey700,
          ),
        ),
        pw.Text(
          'PKR ${amount.toStringAsFixed(0)}',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
