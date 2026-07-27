import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/services/laboratory_service.dart';
import 'package:icare/services/order_service.dart';
import 'package:icare/services/payment_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Payment history for Patients (appointments, pharmacy orders, lab bookings)
/// and Students (course purchases).
class PaymentHistoryScreen extends StatefulWidget {
  final String role; // 'Patient' | 'Student'
  const PaymentHistoryScreen({super.key, required this.role});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _payments = [];

  bool get _isStudent => widget.role == 'Student';

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    final rows = <Map<String, dynamic>>[];
    try {
      if (_isStudent) {
        final payments = await PaymentService().myPayments();
        for (final p in payments) {
          final type = p['type']?.toString();
          if (type != 'course' && type != 'course_installment') continue;
          final amount = (p['amount'] is num) ? (p['amount'] as num).toDouble() : 0.0;
          final status = (p['status'] ?? '').toString();
          rows.add({
            'title': p['displayLabel']?.toString() ?? 'Course',
            'subtitle': type == 'course_installment' ? 'Installment payment' : 'Course enrollment',
            'icon': Icons.school_rounded,
            'color': const Color(0xFF6366F1),
            'amount': amount,
            'date': _parseDate(p['paidAt'] ?? p['createdAt']),
            'status': status == 'paid'
                ? 'Paid'
                : (status == 'failed' || status == 'cancelled' || status == 'expired'
                    ? 'Cancelled'
                    : 'Pending'),
            'paymentId': p['_id']?.toString() ?? '',
            'ref': p['tracker']?.toString() ?? p['refId']?.toString() ?? '',
            'type': type,
          });
        }
      } else {
        try {
          final res = await ApiService().get('/appointments/getAppointments');
          final appts = (res.data['appointments'] as List?) ?? [];
          for (final a in appts) {
            if (a is! Map) continue;
            final doctor = a['doctor'];
            final doctorName = (doctor is Map ? doctor['name'] : null) ?? a['doctorName'] ?? 'Doctor';
            final fee = a['fee'] ?? a['consultationFee'] ?? a['amount'] ??
                (doctor is Map ? doctor['fee'] ?? doctor['consultationFee'] : null);
            final feeVal = (fee is num) ? fee.toDouble() : 0.0;
            final status = (a['status'] ?? '').toString();
            rows.add({
              'title': 'Consultation — $doctorName',
              'subtitle': 'Appointment',
              'icon': Icons.medical_services_rounded,
              'color': const Color(0xFF0036BC),
              'amount': feeVal,
              'date': _parseDate(a['appointmentDate'] ?? a['date'] ?? a['createdAt']),
              'status': status == 'cancelled' ? 'Cancelled' : (status == 'completed' ? 'Paid' : 'Pending'),
              'paymentId': a['_id']?.toString() ?? '',
              'ref': '',
              'type': 'appointment',
            });
          }
        } catch (_) {}

        try {
          final orders = await OrderService().getMyOrders();
          for (final o in orders) {
            if (o is! Map) continue;
            final amount = (o['totalAmount'] ?? o['total'] ?? 0);
            final status = (o['status'] ?? '').toString();
            rows.add({
              'title': o['orderNumber']?.toString() ?? 'Pharmacy Order',
              'subtitle': 'Pharmacy order',
              'icon': Icons.local_pharmacy_rounded,
              'color': const Color(0xFF10B981),
              'amount': (amount is num) ? amount.toDouble() : 0.0,
              'date': _parseDate(o['createdAt']),
              'status': status == 'completed' ? 'Paid' : (status == 'cancelled' || status == 'rejected' ? 'Cancelled' : 'Pending'),
              'paymentId': o['_id']?.toString() ?? '',
              'ref': o['orderNumber']?.toString() ?? '',
              'type': 'pharmacy',
            });
          }
        } catch (_) {}

        try {
          final bookings = await LaboratoryService().getMyBookings();
          for (final b in bookings) {
            if (b is! Map) continue;
            final amount = (b['price'] ?? b['amount'] ?? b['totalAmount'] ?? 0);
            final status = (b['status'] ?? '').toString();
            rows.add({
              'title': b['test_type'] ?? b['testName'] ?? 'Lab Test',
              'subtitle': 'Laboratory booking',
              'icon': Icons.biotech_rounded,
              'color': const Color(0xFF8B5CF6),
              'amount': (amount is num) ? amount.toDouble() : 0.0,
              'date': _parseDate(b['createdAt'] ?? b['test_date']),
              'status': status == 'completed' ? 'Paid' : (status == 'cancelled' ? 'Cancelled' : 'Pending'),
              'paymentId': b['_id']?.toString() ?? '',
              'ref': '',
              'type': 'lab',
            });
          }
        } catch (_) {}
      }
    } catch (_) {}

