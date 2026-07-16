import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:icare/screens/select_payment_method.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';

/// Shows a student's installment schedule for a course (one row per
/// installment: amount, due date, status) with a "Pay Now" button on the
/// first unpaid/overdue row. Reused both from the classroom banner and from
/// Payment History row taps.
class InstallmentScheduleScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  const InstallmentScheduleScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<InstallmentScheduleScreen> createState() => _InstallmentScheduleScreenState();
}

class _InstallmentScheduleScreenState extends State<InstallmentScheduleScreen> {
  final _lms = LmsService();
  bool _loading = true;
  List<dynamic> _installments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _lms.getCourseDetails(widget.courseId);
      final course = data['course'] ?? data;
      setState(() {
        _installments = (course is Map ? course['installments'] as List? : null) ?? [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return const Color(0xFF10B981);
      case 'overdue':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'Paid';
      case 'overdue':
        return 'Overdue';
      default:
        return 'Pending';
    }
  }

  Future<void> _payInstallment(int index, num amount) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectPaymentMethod(
          courseId: widget.courseId,
          installmentIndex: index,
          amount: amount.toDouble(),
        ),
      ),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    // First installment still pending/overdue gets the "Pay Now" CTA.
    final firstUnpaid = _installments.firstWhere(
      (i) => i['status'] != 'paid',
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const CustomBackButton(),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.courseTitle,
          style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Installment Schedule',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_installments.length} installments total',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 20),
                  ..._installments.map((inst) {
                    final index = inst['index'] as int? ?? 0;
                    final amount = (inst['amount'] as num?) ?? 0;
                    final status = inst['status']?.toString() ?? 'pending';
                    final dueDate = DateTime.tryParse(inst['dueDate']?.toString() ?? '');
                    final paidAt = DateTime.tryParse(inst['paidAt']?.toString() ?? '');
                    final isNextToPay = firstUnpaid != null && firstUnpaid['index'] == index;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: status == 'overdue' ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0), width: status == 'overdue' ? 2 : 1),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Text('Installment $index of ${_installments.length}',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(_statusLabel(status),
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _statusColor(status))),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          Text('PKR ${amount.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                          const SizedBox(height: 4),
                          Text(
                            status == 'paid'
                                ? 'Paid ${paidAt != null ? DateFormat('d MMM yyyy').format(paidAt) : ''}'
                                : 'Due ${dueDate != null ? DateFormat('d MMM yyyy').format(dueDate) : ''}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          if (isNextToPay) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => _payInstallment(index, amount),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('Pay Now', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
