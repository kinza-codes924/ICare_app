import 'package:flutter/material.dart';
import 'package:icare/screens/reception_prescription_screen.dart';
import 'package:icare/services/reception_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';

class ReceptionWalkinForm extends StatefulWidget {
  const ReceptionWalkinForm({super.key});

  @override
  State<ReceptionWalkinForm> createState() => _ReceptionWalkinFormState();
}

class _ReceptionWalkinFormState extends State<ReceptionWalkinForm> {
  final ReceptionService _service = ReceptionService();
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  String? _selectedGender;
  String? _selectedDoctorId;
  List<Map<String, dynamic>> _doctors = [];
  bool _loadingDoctors = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    final result = await _service.getMyDoctors();
    if (!mounted) return;
    setState(() {
      _doctors = List<Map<String, dynamic>>.from(result['doctors'] ?? []);
      _loadingDoctors = false;
      if (_doctors.length == 1) _selectedDoctorId = _doctors.first['_id']?.toString();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDoctorId == null) {
      setState(() => _error = 'Please select a doctor');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await _service.createWalkIn(
      doctorId: _selectedDoctorId!,
      patientName: _nameCtrl.text.trim(),
      patientAge: _ageCtrl.text.trim().isEmpty ? null : _ageCtrl.text.trim(),
      patientGender: _selectedGender,
      reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result['success'] == true) {
      final consultation = result['consultation'] as Map;
      final consultationId = consultation['_id']?.toString() ?? '';
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReceptionPrescriptionScreen(
            consultationId: consultationId,
            patientName: _nameCtrl.text.trim(),
          ),
        ),
      );
    } else {
      setState(() => _error = result['message']?.toString() ?? 'Failed to create walk-in');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('New Walk-In Patient'),
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
      body: _loadingDoctors
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_doctors.isEmpty)
                      const Text(
                        'No doctors are assigned to your account yet. Contact admin.',
                        style: TextStyle(color: Colors.red),
                      )
                    else ...[
                      const Text('Doctor', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedDoctorId,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        items: _doctors.map((d) {
                          final name = d['name']?.toString() ?? '';
                          final spec = d['specialization']?.toString() ?? '';
                          return DropdownMenuItem<String>(
                            value: d['_id']?.toString(),
                            // Specialisation on its own line — the front desk
                            // picks by what the doctor treats, not just name.
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                if (spec.isNotEmpty)
                                  Text(
                                    spec,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                        selectedItemBuilder: (context) => _doctors.map((d) {
                          final name = d['name']?.toString() ?? '';
                          final spec = d['specialization']?.toString() ?? '';
                          // Collapsed state has a fixed height, so keep the
                          // selected value on one line.
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Text(spec.isEmpty ? name : '$name  ·  $spec'),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedDoctorId = v),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text('Patient Name', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Patient name is required' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Age', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _ageCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(border: OutlineInputBorder()),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Gender', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedGender,
                                decoration: const InputDecoration(border: OutlineInputBorder()),
                                items: const [
                                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                                ],
                                onChanged: (v) => setState(() => _selectedGender = v),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Reason for visit (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _reasonCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitting || _doctors.isEmpty ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _submitting
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Start Visit'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
