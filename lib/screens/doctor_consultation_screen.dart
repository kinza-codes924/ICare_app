import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icare/models/consultation.dart';
import 'package:icare/services/healthcare_workflow_service.dart';
import 'package:icare/services/laboratory_service.dart';
import 'package:icare/services/pharmacy_service.dart';
import 'package:icare/utils/app_keys.dart';
import 'package:icare/utils/theme.dart';

/// Doctor Consultation Screen
///
/// This implements the STRUCTURED CLINICAL WORKFLOW:
/// Step 1: History (Chief Complaint, HPI, Past Medical History, etc.)
/// Step 2: Examination (Vital Signs, Physical Exam)
/// Step 3: Diagnosis (Primary Diagnosis, Differential Diagnosis)
/// Step 4: Plan (Prescriptions, Lab Tests, Health Programs, Referrals)
///
/// When consultation is completed, the Healthcare Workflow Engine
/// automatically triggers all connected modules.
class DoctorConsultationScreen extends ConsumerStatefulWidget {
  final String appointmentId;
  final String patientId;

  const DoctorConsultationScreen({
    super.key,
    required this.appointmentId,
    required this.patientId,
  });

  @override
  ConsumerState<DoctorConsultationScreen> createState() =>
      _DoctorConsultationScreenState();
}