    rows.sort((a, b) {
      final da = a['date'] as DateTime?;
      final db = b['date'] as DateTime?;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

    if (mounted) {
      setState(() {
        _payments = rows;
        _loading = false;
      });
    }
  }

  Future<void> _downloadInvoice(Map<String, dynamic> p) async {
    final date = p['date'] as DateTime?;
    final dateStr = date != null ? DateFormat('d MMM yyyy, hh:mm a').format(date) : 'N/A';
    final amount = (p['amount'] as double);
    final amountStr = amount > 0 ? 'Rs. ${NumberFormat('#,##0').format(amount)}' : '—';
    final ref = p['ref']?.toString() ?? '';
    final id = p['paymentId']?.toString() ?? '';
    final invoiceNo = id.isNotEmpty ? id.substring(0, 8).toUpperCase() : 'N/A';

    // Load logo
    pw.ImageProvider? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    final primaryColor = PdfColor.fromHex('#0036BC');
    final greyColor = PdfColor.fromHex('#64748B');
    final lightBlue = PdfColor.fromHex('#EFF6FF');
    final borderColor = PdfColor.fromHex('#E2E8F0');
    final greenColor = PdfColor.fromHex('#059669');

    final doc = pw.Document();

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header: logo + INVOICE label
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logoImage != null)
                  pw.Image(logoImage, width: 100, height: 40, fit: pw.BoxFit.contain)
                else
                  pw.Text('iCare',
                      style: pw.TextStyle(
                          fontSize: 26,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor)),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('INVOICE',
                        style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor)),
                    pw.SizedBox(height: 4),
                    pw.Text('#$invoiceNo',
                        style: pw.TextStyle(fontSize: 12, color: greyColor)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: primaryColor, thickness: 2),
            pw.SizedBox(height: 20),

