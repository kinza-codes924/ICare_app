import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/services/laboratory_service.dart';
import 'package:icare/services/order_service.dart';
import 'package:icare/services/payment_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

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

  void _downloadInvoice(Map<String, dynamic> p) {
    final date = p['date'] as DateTime?;
    final dateStr = date != null ? DateFormat('d MMM yyyy, hh:mm a').format(date) : 'N/A';
    final amount = (p['amount'] as double);
    final amountStr = amount > 0 ? 'Rs. ${NumberFormat('#,##0').format(amount)}' : '—';
    final ref = p['ref']?.toString() ?? '';
    final id = p['paymentId']?.toString() ?? '';

    final html_content = '''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8"/>
<title>iCare Invoice</title>
<style>
  body { font-family: Arial, sans-serif; margin: 40px; color: #0f172a; }
  .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #0036BC; padding-bottom: 20px; margin-bottom: 30px; }
  .logo { font-size: 28px; font-weight: 900; color: #0036BC; }
  .invoice-title { font-size: 14px; color: #64748b; text-align: right; }
  .invoice-title strong { font-size: 20px; color: #0f172a; display: block; }
  .section { margin-bottom: 24px; }
  .section h3 { font-size: 12px; text-transform: uppercase; letter-spacing: 1px; color: #64748b; margin-bottom: 8px; }
  .row { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #e2e8f0; }
  .row:last-child { border-bottom: none; }
  .label { color: #64748b; font-size: 14px; }
  .value { font-weight: 700; font-size: 14px; }
  .total-row { background: #eff6ff; border-radius: 8px; padding: 14px 16px; display: flex; justify-content: space-between; margin-top: 16px; }
  .total-label { font-size: 16px; font-weight: 700; }
  .total-value { font-size: 20px; font-weight: 900; color: #0036BC; }
  .badge { background: #ecfdf5; color: #059669; border-radius: 20px; padding: 4px 12px; font-size: 12px; font-weight: 700; }
  .footer { margin-top: 40px; text-align: center; color: #94a3b8; font-size: 12px; border-top: 1px solid #e2e8f0; padding-top: 20px; }
</style>
</head>
<body>
<div class="header">
  <div class="logo">iCare</div>
  <div class="invoice-title">
    <strong>INVOICE</strong>
    ${id.isNotEmpty ? '#${id.substring(0, 8).toUpperCase()}' : ''}
  </div>
</div>
<div class="section">
  <h3>Payment Details</h3>
  <div class="row"><span class="label">Description</span><span class="value">${p['title']}</span></div>
  <div class="row"><span class="label">Type</span><span class="value">${p['subtitle']}</span></div>
  <div class="row"><span class="label">Date</span><span class="value">$dateStr</span></div>
  <div class="row"><span class="label">Status</span><span class="value"><span class="badge">${p['status']}</span></span></div>
  ${ref.isNotEmpty ? '<div class="row"><span class="label">Reference</span><span class="value">$ref</span></div>' : ''}
</div>
<div class="total-row">
  <span class="total-label">Total Paid</span>
  <span class="total-value">$amountStr</span>
</div>
<div class="footer">
  iCare Virtual Hospital &nbsp;|&nbsp; icare.com.co<br/>
  This is a computer-generated invoice and does not require a signature.
</div>
</body>
</html>''';

    if (kIsWeb) {
      final blob = html.Blob([html_content], 'text/html');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'icare-invoice-${id.isNotEmpty ? id.substring(0, 8) : 'receipt'}.html')
        ..click();
      html.Url.revokeObjectUrl(url);
    }
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
            if (p['status'] == 'Paid' && kIsWeb)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _downloadInvoice(p);
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