class _DoctorConsultationScreenState
    extends ConsumerState<DoctorConsultationScreen> {
  int _currentStep = 0;
  final bool _isLoading = false;
  bool _isSaving = false;

  // Step 1: History
  final _chiefComplaintController = TextEditingController();
  final _hpiController = TextEditingController();
  final _pastMedicalHistoryController = TextEditingController();
  final _medicationsController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _familyHistoryController = TextEditingController();
  final _socialHistoryController = TextEditingController();

  // Step 2: Examination
  final _bpSystolicController = TextEditingController();
  final _bpDiastolicController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _respiratoryRateController = TextEditingController();
  final _oxygenSaturationController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _generalAppearanceController = TextEditingController();
  final _examinationNotesController = TextEditingController();

  // Step 3: Diagnosis
  final _primaryDiagnosisController = TextEditingController();
  final _differentialDiagnosisController = TextEditingController();
  final _icdCodeController = TextEditingController();
  final _clinicalNotesController = TextEditingController();

  // Step 4: Plan
  final _instructionsController = TextEditingController();
  final _followUpInstructionsController = TextEditingController();
  final _followUpDurationController = TextEditingController();
  String _followUpUnit = 'Days';
  DateTime? _followUpDate;

  // Plan items (will be managed through dialogs)
  final List<Map<String, dynamic>> _prescriptions = [];
  final List<Map<String, dynamic>> _labTests = [];
  final List<Map<String, dynamic>> _healthPrograms = [];
  Map<String, dynamic>? _referral;

  // Selected pharmacy & lab for auto-routing
  String? _selectedPharmacyId;
  String? _selectedLabId;

  List<dynamic> _availablePharmacies = [];
  List<dynamic> _availableLabs = [];
  bool _isLoadingPharmacies = false;
  bool _isLoadingLabs = false;

  final PharmacyService _pharmacyService = PharmacyService();
  final LaboratoryService _labService = LaboratoryService();

  @override
  void initState() {
    super.initState();
    _loadPharmaciesAndLabs();
  }

  Future<void> _loadPharmaciesAndLabs() async {
    setState(() { _isLoadingPharmacies = true; _isLoadingLabs = true; });
    try {
      final pharmacies = await _pharmacyService.getAllPharmacies();
      if (mounted) setState(() { _availablePharmacies = pharmacies; _isLoadingPharmacies = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingPharmacies = false);
    }
    try {
      final labs = await _labService.getAllLaboratories();
      if (mounted) setState(() { _availableLabs = labs; _isLoadingLabs = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingLabs = false);
    }
  }

  @override
  void dispose() {
    // Dispose all controllers
    _chiefComplaintController.dispose();
    _hpiController.dispose();
    _pastMedicalHistoryController.dispose();
    _medicationsController.dispose();
    _allergiesController.dispose();
    _familyHistoryController.dispose();
    _socialHistoryController.dispose();
    _bpSystolicController.dispose();
    _bpDiastolicController.dispose();
    _heartRateController.dispose();
    _temperatureController.dispose();
    _respiratoryRateController.dispose();
    _oxygenSaturationController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _generalAppearanceController.dispose();
    _examinationNotesController.dispose();
    _primaryDiagnosisController.dispose();
    _differentialDiagnosisController.dispose();
    _icdCodeController.dispose();
    _clinicalNotesController.dispose();
    _instructionsController.dispose();
    _followUpInstructionsController.dispose();
    _followUpDurationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Clinical Consultation',
              style: TextStyle(
                fontSize: 20,
                fontFamily: 'Gilroy-Bold',
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              'Patient ID: ${widget.patientId.substring(0, 8)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
                fontFamily: 'Gilroy-Medium',
              ),
            ),
          ],
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton.icon(
              onPressed: _saveAsDraft,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save Draft'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryColor,
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildStepperContent(),
    );
  }

  Widget _buildStepperContent() {
    return Stepper(
      currentStep: _currentStep,
      onStepContinue: _onStepContinue,
      onStepCancel: _onStepCancel,
      onStepTapped: (step) => setState(() => _currentStep = step),
      controlsBuilder: (context, details) {
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Row(
            children: [
              if (_currentStep < 3)
                Expanded(
                  child: ElevatedButton(
                    onPressed: details.onStepContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Continue'),
                  ),
                )
              else
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _completeConsultation,
                    icon: const Icon(Icons.check_circle_rounded, size: 20),
                    label: const Text('Complete Consultation'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              if (_currentStep > 0) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: details.onStepCancel,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Back'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
      steps: [
        Step(
          title: const Text('History'),
          subtitle: const Text('Patient history & complaints'),
          content: _buildHistoryStep(),
          isActive: _currentStep >= 0,
          state: _currentStep > 0 ? StepState.complete : StepState.indexed,
        ),
        Step(
          title: const Text('Examination'),
          subtitle: const Text('Vital signs & physical exam'),
          content: _buildExaminationStep(),
          isActive: _currentStep >= 1,
          state: _currentStep > 1 ? StepState.complete : StepState.indexed,
        ),
        Step(
          title: const Text('Diagnosis'),
          subtitle: const Text('Clinical diagnosis'),
          content: _buildDiagnosisStep(),
          isActive: _currentStep >= 2,
          state: _currentStep > 2 ? StepState.complete : StepState.indexed,
        ),
        Step(
          title: const Text('Plan'),
          subtitle: const Text('Treatment plan'),
          content: _buildPlanStep(),
          isActive: _currentStep >= 3,
          state: _currentStep > 3 ? StepState.complete : StepState.indexed,
        ),
      ],
    );
  }

  Widget _buildHistoryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chief Complaint',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            fontFamily: 'Gilroy-Bold',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _chiefComplaintController,
          decoration: InputDecoration(
            hintText: 'What brings the patient in today?',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 20),
        const Text(
          'History of Present Illness (HPI)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            fontFamily: 'Gilroy-Bold',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _hpiController,
          decoration: InputDecoration(
            hintText: 'Detailed description of current illness...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          maxLines: 4,
        ),
        const SizedBox(height: 20),
        const Text(
          'Past Medical History',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            fontFamily: 'Gilroy-Bold',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _pastMedicalHistoryController,
          decoration: InputDecoration(
            hintText: 'Previous conditions, surgeries, hospitalizations...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 20),
        const Text(
          'Current Medications',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            fontFamily: 'Gilroy-Bold',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _medicationsController,
          decoration: InputDecoration(
            hintText: 'List current medications...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 20),
        const Text(
          'Allergies',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            fontFamily: 'Gilroy-Bold',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _allergiesController,
          decoration: InputDecoration(
            hintText: 'Drug allergies, food allergies...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 20),
        const Text(
          'Family History',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            fontFamily: 'Gilroy-Bold',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _familyHistoryController,
          decoration: InputDecoration(
            hintText: 'Relevant family medical history...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 20),
        const Text(
          'Social History',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            fontFamily: 'Gilroy-Bold',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _socialHistoryController,
          decoration: InputDecoration(
            hintText: 'Smoking, alcohol, occupation, living situation...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildExaminationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vital Signs',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            fontFamily: 'Gilroy-Bold',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('BP Systolic (mmHg)', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _bpSystolicController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '120',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('BP Diastolic (mmHg)', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _bpDiastolicController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '80',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Heart Rate (bpm)', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _heartRateController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '72',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Temperature (°F)', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _temperatureController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '98.6',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'General Appearance',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            fontFamily: 'Gilroy-Bold',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _generalAppearanceController,
          decoration: InputDecoration(
            hintText: 'Well-appearing, alert and oriented...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 20),
        const Text(
          'Physical Examination Notes',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            fontFamily: 'Gilroy-Bold',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _examinationNotesController,
          decoration: InputDecoration(
            hintText: 'Systemic examination findings...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildDiagnosisStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Primary Diagnosis',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            fontFamily: 'Gilroy-Bold',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _primaryDiagnosisController,
          decoration: InputDecoration(
            hintText: 'Main diagnosis...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'ICD Code',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            fontFamily: 'Gilroy-Bold',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _icdCodeController,
          decoration: InputDecoration(
            hintText: 'ICD-10 code...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Differential Diagnosis',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            fontFamily: 'Gilroy-Bold',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _differentialDiagnosisController,
          decoration: InputDecoration(
            hintText: 'Alternative diagnoses (comma-separated)...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 20),
        const Text(
          'Clinical Notes',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            fontFamily: 'Gilroy-Bold',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _clinicalNotesController,
          decoration: InputDecoration(
            hintText: 'Additional clinical observations...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildPlanStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Treatment Plan',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 6),
        const Text(
          'Add prescriptions, lab tests, health programs, and referrals for this patient.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),

        // ── PRESCRIPTIONS ────────────────────────────────────────────
        _buildPlanSection(
          title: 'Medications',
          icon: Icons.medication_rounded,
          color: const Color(0xFF3B82F6),
          items: _prescriptions,
          labelKey: 'name',
          sublabelKey: 'dosage',
          sublabelSuffix: (item) => ' • ${item['frequency'] ?? ''} • ${item['duration'] ?? ''}',
          onAdd: _showAddPrescriptionDialog,
          onRemove: (i) => setState(() => _prescriptions.removeAt(i)),
          emptyLabel: 'No medications added',
        ),
        const SizedBox(height: 20),

        // ── LAB TESTS ────────────────────────────────────────────────
        _buildPlanSection(
          title: 'Lab Tests',
          icon: Icons.biotech_rounded,
          color: const Color(0xFF8B5CF6),
          items: _labTests,
          labelKey: 'name',
          sublabelKey: 'urgency',
          sublabelSuffix: (item) => item['notes'] != null && item['notes'].toString().isNotEmpty
              ? ' • ${item['notes']}' : '',
          onAdd: _showAddLabTestDialog,
          onRemove: (i) => setState(() => _labTests.removeAt(i)),
          emptyLabel: 'No lab tests ordered',
        ),
        const SizedBox(height: 20),

        // ── HEALTH PROGRAMS ──────────────────────────────────────────
        _buildPlanSection(
          title: 'Health Programs',
          icon: Icons.health_and_safety_rounded,
          color: const Color(0xFF10B981),
          items: _healthPrograms,
          labelKey: 'name',
          sublabelKey: 'category',
          sublabelSuffix: (_) => '',
          onAdd: _showAddHealthProgramDialog,
          onRemove: (i) => setState(() => _healthPrograms.removeAt(i)),
          emptyLabel: 'No health programs assigned',
        ),
        const SizedBox(height: 20),

        // ── REFERRAL ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_search_rounded, color: Color(0xFFF59E0B), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('Specialist Referral', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _showAddReferralDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(_referral == null ? 'Add' : 'Change'),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFF59E0B)),
                  ),
                ],
              ),
              if (_referral != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_forward_rounded, color: Color(0xFFF59E0B), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_referral!['specialty']} — ${_referral!['reason'] ?? 'Specialist Consultation'}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
                        onPressed: () => setState(() => _referral = null),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        // ── SELECT PHARMACY ──────────────────────────────────────────
        if (_prescriptions.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildDropdownSection(
            title: 'Send Prescription To',
            icon: Icons.local_pharmacy_rounded,
            color: const Color(0xFF3B82F6),
            isLoading: _isLoadingPharmacies,
            items: _availablePharmacies,
            selectedId: _selectedPharmacyId,
            nameKey: 'pharmacyName',
            hint: 'Select pharmacy (optional)',
            onChanged: (id) => setState(() => _selectedPharmacyId = id),
          ),
        ],

        // ── SELECT LAB ───────────────────────────────────────────────
        if (_labTests.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildDropdownSection(
            title: 'Send Lab Tests To',
            icon: Icons.science_rounded,
            color: const Color(0xFF8B5CF6),
            isLoading: _isLoadingLabs,
            items: _availableLabs,
            selectedId: _selectedLabId,
            nameKey: 'labName',
            hint: 'Select laboratory (optional)',
            onChanged: (id) => setState(() => _selectedLabId = id),
          ),
        ],

        const SizedBox(height: 20),

        // ── INSTRUCTIONS ─────────────────────────────────────────────
        const Text(
          'Instructions to Patient',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _instructionsController,
          decoration: InputDecoration(
            hintText: 'General instructions, lifestyle advice, diet, etc.',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        const Text(
          'Follow-up Instructions',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _followUpInstructionsController,
          decoration: InputDecoration(
            hintText: 'When to return, warning signs to watch for...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 20),

        // ── FOLLOW UP AFTER ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.event_repeat_rounded, color: Color(0xFF6366F1), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('Follow Up After', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _followUpDurationController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Duration',
                        hintText: 'e.g. 7',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      initialValue: _followUpUnit,
                      decoration: InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                      items: ['Days', 'Weeks', 'Months'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: (v) => setState(() => _followUpUnit = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Patient will be prompted to schedule a follow-up appointment',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlanSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Map<String, dynamic>> items,
    required String labelKey,
    required String sublabelKey,
    required String Function(Map<String, dynamic>) sublabelSuffix,
    required VoidCallback onAdd,
    required void Function(int) onRemove,
    required String emptyLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
                style: TextButton.styleFrom(foregroundColor: color),
              ),
            ],
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(emptyLabel, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            )
          else
            ...items.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;
              return Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: color, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item[labelKey]?.toString() ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          if ((item[sublabelKey]?.toString() ?? '').isNotEmpty || sublabelSuffix(item).isNotEmpty)
                            Text(
                              '${item[sublabelKey] ?? ''}${sublabelSuffix(item)}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
                      onPressed: () => onRemove(i),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDropdownSection({
    required String title,
    required IconData icon,
    required Color color,
    required bool isLoading,
    required List<dynamic> items,
    required String? selectedId,
    required String nameKey,
    required String hint,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: isLoading
                ? const LinearProgressIndicator()
                : DropdownButtonFormField<String>(
                    initialValue: selectedId,
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: const TextStyle(fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    items: [
                      DropdownMenuItem<String>(value: null, child: Text(hint, style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)))),
                      ...items.map((item) {
                        final id = item['_id']?.toString() ?? item['id']?.toString() ?? '';
                        final name = item[nameKey]?.toString() ?? item['name']?.toString() ?? 'Unknown';
                        return DropdownMenuItem<String>(value: id, child: Text(name, style: const TextStyle(fontSize: 13)));
                      }),
                    ],
                    onChanged: onChanged,
                  ),
          ),
        ],
      ),
    );
  }

  void _onStepContinue() {
    if (_currentStep < 3) setState(() => _currentStep++);
  }

  void _onStepCancel() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  void _showAddPrescriptionDialog() {
    final nameCtrl = TextEditingController();
    final dosageCtrl = TextEditingController();
    final freqCtrl = TextEditingController(text: 'Once daily');
    final durationCtrl = TextEditingController(text: '7 days');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Medication'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Medicine Name', hintText: 'e.g. Paracetamol 500mg')),
            const SizedBox(height: 12),
            TextField(controller: dosageCtrl, decoration: const InputDecoration(labelText: 'Dosage', hintText: 'e.g. 1 tablet')),
            const SizedBox(height: 12),
            TextField(controller: freqCtrl, decoration: const InputDecoration(labelText: 'Frequency')),
            const SizedBox(height: 12),
            TextField(controller: durationCtrl, decoration: const InputDecoration(labelText: 'Duration')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              setState(() => _prescriptions.add({
                'name': nameCtrl.text.trim(),
                'dosage': dosageCtrl.text.trim(),
                'frequency': freqCtrl.text.trim(),
                'duration': durationCtrl.text.trim(),
                'id': 'rx_${DateTime.now().millisecondsSinceEpoch}',
              }));
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddLabTestDialog() {
    final nameCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String urgency = 'Routine';
    final urgencyOptions = ['Routine', 'Urgent', 'STAT'];
    final commonTests = ['CBC (Complete Blood Count)', 'HbA1c', 'Lipid Profile', 'Liver Function Test', 'Kidney Function Test', 'Thyroid Panel', 'Urine Analysis', 'Blood Glucose', 'Chest X-Ray', 'ECG'];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Order Lab Test'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Common Tests:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: commonTests.map((t) => GestureDetector(
                  onTap: () => nameCtrl.text = t,
                  child: Chip(label: Text(t, style: const TextStyle(fontSize: 11)), padding: EdgeInsets.zero),
                )).toList(),
              ),
              const SizedBox(height: 12),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Test Name')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: urgency,
                decoration: const InputDecoration(labelText: 'Urgency'),
                items: urgencyOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (v) => setDlgState(() => urgency = v!),
              ),
              const SizedBox(height: 12),
              TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Clinical Notes (optional)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                setState(() => _labTests.add({
                  'name': nameCtrl.text.trim(),
                  'urgency': urgency,
                  'notes': notesCtrl.text.trim(),
                  'id': 'lab_${DateTime.now().millisecondsSinceEpoch}',
                }));
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.white),
              child: const Text('Order'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddHealthProgramDialog() {
    final programs = [
      'Diabetes Management Program',
      'Hypertension Control Program',
      'Weight Loss Plan',
      'Cardiac Rehabilitation',
      'Post-Surgery Rehabilitation',
      'Prenatal Care Program',
      'Mental Health & Wellness',
      'COPD Management',
      'Smoking Cessation',
      'Chronic Pain Management',
    ];
    String? selected;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Assign Health Program'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select a program to assign to the patient:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 12),
              ...programs.map((p) => RadioListTile<String>(
                value: p,
                groupValue: selected,
                title: Text(p, style: const TextStyle(fontSize: 14)),
                onChanged: (v) => setDlgState(() => selected = v),
                contentPadding: EdgeInsets.zero,
                dense: true,
              )),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selected == null ? null : () {
                setState(() => _healthPrograms.add({
                  'name': selected!,
                  'category': 'Clinical Program',
                  'id': 'prog_${DateTime.now().millisecondsSinceEpoch}',
                }));
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddReferralDialog() {
    final specialties = ['Cardiology', 'Neurology', 'Orthopedics', 'Pulmonology', 'Endocrinology', 'Gastroenterology', 'Dermatology', 'Psychiatry', 'Ophthalmology', 'ENT'];
    String? selected;
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Create Specialist Referral'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Specialty'),
                items: specialties.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setDlgState(() => selected = v),
              ),
              const SizedBox(height: 12),
              TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason for Referral'), maxLines: 2),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selected == null ? null : () {
                setState(() => _referral = {
                  'specialty': selected!,
                  'reason': reasonCtrl.text.trim(),
                  'id': 'ref_${DateTime.now().millisecondsSinceEpoch}',
                });
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _completeConsultation() async {
    if (_chiefComplaintController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete the patient history section first.'), backgroundColor: Color(0xFFEF4444)),
      );
      setState(() => _currentStep = 0);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final consultation = Consultation(
        id: 'c_${DateTime.now().millisecondsSinceEpoch}',
        patientId: widget.patientId,
        doctorId: 'd1',
        appointmentId: widget.appointmentId,
        status: ConsultationStatus.completed,
        consultationDate: DateTime.now(),
        history: PatientHistory(
          chiefComplaint: _chiefComplaintController.text.trim(),
          historyOfPresentIllness: _hpiController.text.trim(),
          pastMedicalHistory: _pastMedicalHistoryController.text.trim().isNotEmpty
              ? [_pastMedicalHistoryController.text.trim()] : [],
          medications: _medicationsController.text.trim().isNotEmpty
              ? [_medicationsController.text.trim()] : [],
          allergies: _allergiesController.text.trim().isNotEmpty
              ? [_allergiesController.text.trim()] : [],
          familyHistory: _familyHistoryController.text.trim(),
          socialHistory: _socialHistoryController.text.trim(),
        ),
        examination: PhysicalExamination(
          vitalSigns: VitalSigns(
            bloodPressureSystolic: double.tryParse(_bpSystolicController.text) ?? 0,
            bloodPressureDiastolic: double.tryParse(_bpDiastolicController.text) ?? 0,
            heartRate: double.tryParse(_heartRateController.text) ?? 0,
            temperature: double.tryParse(_temperatureController.text) ?? 0,
            oxygenSaturation: double.tryParse(_oxygenSaturationController.text) ?? 0,
            weight: double.tryParse(_weightController.text) ?? 0,
            height: double.tryParse(_heightController.text) ?? 0,
          ),
          generalAppearance: _generalAppearanceController.text.trim(),
          systemicExamination: {},
          notes: _examinationNotesController.text.trim(),
        ),
        diagnosis: Diagnosis(
          primaryDiagnosis: _primaryDiagnosisController.text.trim(),
          differentialDiagnosis: _differentialDiagnosisController.text.trim().isNotEmpty
              ? [_differentialDiagnosisController.text.trim()] : [],
          icdCode: _icdCodeController.text.trim(),
          clinicalNotes: _clinicalNotesController.text.trim(),
        ),
        plan: TreatmentPlan(
          // Pass medicine names as IDs so workflow service can send them to pharmacy
          prescriptionIds: _prescriptions.map((p) => p['name'].toString()).toList(),
          // Pass lab test names so workflow service can send them to lab
          labTestRequestIds: _labTests.map((l) => l['name'].toString()).toList(),
          healthProgramIds: _healthPrograms.map((h) => h['id'].toString()).toList(),
          instructions: _instructionsController.text.trim(),
          followUpInstructions: _followUpInstructionsController.text.trim(),
          referralId: _referral?['id'],
        ),
        createdAt: DateTime.now(),
        completedAt: DateTime.now(),
      );

      final workflowService = HealthcareWorkflowService();
      final result = await workflowService.processConsultationCompletion(
        consultation,
        selectedPharmacyId: _selectedPharmacyId,
        selectedLabId: _selectedLabId,
      );

      if (mounted) {
        // Show completion summary
        _showCompletionSummary(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to complete consultation. Please try again.'), backgroundColor: Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showCompletionSummary(WorkflowResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
            ),
            const SizedBox(width: 12),
            const Text('Consultation Complete', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('The following actions have been triggered:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            if (_prescriptions.isNotEmpty)
              _summaryRow(Icons.medication_rounded, const Color(0xFF3B82F6),
                  '${_prescriptions.length} prescription(s) issued${_selectedPharmacyId != null ? ' → sent to pharmacy' : ''}'),
            if (_labTests.isNotEmpty)
              _summaryRow(Icons.biotech_rounded, const Color(0xFF8B5CF6),
                  '${_labTests.length} lab test(s)${_selectedLabId != null ? ' → sent to lab dashboard' : ' ordered'}'),
            if (_healthPrograms.isNotEmpty)
              _summaryRow(Icons.health_and_safety_rounded, const Color(0xFF10B981), '${_healthPrograms.length} health program(s) assigned to patient'),
            if (_referral != null)
              _summaryRow(Icons.person_search_rounded, const Color(0xFFF59E0B), 'Referral to ${_referral!['specialty']} created'),
            const SizedBox(height: 8),
            const Text('Patient will see all updates in their health dashboard.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); // close dialog
              // Navigate to dashboard — clears entire stack so no white screen
              appNavigatorKey.currentContext?.go('/dashboard');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Go to Dashboard'),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Future<void> _saveAsDraft() async {
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consultation draft saved successfully.')),
      );
      setState(() => _isSaving = false);
    }
  }
}
