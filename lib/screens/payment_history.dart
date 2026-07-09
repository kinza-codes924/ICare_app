import 'package:flutter/material.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/services/course_service.dart';
import 'package:icare/services/laboratory_service.dart';
import 'package:icare/services/order_service.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';

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
        // Course purchases
        final enrollments = await CourseService().myPurchases();
        for (final e in enrollments) {
          final course = e['course'];
          if (course is! Map) continue;
          final price = (course['price'] is num) ? (course['price'] as num).toDouble() : 0.0;
          rows.add({
            'title': course['title'] ?? course['name'] ?? 'Course',
            'subtitle': 'Course enrollment',
            'icon': Icons.school_rounded,
            'color': const Color(0xFF6366F1),
            'amount': price,
            'date': _parseDate(e['createdAt'] ?? e['enrolledAt']),
            'status': price > 0 ? 'Paid' : 'Free',
          });
        }
      } else {
        // Patient: appointments + pharmacy orders + lab bookings (each best-effort)
        try {
          final res = await ApiService().get('/appointments/getAppointments');
          final appts = (res.data['appointments'] as List?) ?? [];
          for (final a in appts) {
            if (a is! Map) continue;
            final doctor = a['doctor'];
            final doctorName = (doctor is Map ? doctor['name'] : null) ??
                a['doctorName'] ?? 'Doctor';
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
              'status': status == 'cancelled'
                  ? 'Cancelled'
                  : (status == 'completed' ? 'Paid' : 'Pending'),
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
              'status': status == 'completed'
                  ? 'Paid'
                  : (status == 'cancelled' || status == 'rejected'
                      ? 'Cancelled'
                      : 'Pending'),
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
              'status': status == 'completed'
                  ? 'Paid'
                  : (status == 'cancelled' ? 'Cancelled' : 'Pending'),
            });
          }
        } catch (_) {}
      }
    } catch (_) {}

    // Newest first
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
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A))),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  children: [
                    // Total spent card
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0036BC), Color(0xFF2563EB)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Spent',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 6),
                          Text('Rs. ${NumberFormat('#,##0').format(total)}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text('${_payments.length} transactions',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
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
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                itemCount: _payments.length,
                                itemBuilder: (_, i) {
                                  final p = _payments[i];
                                  final date = p['date'] as DateTime?;
                                  final status = p['status'] as String;
                                  final statusColor = status == 'Paid'
                                      ? const Color(0xFF10B981)
                                      : status == 'Cancelled'
                                          ? const Color(0xFFEF4444)
                                          : status == 'Free'
                                              ? const Color(0xFF6366F1)
                                              : const Color(0xFFF59E0B);
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: (p['color'] as Color)
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Icon(p['icon'] as IconData,
                                              color: p['color'] as Color,
                                              size: 22),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(p['title'].toString(),
                                                  style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          Color(0xFF0F172A)),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${p['subtitle']}${date != null ? ' · ${DateFormat('d MMM yyyy').format(date)}' : ''}',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF64748B)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color: statusColor.withValues(
                                                    alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(status,
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: statusColor)),
                                            ),
                                          ],
                                        ),
                                      ],
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
