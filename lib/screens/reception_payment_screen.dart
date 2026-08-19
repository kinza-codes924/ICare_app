import 'package:flutter/material.dart';
import 'package:icare/screens/reception_visit_summary.dart';
import 'package:icare/services/api_service.dart';
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
  final ApiService _api = ApiService();

  bool _loading = true;
  double _total = 0;
  String _method = 'cash';
  bool _collecting = false;
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

  Future<void> _collectPayment() async {
    setState(() {
      _collecting = true;
      _error = null;
    });
    try {
      final createResponse = await _api.post('/payments/create', {
        'type': 'reception',
        'refId': widget.consultationId,
        'method': _method,
      });
      final createData = createResponse.data;
      if (createData is! Map || createData['success'] != true) {
        setState(() {
          _error = createData is Map ? createData['message']?.toString() : 'Failed to record payment';
          _collecting = false;
        });
        return;
      }
      final paymentId = createData['paymentId']?.toString();
      if (paymentId != null) {
        await _api.post('/payments/$paymentId/cash-collected', {});
      }
      if (!mounted) return;
      _goToSummary();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _collecting = false;
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
                            label: const Text('Card'),
                            selected: _method == 'card',
                            onSelected: (_) => setState(() => _method = 'card'),
                          ),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _collecting ? null : _collectPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _collecting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Collect Payment'),
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
