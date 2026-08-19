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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _service.getConsultation(widget.consultationId);
    if (!mounted) return;
    final consultation = result['consultation'] as Map?;
    setState(() {
      _procedures = List<Map<String, dynamic>>.from(consultation?['procedures'] ?? []);
      _loading = false;
    });
  }

  Future<void> _addProcedure() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Procedure'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Procedure name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price (PKR)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final result = await _service.addProcedure(
                consultationId: widget.consultationId,
                name: nameCtrl.text.trim(),
                price: double.tryParse(priceCtrl.text.trim()) ?? 0,
              );
              if (ctx.mounted) Navigator.pop(ctx, result['success'] == true);
            },
            child: const Text('Add'),
          ),
        ],
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
                        child: ListTile(
                          title: Text(p['name']?.toString() ?? ''),
                          subtitle: Text('PKR ${p['price'] ?? 0}'),
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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
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
