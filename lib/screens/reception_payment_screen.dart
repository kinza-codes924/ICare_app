import 'package:flutter/material.dart';
import 'package:icare/screens/reception_visit_summary.dart';
import 'package:icare/services/payment_service.dart';
import 'package:icare/services/reception_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';

class ReceptionPaymentScreen extends StatefulWidget {
  final String consultationId;
  final String patientName;

  const ReceptionPaymentScreen({
    super.key,
    required this.consultationId,
    required this.patientName,
  });

  @override
  State<ReceptionPaymentScreen> createState() => _ReceptionPaymentScreenState();
}

class _ReceptionPaymentScreenState extends State<ReceptionPaymentScreen> {
  final ReceptionService _receptionService = ReceptionService();
  final PaymentService _paymentService = PaymentService();

  bool _loading = true;
  double _total = 0;
  String _method = 'cash'; // 'cash' | 'card'
  bool _processing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _receptionService.getConsultation(widget.consultationId);
    if (!mounted) return;
    final consultation = result['consultation'] as Map?;
    final fee = (consultation?['consultationFee'] as num?)?.toDouble() ?? 0;
    final procedures = List<Map<String, dynamic>>.from(consultation?['procedures'] ?? []);
    final proceduresTotal = procedures.fold<double>(0, (sum, p) => sum + ((p['price'] as num?)?.toDouble() ?? 0));
    final subtotal = fee + proceduresTotal;
    // Displayed total mirrors what payments.js's calculateAmount() will
    // actually charge (subtotal + SRB tax) — computed the same way here so
    // the receptionist sees the real figure before confirming collection.
    final taxRate = (consultation?['taxRate'] as num?)?.toDouble() ?? 0;
    final taxAmount = subtotal * (taxRate / 100);
    setState(() {
      _total = subtotal + taxAmount;
      _loading = false;
    });
  }

  void _goToSummary() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ReceptionVisitSummary(
          consultationId: widget.consultationId,
          patientName: widget.patientName,
        ),
      ),
    );
  }

  // Both cash and card are collected in person at the front desk — the
  // patient hands over cash, or swipes their own card on the clinic's own
  // POS machine (that machine has no connection to this app at all). Either
  // way the receptionist is just confirming "payment received", so both
  // methods use the identical instant create-then-confirm flow — no online
  // checkout/gateway involved for either.
  Future<void> _collectPayment() async {
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final create = await _paymentService.createPayment(
        type: 'reception',
        refId: widget.consultationId,
        method: _method,
      );
      if (create['success'] != true && create['cash'] != true) {
        setState(() {
          _error = create['message']?.toString() ?? 'Failed to record payment';
          _processing = false;
        });
        return;
      }
      final paymentId = create['paymentId']?.toString();
      if (paymentId != null) {
        await _paymentService.markCashCollected(paymentId);
      }
      if (!mounted) return;
      _goToSummary();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _processing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Payment — ${widget.patientName}'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Back to Front Desk',
            onPressed: () => goBackOrHome(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const Text('Total Amount', style: TextStyle(color: Color(0xFF64748B))),
                              const SizedBox(height: 8),
                              Text(
                                'PKR ${_total.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_total > 0) ...[
                        const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('Cash'),
                                selected: _method == 'cash',
                                onSelected: (_) => setState(() => _method = 'cash'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('Card (Swiped)'),
                                selected: _method == 'card',
                                onSelected: (_) => setState(() => _method = 'card'),
                              ),
                            ),
                          ],
                        ),
                        if (_method == 'card') ...[
                          const SizedBox(height: 10),
                          const Text(
                            'Have the patient swipe their card on the clinic\'s card machine, then confirm below.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(_error!, style: const TextStyle(color: Colors.red)),
                        ],
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _processing ? null : _collectPayment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _processing
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(_method == 'cash' ? 'Confirm Cash Collected' : 'Confirm Card Swiped'),
                        ),
                      ] else
                        ElevatedButton(
                          onPressed: _goToSummary,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('No Payment Due — Continue'),
                        ),
                    ],
                  ),
                ),
    );
  }
}
