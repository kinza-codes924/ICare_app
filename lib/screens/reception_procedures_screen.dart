import 'package:flutter/material.dart';
import 'package:icare/screens/reception_payment_screen.dart';
import 'package:icare/services/reception_service.dart';
import 'package:icare/utils/theme.dart';

class ReceptionProceduresScreen extends StatefulWidget {
  final String consultationId;
  final String patientName;

  const ReceptionProceduresScreen({
    super.key,
    required this.consultationId,
    required this.patientName,
  });

  @override
  State<ReceptionProceduresScreen> createState() => _ReceptionProceduresScreenState();
}

class _ReceptionProceduresScreenState extends State<ReceptionProceduresScreen> {
  final ReceptionService _service = ReceptionService();
  List<Map<String, dynamic>> _procedures = [];
  bool _loading = true;
  final _taxRateCtrl = TextEditingController(text: '15');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _taxRateCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final result = await _service.getConsultation(widget.consultationId);
    if (!mounted) return;
    final consultation = result['consultation'] as Map?;
    setState(() {
      _procedures = List<Map<String, dynamic>>.from(consultation?['procedures'] ?? []);
      final taxRate = (consultation?['taxRate'] as num?)?.toDouble();
      if (taxRate != null) _taxRateCtrl.text = taxRate.toStringAsFixed(taxRate == taxRate.roundToDouble() ? 0 : 2);
      _loading = false;
    });
  }

  Future<void> _saveTaxRate() async {
    final rate = double.tryParse(_taxRateCtrl.text.trim());
    if (rate == null) return;
    await _service.setConsultationTax(consultationId: widget.consultationId, taxRate: rate);
  }

  static const _commonProcedures = [
    'Consultation',
    'Dressing',
    'Injection',
    'Minor Suture',
    'X-Ray',
    'Blood Pressure Check',
  ];

  Future<void> _addProcedure() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String? error;
    bool submitting = false;

    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.medical_services_outlined, color: AppColors.primaryColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text('Add Procedure', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Quick select', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _commonProcedures
                      .map((name) => ActionChip(
                            label: Text(name, style: const TextStyle(fontSize: 12)),
                            onPressed: () => setModal(() => nameCtrl.text = name),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Procedure name',
                    prefixIcon: const Icon(Icons.edit_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Price (PKR)',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: submitting
                          ? null
                          : () async {
                              if (nameCtrl.text.trim().isEmpty) {
                                setModal(() => error = 'Procedure name is required');
                                return;
                              }
                              setModal(() {
                                submitting = true;
                                error = null;
                              });
                              final result = await _service.addProcedure(
                                consultationId: widget.consultationId,
                                name: nameCtrl.text.trim(),
                                price: double.tryParse(priceCtrl.text.trim()) ?? 0,
                              );
                              if (result['success'] == true) {
                                if (ctx.mounted) Navigator.pop(ctx, true);
                              } else {
                                setModal(() {
                                  submitting = false;
                                  error = result['message']?.toString() ?? 'Failed to add procedure';
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: submitting
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (added == true) _load();
  }

  Future<void> _removeProcedure(String procedureId) async {
    await _service.removeProcedure(consultationId: widget.consultationId, procedureId: procedureId);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Procedures — ${widget.patientName}'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Back to Front Desk',
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_procedures.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No procedures added yet.', style: TextStyle(color: Color(0xFF64748B))),
                    ),
                  )
                else
                  ..._procedures.map((p) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.medical_services_outlined, color: AppColors.primaryColor, size: 18),
                          ),
                          title: Text(p['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('PKR ${(p['price'] as num?)?.toStringAsFixed(0) ?? '0'}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _removeProcedure(p['_id']?.toString() ?? ''),
                          ),
                        ),
                      )),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _addProcedure,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Procedure'),
                ),
                const SizedBox(height: 24),
                const Text('SRB Sales Tax Rate (%)', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: _taxRateCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  onEditingComplete: _saveTaxRate,
                  onTapOutside: (_) => _saveTaxRate(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _saveTaxRate();
                      if (!context.mounted) return;
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => ReceptionPaymentScreen(
                            consultationId: widget.consultationId,
                            patientName: widget.patientName,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Continue to Payment'),
                  ),
                ),
              ],
            ),
    );
  }
}
