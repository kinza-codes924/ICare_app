import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:icare/screens/reception_visit_summary.dart';
import 'package:icare/services/payment_service.dart';
import 'package:icare/services/reception_service.dart';
import 'package:icare/utils/theme.dart';

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
  bool _awaitingGateway = false;
  bool _pollCancelled = false;
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
    setState(() {
      _total = fee + proceduresTotal;
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

  // Cash is collected in person right now — create the payment then
  // immediately confirm it as collected.
  Future<void> _collectCash() async {
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final create = await _paymentService.createPayment(
        type: 'reception',
        refId: widget.consultationId,
        method: 'cash',
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

  // Card is a real online payment — go through the same Safepay hosted
  // checkout the rest of the app uses (course/appointment/lab), not an
  // instant "mark as paid".
  Future<void> _startCardPayment() async {
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final create = await _paymentService.createPayment(
        type: 'reception',
        refId: widget.consultationId,
        method: 'safepay',
        redirectUrl: kIsWeb ? '${Uri.base.origin}/payment-success' : null,
        cancelUrl: kIsWeb ? '${Uri.base.origin}/payment-cancelled' : null,
      );

      if (create['free'] == true) {
        if (!mounted) return;
        _goToSummary();
        return;
      }

      final checkoutUrl = create['checkoutUrl']?.toString();
      final paymentId = create['paymentId']?.toString();
      if (checkoutUrl == null || paymentId == null) {
        throw Exception('Payment gateway did not return a checkout link');
      }

      await launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);

      if (!mounted) return;
      setState(() {
        _processing = false;
        _awaitingGateway = true;
        _pollCancelled = false;
      });

      final paid = await _paymentService.pollUntilPaid(
        paymentId,
        isCancelled: () => _pollCancelled || !mounted,
      );

      if (!mounted) return;
      setState(() => _awaitingGateway = false);

      if (paid) {
        _goToSummary();
      } else if (!_pollCancelled) {
        setState(() => _error = 'Payment was not completed. The patient has not been charged — please try again.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _processing = false;
        _awaitingGateway = false;
      });
    }
  }

  Widget _buildAwaitingGateway() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            const Text(
              'Complete the payment',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'A secure Safepay checkout page has opened for the card payment. This screen updates automatically once it completes.',
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => setState(() {
                _pollCancelled = true;
                _awaitingGateway = false;
              }),
              child: const Text('Cancel payment'),
            ),
          ],
        ),
      ),
    );
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
          if (!_awaitingGateway)
            IconButton(
              icon: const Icon(Icons.home_outlined),
              tooltip: 'Back to Front Desk',
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _awaitingGateway
              ? _buildAwaitingGateway()
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
                                label: const Text('Card (Online)'),
                                selected: _method == 'card',
                                onSelected: (_) => setState(() => _method = 'card'),
                              ),
                            ),
                          ],
                        ),
                        if (_method == 'card') ...[
                          const SizedBox(height: 10),
                          const Text(
                            'Opens a secure Safepay checkout page for the patient\'s card.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(_error!, style: const TextStyle(color: Colors.red)),
                        ],
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _processing ? null : (_method == 'cash' ? _collectCash : _startCardPayment),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _processing
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(_method == 'cash' ? 'Collect Cash Payment' : 'Pay with Card'),
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
