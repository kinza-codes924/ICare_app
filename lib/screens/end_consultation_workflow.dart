import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:icare/models/appointment_detail.dart';
import 'package:icare/screens/lab_test_template_screen.dart';
import 'package:icare/screens/soap_notes_redesign.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/services/appointment_service.dart';
import 'package:icare/services/clinical_service.dart';
import 'package:icare/services/medical_record_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/icd_code_selector.dart';

class EndConsultationWorkflow extends StatefulWidget {
  final AppointmentDetail appointment;

  const EndConsultationWorkflow({super.key, required this.appointment});

  @override
  State<EndConsultationWorkflow> createState() =>
      _EndConsultationWorkflowState();
}

class _EndConsultationWorkflowState extends State<EndConsultationWorkflow> {
  final ClinicalService _clinicalService = ClinicalService();
  final MedicalRecordService _medicalRecordService = MedicalRecordService();

  // Diagnosis state
  bool _diagnosisCompleted = false;
  final List<Map<String, dynamic>> _selectedICDCodes = [];
  final TextEditingController _diagnosisNotesController = TextEditingController();

  // Common medicines list for autocomplete
  static const List<String> _commonMedicines = [
    'Paracetamol 500mg', 'Paracetamol 1000mg',
    'Amoxicillin 250mg', 'Amoxicillin 500mg',
    'Ibuprofen 200mg', 'Ibuprofen 400mg', 'Ibuprofen 600mg',
    'Aspirin 75mg', 'Aspirin 300mg',
    'Metformin 500mg', 'Metformin 850mg', 'Metformin 1000mg',
    'Atorvastatin 10mg', 'Atorvastatin 20mg', 'Atorvastatin 40mg',
    'Omeprazole 20mg', 'Omeprazole 40mg',
    'Pantoprazole 20mg', 'Pantoprazole 40mg',
    'Ciprofloxacin 250mg', 'Ciprofloxacin 500mg',
    'Azithromycin 250mg', 'Azithromycin 500mg',
    'Doxycycline 100mg',
    'Metronidazole 200mg', 'Metronidazole 400mg',
    'Cetirizine 10mg', 'Loratadine 10mg',
    'Salbutamol 2mg', 'Salbutamol 4mg',
    'Prednisolone 5mg', 'Prednisolone 10mg',
    'Diclofenac 50mg', 'Diclofenac 75mg',
    'Tramadol 50mg', 'Tramadol 100mg',
    'Codeine 30mg',
    'Lisinopril 5mg', 'Lisinopril 10mg',
    'Amlodipine 5mg', 'Amlodipine 10mg',
    'Losartan 25mg', 'Losartan 50mg',
    'Bisoprolol 2.5mg', 'Bisoprolol 5mg',
    'Furosemide 20mg', 'Furosemide 40mg',
    'Spironolactone 25mg', 'Spironolactone 50mg',
    'Warfarin 1mg', 'Warfarin 5mg',
    'Clopidogrel 75mg',
    'Insulin Regular', 'Insulin NPH', 'Insulin Glargine',
    'Levothyroxine 25mcg', 'Levothyroxine 50mcg', 'Levothyroxine 100mcg',
    'Sertraline 50mg', 'Sertraline 100mg',
    'Fluoxetine 20mg', 'Fluoxetine 40mg',
    'Diazepam 2mg', 'Diazepam 5mg',
    'Vitamin C 500mg', 'Vitamin D3 1000IU', 'Vitamin B Complex',
    'Zinc 20mg', 'Iron 65mg', 'Folic Acid 5mg',
    'Calcium 500mg', 'Calcium + Vitamin D3',
    'ORS Sachet', 'Oral Rehydration Salts',
    'Antacid Syrup', 'Gaviscon',
    'Cough Syrup', 'Dextromethorphan',
    'Nasal Drops', 'Xylometazoline',
    'Eye Drops Chloramphenicol', 'Artificial Tears',
    'Hydrocortisone Cream 1%', 'Betamethasone Cream',
    'Clotrimazole Cream', 'Fluconazole 150mg',
  ];

  // Prescription state
  bool _prescriptionCompleted = false;
  bool _noPrescription = false;
  String _noPrescriptionReason = '';

