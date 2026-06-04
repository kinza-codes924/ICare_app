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
                          color: PdfColor.fromHex('#0B2D6E'),
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
              pw.Divider(color: PdfColor.fromHex('#0B2D6E'), thickness: 2),
              pw.SizedBox(height: 16),

              // Invoice Title
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TEST INVOICE',
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
                        'Booking #$bookingNumber',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        DateFormat('MMM dd, yyyy').format(bookingDate),
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
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // Test Details
              pw.Text(
                'TEST DETAILS',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          testName,
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'PKR ${testPrice.toStringAsFixed(0)}',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#10B981'),
                          ),
                        ),
                      ],
                    ),
                    if (sampleType != null) ...[
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Sample Type: $sampleType',
                        style: const pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                    if (turnaroundTime != null) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Turnaround Time: $turnaroundTime',
                        style: const pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // Total
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8FAFC'),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL AMOUNT',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'PKR ${testPrice.toStringAsFixed(0)}',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#10B981'),
                      ),
                    ),
                  ],
                ),
              ),
              pw.Spacer(),

              // Footer
              pw.Divider(color: PdfColor.fromHex('#E2E8F0')),
              pw.SizedBox(height: 8),
              if (sampleCollectedBy != null && sampleCollectedBy.isNotEmpty)
                pw.Text(
                  'Sample Collected By: $sampleCollectedBy',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
              if (doctors != null && doctors.isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Text(
                  'This is an electronically generated report verified by:',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 4),
                ...doctors.map((d) {
                  final name = d['name']?.toString() ?? '';
                  final edu = d['education']?.toString() ?? '';
                  final desig = d['designation']?.toString() ?? '';
                  final parts = [name, edu, desig].where((s) => s.isNotEmpty).join(', ');
                  return pw.Text(parts, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700));
                }),
                pw.SizedBox(height: 6),
              ],
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Processed by: $labName',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'Powered by iCare',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#0B2D6E'),
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