            // Issued to / Date
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ISSUED BY',
                        style: pw.TextStyle(fontSize: 9, color: greyColor,
                            letterSpacing: 1)),
                    pw.SizedBox(height: 4),
                    pw.Text('iCare Virtual Hospital',
                        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                    pw.Text('icare.com.co',
                        style: pw.TextStyle(fontSize: 11, color: greyColor)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('DATE',
                        style: pw.TextStyle(fontSize: 9, color: greyColor,
                            letterSpacing: 1)),
                    pw.SizedBox(height: 4),
                    pw.Text(dateStr,
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            // Payment details table
            pw.Text('PAYMENT DETAILS',
                style: pw.TextStyle(fontSize: 9, color: greyColor, letterSpacing: 1)),
            pw.SizedBox(height: 8),
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: borderColor),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                children: [
                  _pdfRow('Description', p['title'].toString(), primaryColor, borderColor, isFirst: true),
                  _pdfRow('Type', p['subtitle'].toString(), primaryColor, borderColor),
                  _pdfRow('Date', dateStr, primaryColor, borderColor),
                  _pdfRow('Status', p['status'].toString(), primaryColor, borderColor,
                      valueColor: greenColor),
                  if (ref.isNotEmpty)
                    _pdfRow('Reference', ref, primaryColor, borderColor),
                  if (id.isNotEmpty)
                    _pdfRow('Payment ID', id, primaryColor, borderColor, isLast: true),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Total box
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: pw.BoxDecoration(
                color: lightBlue,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Paid',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text(amountStr,
                      style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor)),
                ],
              ),
            ),

            pw.Spacer(),

            // Footer
            pw.Divider(color: borderColor),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'iCare Virtual Hospital  |  icare.com.co\n'
                'This is a computer-generated invoice and does not require a signature.',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 9, color: greyColor),
              ),
            ),
          ],
        );
      },
    ));

    final Uint8List pdfBytes = await doc.save();

    try {
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'icare-invoice-$invoiceNo.pdf')
        ..click();
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      debugPrint('Failed to download invoice PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not download invoice. Please try again.')),
        );
      }
    }
  }

  pw.Widget _pdfRow(
    String label,
    String value,
    PdfColor primary,
    PdfColor border, {
    bool isFirst = false,
    bool isLast = false,
    PdfColor? valueColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: isLast ? pw.BorderSide.none : pw.BorderSide(color: border),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(fontSize: 12, color: PdfColor.fromHex('#64748B'))),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: valueColor ?? PdfColor.fromHex('#0F172A'))),
        ],
      ),
    );
  }

  void _showDetail(Map<String, dynamic> p) {
    final date = p['date'] as DateTime?;
    final dateStr = date != null ? DateFormat('d MMM yyyy, hh:mm a').format(date) : 'N/A';
    final amount = (p['amount'] as double);
    final statusColor = p['status'] == 'Paid'
        ? const Color(0xFF10B981)
        : p['status'] == 'Cancelled'
            ? const Color(0xFFEF4444)
            : const Color(0xFFF59E0B);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (p['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(p['icon'] as IconData, color: p['color'] as Color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['title'].toString(),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                      Text(p['subtitle'].toString(),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _detailRow('Date', dateStr),
            _detailRow('Amount', amount > 0 ? 'Rs. ${NumberFormat('#,##0').format(amount)}' : '—'),
            _detailRow('Status', p['status'].toString(), valueColor: statusColor),
            if ((p['ref']?.toString() ?? '').isNotEmpty)
              _detailRow('Reference', p['ref'].toString()),
            if ((p['paymentId']?.toString() ?? '').isNotEmpty)
              _detailRow('Payment ID', p['paymentId'].toString()),
            const SizedBox(height: 20),
            if (p['status'] == 'Paid')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _downloadInvoice(p);  // async — fire and forget
                  },
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Download Invoice',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? const Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _payments
        .where((p) => p['status'] == 'Paid')
        .fold<double>(0, (sum, p) => sum + (p['amount'] as double));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: const Text('Payment History',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF0036BC), Color(0xFF2563EB)]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Spent',
                              style: TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 6),
                          Text('Rs. ${NumberFormat('#,##0').format(total)}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text('${_payments.length} transactions',
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _payments.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.receipt_long_rounded,
                                      size: 64, color: Colors.grey.shade300),
                                  const SizedBox(height: 16),
                                  const Text('No payments yet',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A))),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                itemCount: _payments.length,
                                itemBuilder: (_, i) {
                                  final p = _payments[i];
                                  final date = p['date'] as DateTime?;
                                  final status = p['status'] as String;
                                  final statusColor = status == 'Paid'
                                      ? const Color(0xFF10B981)
                                      : status == 'Cancelled'
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFFF59E0B);
                                  return InkWell(
                                    onTap: () => _showDetail(p),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: (p['color'] as Color).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(p['icon'] as IconData,
                                                color: p['color'] as Color, size: 22),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(p['title'].toString(),
                                                    style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w700,
                                                        color: Color(0xFF0F172A)),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${p['subtitle']}${date != null ? ' · ${DateFormat('d MMM yyyy').format(date)}' : ''}',
                                                  style: const TextStyle(
                                                      fontSize: 12, color: Color(0xFF64748B)),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                (p['amount'] as double) > 0
                                                    ? 'Rs. ${NumberFormat('#,##0').format(p['amount'])}'
                                                    : '—',
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF0F172A)),
                                              ),
                                              const SizedBox(height: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Text(status,
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w800,
                                                        color: statusColor)),
                                              ),
                                              const SizedBox(height: 4),
                                              const Icon(Icons.chevron_right_rounded,
                                                  size: 16, color: Color(0xFF94A3B8)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}