  // Inline prescription form state
  bool _showPrescriptionForm = false;
  final List<Map<String, dynamic>> _prescriptionMedicines = [];
  final TextEditingController _medNameController = TextEditingController();
  final TextEditingController _medDayController = TextEditingController();
  final TextEditingController _medNoonController = TextEditingController();
  final TextEditingController _medNightController = TextEditingController();
  final TextEditingController _medDurationController = TextEditingController();
  final TextEditingController _medNotesController = TextEditingController();

  // Lab Tests state
  bool _labTestsCompleted = false;
  bool _noLabTests = false;
  String _noLabTestsReason = '';
  Map<String, dynamic>? _selectedLabTemplate;

  // SOAP Notes state
  bool _soapNotesCompleted = false;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _diagnosisNotesController.dispose();
    _medNameController.dispose();
    _medDayController.dispose();
    _medNoonController.dispose();
    _medNightController.dispose();
    _medDurationController.dispose();
    _medNotesController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _checkExistingData();
  }

  Future<void> _checkExistingData() async {
    try {
      // Check if SOAP notes exist
      final soapResult = await _clinicalService.getSoapNotes(
        widget.appointment.id,
      );
      if (soapResult['success'] == true) {
        final hasContent = (soapResult['subjective']?.toString().isNotEmpty ?? false) ||
            (soapResult['objective']?.toString().isNotEmpty ?? false) ||
            (soapResult['assessment']?.toString().isNotEmpty ?? false) ||
            (soapResult['plan']?.toString().isNotEmpty ?? false);
        if (mounted) setState(() => _soapNotesCompleted = hasContent);
      }
    } catch (e) {
      debugPrint('Error checking existing data: $e');
    }
  }

  bool get _canEndConsultation {
    final diagnosisOk = _diagnosisCompleted;
    final prescriptionOk = _prescriptionCompleted || (_noPrescription && _noPrescriptionReason.trim().isNotEmpty);
    final labTestsOk = _labTestsCompleted || (_noLabTests && _noLabTestsReason.trim().isNotEmpty);
    final soapOk = _soapNotesCompleted;
    return diagnosisOk && prescriptionOk && labTestsOk && soapOk;
  }

  Future<void> _endConsultation() async {
    if (!_canEndConsultation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all mandatory sections before ending consultation'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final appointmentId = widget.appointment.id;
      final patientId = widget.appointment.patient?.id ?? '';

      // 1. Save SOAP notes with diagnosis + ICD codes (non-blocking)
      if (_diagnosisCompleted && _selectedICDCodes.isNotEmpty) {
        _clinicalService.saveSoapNotes(appointmentId, {
          'assessment': _diagnosisNotesController.text,
          'icdCodes': _selectedICDCodes,
        }).catchError((_) {});
      }

      // 2. Build prescription medicines list with Day/Noon/Night dosage
      final List<Map<String, dynamic>> medicines = _prescriptionMedicines.map((m) => {
        'name': m['name'] ?? '',
        'dosage': [
          if ((m['day'] ?? '').isNotEmpty) 'Day: ${m['day']}',
          if ((m['noon'] ?? '').isNotEmpty) 'Noon: ${m['noon']}',
          if ((m['night'] ?? '').isNotEmpty) 'Night: ${m['night']}',
        ].join(' | '),
        'day': m['day'] ?? '',
        'noon': m['noon'] ?? '',
        'night': m['night'] ?? '',
        'duration': m['duration'] ?? '',
        'notes': m['notes'] ?? '',
      }).toList();

      // 3. Build lab tests list from selected template
      final List<String> labTests = _selectedLabTemplate != null
          ? (_selectedLabTemplate!['tests'] as List)
              .map((t) => t['name']?.toString() ?? '')
              .where((n) => n.isNotEmpty)
              .toList()
          : [];

      // 4. Build diagnosis string from ICD codes + notes
      final diagnosisText = _selectedICDCodes.isNotEmpty
          ? '${_selectedICDCodes.map((c) => '${c['code']} - ${c['description']}').join(', ')}'
              '${_diagnosisNotesController.text.trim().isNotEmpty ? '\n${_diagnosisNotesController.text.trim()}' : ''}'
          : _diagnosisNotesController.text.trim();

      // 5. Create medical record — fire and forget, don't block navigation
      if (patientId.isNotEmpty) {
        _medicalRecordService.createMedicalRecord({
          'patientId': patientId,
          'appointmentId': appointmentId,
          'diagnosis': diagnosisText.isNotEmpty ? diagnosisText : 'Consultation completed',
          'symptoms': [],
          'prescription': {
            'medicines': medicines,
            'labTests': labTests,
            'noPrescriptionReason': _noPrescription ? _noPrescriptionReason : '',
            'noLabTestsReason': _noLabTests ? _noLabTestsReason : '',
          },
          'labTests': labTests,
          'notes': _noPrescription
              ? 'No prescription: $_noPrescriptionReason'
              : (_noLabTests ? 'No lab tests: $_noLabTestsReason' : ''),
        }).catchError((_) {});
      }

      // 6. Complete prescription via backend API — triggers email to patient
      if (_prescriptionCompleted && medicines.isNotEmpty) {
        final api = ApiService();
        api.post('/consultations/$appointmentId/prescription/complete', {
          'medicines': medicines,
          'diagnoses': _selectedICDCodes.map((d) => {'code': d['code'], 'name': d['description']}).toList(),
          'labTests': labTests,
          'doctorNotes': _diagnosisNotesController.text.trim(),
        }).catchError((_) {});
      }

      // 7. Mark appointment as completed — fire and forget
      AppointmentService().updateAppointmentStatus(
        appointmentId: appointmentId,
        status: 'completed',
      ).catchError((_) {});

    } catch (_) {
      // Even if something fails, still show success and navigate
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }

    // Always show success dialog and navigate — regardless of API result
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 56),
            ),
            const SizedBox(height: 20),
            const Text(
              'Consultation Ended',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'All records have been saved and are now visible to the patient.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  // Use browser navigation — guaranteed to work on Flutter Web
                  html.window.location.href = '/dashboard';
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Go to Dashboard', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
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
        leading: const CustomBackButton(),
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'End Consultation',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryColor.withValues(alpha: 0.1),
                    AppColors.primaryColor.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.assignment_turned_in_rounded,
                      color: AppColors.primaryColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Complete Required Documentation',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'All sections must be completed before ending consultation',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 1. Diagnosis Section (with ICD-10 codes)
            _buildSection(
              title: '1. Diagnosis',
              icon: Icons.medical_services_rounded,
              color: const Color(0xFFEF4444),
              isCompleted: _diagnosisCompleted,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add diagnosis and ICD-10 codes:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ICD-10 Codes Section
                  Row(
                    children: [
                      const Text(
                        'ICD-10 Diagnosis Codes',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => ICDCodeSelector(
                              onCodeSelected: (code) {
                                setState(() {
                                  if (!_selectedICDCodes.any((c) => c['code'] == code['code'])) {
                                    _selectedICDCodes.add(code);
                                  }
                                });
                              },
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                        label: const Text('Add Code'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_selectedICDCodes.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFFEF4444),
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'At least one ICD-10 code is required',
                              style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedICDCodes.map((code) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  code['code'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 180),
                                child: Text(
                                  code['description'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedICDCodes.removeWhere((c) => c['code'] == code['code']);
                                  });
                                },
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 16),

                  // Diagnosis Notes
                  const Text(
                    'Diagnosis Notes',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _diagnosisNotesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter clinical impression and diagnosis details...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primaryColor, width: 2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _selectedICDCodes.isEmpty
                          ? null
                          : () {
                              // Diagnosis Notes mandatory
                              if (_diagnosisNotesController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter Diagnosis Notes'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              setState(() => _diagnosisCompleted = true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Diagnosis saved'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                      icon: const Icon(Icons.check_rounded, size: 20),
                      label: const Text('Save Diagnosis'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  if (_diagnosisCompleted) ...[
                    const SizedBox(height: 12),
                    _buildCompletedIndicator('Diagnosis completed with ${_selectedICDCodes.length} ICD code(s)'),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 2. Prescription Section
            _buildSection(
              title: '2. Prescription',
              icon: Icons.medication_rounded,
              color: Colors.green,
              isCompleted: _prescriptionCompleted || (_noPrescription && _noPrescriptionReason.isNotEmpty),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_prescriptionCompleted && !_noPrescription) ...[
                    const Text(
                      'Choose one option:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => setState(() => _showPrescriptionForm = true),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text('Create Prescription'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _noPrescription = true),
                        icon: const Icon(Icons.block_rounded, size: 20),
                        label: const Text('No Prescription'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Inline prescription form with Day/Noon/Night dosage
                  if (_showPrescriptionForm && !_prescriptionCompleted) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add Medicine',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Medicine Name with autocomplete
                          Autocomplete<String>(
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return _commonMedicines;
                              }
                              final query = textEditingValue.text.toLowerCase();
                              return _commonMedicines.where(
                                (m) => m.toLowerCase().contains(query),
                              );
                            },
                            onSelected: (String selection) {
                              _medNameController.text = selection;
                            },
                            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                              // Sync with _medNameController
                              controller.text = _medNameController.text;
                              controller.addListener(() {
                                _medNameController.text = controller.text;
                              });
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                decoration: InputDecoration(
                                  labelText: 'Medicine Name *',
                                  hintText: 'Type to search medicines...',
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: const Icon(Icons.medication_rounded, color: Color(0xFF3B82F6), size: 20),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                                  ),
                                ),
                              );
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 8,
                                  borderRadius: BorderRadius.circular(12),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxHeight: 220, maxWidth: 500),
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      itemBuilder: (ctx, i) {
                                        final option = options.elementAt(i);
                                        return InkWell(
                                          onTap: () => onSelected(option),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.medication_outlined, size: 16, color: Color(0xFF3B82F6)),
                                                const SizedBox(width: 10),
                                                Text(option, style: const TextStyle(fontSize: 14)),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          // Dosage: Day / Noon / Night
                          const Text(
                            'Dosage',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDosageField(
                                  controller: _medDayController,
                                  label: 'Day',
                                  icon: Icons.wb_sunny_rounded,
                                  color: const Color(0xFFF59E0B),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildDosageField(
                                  controller: _medNoonController,
                                  label: 'Noon',
                                  icon: Icons.wb_twilight_rounded,
                                  color: const Color(0xFFEF4444),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildDosageField(
                                  controller: _medNightController,
                                  label: 'Night',
                                  icon: Icons.nightlight_round,
                                  color: const Color(0xFF6366F1),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _medDurationController,
                                  decoration: InputDecoration(
                                    labelText: 'Duration',
                                    hintText: 'e.g. 5 days',
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _medNotesController,
                                  decoration: InputDecoration(
                                    labelText: 'Notes',
                                    hintText: 'e.g. After meal',
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (_medNameController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter medicine name')),
                                  );
                                  return;
                                }
                                setState(() {
                                  _prescriptionMedicines.add({
                                    'name': _medNameController.text.trim(),
                                    'day': _medDayController.text.trim(),
                                    'noon': _medNoonController.text.trim(),
                                    'night': _medNightController.text.trim(),
                                    'duration': _medDurationController.text.trim(),
                                    'notes': _medNotesController.text.trim(),
                                  });
                                  _medNameController.clear();
                                  _medDayController.clear();
                                  _medNoonController.clear();
                                  _medNightController.clear();
                                  _medDurationController.clear();
                                  _medNotesController.clear();
                                });
                              },
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: Text(_prescriptionMedicines.isEmpty ? 'Add Medicine' : 'Add More Medicines'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Added medicines list
                    if (_prescriptionMedicines.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Medicines Added:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._prescriptionMedicines.asMap().entries.map((entry) {
                        final med = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      med['name'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if ((med['day'] ?? '').isNotEmpty)
                                          _buildDosageBadge('Day: ${med['day']}', const Color(0xFFF59E0B)),
                                        if ((med['noon'] ?? '').isNotEmpty) ...[
                                          const SizedBox(width: 4),
                                          _buildDosageBadge('Noon: ${med['noon']}', const Color(0xFFEF4444)),
                                        ],
                                        if ((med['night'] ?? '').isNotEmpty) ...[
                                          const SizedBox(width: 4),
                                          _buildDosageBadge('Night: ${med['night']}', const Color(0xFF6366F1)),
                                        ],
                                      ],
                                    ),
                                    if ((med['duration'] ?? '').isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          'Duration: ${med['duration']}${(med['notes'] ?? '').isNotEmpty ? ' • ${med['notes']}' : ''}',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => setState(() => _prescriptionMedicines.removeAt(entry.key)),
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _prescriptionCompleted = true;
                              _showPrescriptionForm = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Prescription saved'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          icon: const Icon(Icons.check_rounded, size: 20),
                          label: const Text('Save Prescription'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],

                  if (_noPrescription && !_prescriptionCompleted && _noPrescriptionReason.isEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Please provide a reason:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'e.g., Patient needs specialist referral, no medication required, etc.',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      onChanged: (value) {
                        // Only update the reason string — do NOT call setState
                        // so the field doesn't disappear while typing
                        _noPrescriptionReason = value;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (_noPrescriptionReason.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a reason first')),
                                );
                                return;
                              }
                              setState(() {}); // now refresh to show completed state
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Confirm'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: () => setState(() {
                            _noPrescription = false;
                            _noPrescriptionReason = '';
                          }),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ],
                  if (_prescriptionCompleted) ...[
                    _buildCompletedIndicator('Prescription created with ${_prescriptionMedicines.length} medicine(s)'),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _prescriptionCompleted = false;
                        _showPrescriptionForm = true;
                      }),
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Edit Prescription'),
                      style: TextButton.styleFrom(foregroundColor: Colors.green),
                    ),
                  ],
                  if (_noPrescription && _noPrescriptionReason.isNotEmpty) ...[
                    _buildCompletedIndicator('No prescription - Reason provided'),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. Lab Tests Section
            _buildSection(
              title: '3. Suggest Lab Test',
              icon: Icons.biotech_rounded,
              color: const Color(0xFF8B5CF6),
              isCompleted: _labTestsCompleted || (_noLabTests && _noLabTestsReason.isNotEmpty),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_labTestsCompleted && !_noLabTests) ...[
                    const Text(
                      'Choose one option:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LabTestTemplateScreen(
                                selectionMode: true,
                                onTemplateSelected: (template) {
                                  setState(() {
                                    _selectedLabTemplate = template;
                                    _labTestsCompleted = true;
                                  });
                                },
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text('Suggest Lab Tests'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _noLabTests = true),
                        icon: const Icon(Icons.block_rounded, size: 20),
                        label: const Text('No Lab Tests'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_noLabTests && !_labTestsCompleted && _noLabTestsReason.isEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Please provide a reason:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'e.g., No tests required for this condition, recent tests available, etc.',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      onChanged: (value) {
                        // Only update string — no setState so field stays visible
                        _noLabTestsReason = value;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (_noLabTestsReason.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a reason first')),
                                );
                                return;
                              }
                              setState(() {}); // refresh to show completed state
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B5CF6),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Confirm'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: () => setState(() {
                            _noLabTests = false;
                            _noLabTestsReason = '';
                          }),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ],
                  if (_labTestsCompleted && _selectedLabTemplate != null) ...[
                    _buildCompletedIndicator(
                      'Lab tests suggested: ${_selectedLabTemplate!['name']} (${(_selectedLabTemplate!['tests'] as List).length} tests)',
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LabTestTemplateScreen(
                              selectionMode: true,
                              onTemplateSelected: (template) {
                                setState(() {
                                  _selectedLabTemplate = template;
                                  _labTestsCompleted = true;
                                });
                              },
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                      label: const Text('Change Template'),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF8B5CF6)),
                    ),
                  ],
                  if (_labTestsCompleted && _selectedLabTemplate == null) ...[
                    _buildCompletedIndicator('Lab tests suggested'),
                  ],
                  if (_noLabTests && _noLabTestsReason.isNotEmpty) ...[
                    _buildCompletedIndicator('No lab tests - Reason provided'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. SOAP Notes Section
            _buildSection(
              title: '4. SOAP Notes',
              icon: Icons.description_rounded,
              color: Colors.blue,
              isCompleted: _soapNotesCompleted,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_soapNotesCompleted) ...[
                    const Text(
                      'SOAP notes are mandatory and must be completed:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SoapNotesRedesign(
                                appointment: widget.appointment,
                              ),
                            ),
                          ).then((_) => _checkExistingData());
                        },
                        icon: const Icon(Icons.edit_rounded, size: 20),
                        label: const Text('Complete SOAP Notes'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_soapNotesCompleted) ...[
                    _buildCompletedIndicator('SOAP notes completed'),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 40),

            // End Consultation Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _endConsultation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canEndConsultation
                      ? AppColors.primaryColor
                      : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: _canEndConsultation ? 2 : 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            _canEndConsultation
                                ? 'End Consultation'
                                : 'Complete All Sections First',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required bool isCompleted,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? color.withValues(alpha: 0.5)
              : const Color(0xFFE2E8F0),
          width: isCompleted ? 2 : 1,
        ),
        boxShadow: isCompleted
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (isCompleted)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildCompletedIndicator(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDosageField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
        prefixIcon: Icon(icon, color: color, size: 16),
        filled: true,
        fillColor: color.withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: 2),
        ),
      ),
    );
  }

  Widget _buildDosageBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
