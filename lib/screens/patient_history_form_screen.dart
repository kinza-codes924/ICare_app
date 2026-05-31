// Patient History Form Screen
// Complete 10-section history form as per client requirements

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:icare/models/appointment_detail.dart';
import 'package:icare/models/patient_history_form.dart';
import 'package:icare/services/consultation_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';

class PatientHistoryFormScreen extends StatefulWidget {
  final AppointmentDetail appointment;
  final String consultationId;
  final Function(String)? onHistoryComplete;

  const PatientHistoryFormScreen({
    super.key,
    required this.appointment,
    required this.consultationId,
    this.onHistoryComplete,
  });

  @override
  State<PatientHistoryFormScreen> createState() =>
      _PatientHistoryFormScreenState();
}

class _PatientHistoryFormScreenState extends State<PatientHistoryFormScreen> {
  final ConsultationService _consultationService = ConsultationService();
  final ScrollController _scrollController = ScrollController();

  bool _isSaving = false;

  // Track which sections are expanded
  final Set<int> _expandedSections = {0}; // First section open by default

  // Section 1: Chief Complaints
  final List<ChiefComplaint> _chiefComplaints = [];
  final TextEditingController _complaintController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();

  // Section 2: HPI
  final TextEditingController _onsetController = TextEditingController();
  final TextEditingController _hpiDurationController = TextEditingController();
  final TextEditingController _progressionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _radiationController = TextEditingController();
  final TextEditingController _characterController = TextEditingController();
  final TextEditingController _severityController = TextEditingController();
  final TextEditingController _aggravatingController = TextEditingController();
  final TextEditingController _relievingController = TextEditingController();
  final TextEditingController _associatedController = TextEditingController();
  final TextEditingController _previousController = TextEditingController();
  final TextEditingController _treatmentController = TextEditingController();
  final TextEditingController _additionalController = TextEditingController();

  // Section 3: Past Medical History
  bool _hypertension = false;
  String? _hypertensionDetails;
  bool _diabetes = false;
  String? _diabetesDetails;
  bool _ihd = false;
  String? _ihdDetails;
  bool _asthma = false;
  String? _asthmaDetails;
  bool _tb = false;
  String? _tbDetails;
  bool _hepatitis = false;
  String? _hepatitisDetails;
  bool _thyroid = false;
  String? _thyroidDetails;
  bool _renal = false;
  String? _renalDetails;
  bool _epilepsy = false;
  String? _epilepsyDetails;
  bool _psychiatric = false;
  String? _psychiatricDetails;

  // Section 4: Surgical History
  final List<SurgicalHistory> _surgicalHistory = [];

  // Section 5: Drug History
  final List<CurrentMedication> _currentMedications = [];
  final List<Allergy> _allergies = [];

  // Section 6: Family History
  FamilyMemberHistory? _father;
  FamilyMemberHistory? _mother;
  final List<FamilyMemberHistory> _siblings = [];
  final List<FamilyMemberHistory> _children = [];
  String? _otherFamilyHistory;

  // Section 7: Personal & Social History
  String _diet = '';
  String _appetite = '';
  String _sleep = '';
  String _bowelHabits = '';
  String _bladderHabits = '';
  SmokingStatus _smoking = SmokingStatus.never;
  AlcoholStatus _alcohol = AlcoholStatus.never;
  bool _substanceAbuse = false;
  String? _substanceDetails;
  String _exercise = '';
  String _sexualHistory = '';
  String _occupationalExposure = '';
  String _travelHistory = '';
  String _vaccinationHistory = '';

  // Section 8: Gynecological History (if applicable)
  bool _showGynecologicalHistory = false;
  int? _menarche;
  DateTime? _lmp;
  String _menstrualCycle = '';
  int _gravida = 0;
  int _para = 0;
  int _abortions = 0;
  int _livingChildren = 0;
  String? _contraceptive;
  bool _menopause = false;

  // Section 9: Review of Systems
  final TextEditingController _generalController = TextEditingController();
  final TextEditingController _cardiovascularController = TextEditingController();
  final TextEditingController _respiratoryController = TextEditingController();
  final TextEditingController _giController = TextEditingController();
  final TextEditingController _guController = TextEditingController();
  final TextEditingController _neuroController = TextEditingController();
  final TextEditingController _musculoskeletalController = TextEditingController();
  final TextEditingController _endocrineController = TextEditingController();
  final TextEditingController _skinController = TextEditingController();
  final TextEditingController _psychiatricController = TextEditingController();

  // Section 10: Virtual Examination
  final TextEditingController _bpController = TextEditingController();
  final TextEditingController _pulseController = TextEditingController();
  final TextEditingController _rrController = TextEditingController();
  final TextEditingController _tempController = TextEditingController();
  final TextEditingController _spo2Controller = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _bmiController = TextEditingController();
  final TextEditingController _appearanceController = TextEditingController();
  final TextEditingController _consciousnessController = TextEditingController();
  final TextEditingController _orientationController = TextEditingController();
  final TextEditingController _hydrationController = TextEditingController();
  bool _pallor = false;
  bool _icterus = false;
  bool _cyanosis = false;
  bool _clubbing = false;
  bool _edema = false;
  bool _lymphadenopathy = false;
  final TextEditingController _nutritionalController = TextEditingController();
  final TextEditingController _mobilityController = TextEditingController();
  final TextEditingController _examNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Check patient gender for gynecological history
    if (widget.appointment.patient?.gender?.toLowerCase() == 'female') {
      _showGynecologicalHistory = true;
    }
  }

  Future<void> _saveHistory() async {
    final patientId = widget.appointment.patient?.id ?? '';
    final doctorId = widget.appointment.doctor?.id ?? '';

    if (patientId.isEmpty || doctorId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to save: patient or doctor info missing. Please go back and retry.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      final historyForm = PatientHistoryForm(
        patientId: patientId,
        consultationId: widget.consultationId,
        doctorId: doctorId,
        chiefComplaints: _chiefComplaints,
        hpi: HistoryOfPresentIllness(
          onset: _onsetController.text,
          duration: _hpiDurationController.text,
          progression: _progressionController.text,
          location: _locationController.text,
          radiation: _radiationController.text,
          character: _characterController.text,
          severity: _severityController.text,
          aggravatingFactors: _aggravatingController.text,
          relievingFactors: _relievingController.text,
          associatedSymptoms: _associatedController.text,
          previousEpisodes: _previousController.text,
          treatmentTaken: _treatmentController.text,
          additionalNotes: _additionalController.text,
        ),
        pastMedicalHistory: PastMedicalHistory(
          hypertension: _hypertension,
          hypertensionDetails: _hypertensionDetails,
          diabetesMellitus: _diabetes,
          diabetesDetails: _diabetesDetails,
          ischemicHeartDisease: _ihd,
          ihdDetails: _ihdDetails,
          asthma: _asthma,
          asthmaDetails: _asthmaDetails,
          tuberculosis: _tb,
          tbDetails: _tbDetails,
          hepatitis: _hepatitis,
          hepatitisDetails: _hepatitisDetails,
          thyroidDisease: _thyroid,
          thyroidDetails: _thyroidDetails,
          renalDisease: _renal,
          renalDetails: _renalDetails,
          epilepsy: _epilepsy,
          epilepsyDetails: _epilepsyDetails,
          psychiatricIllness: _psychiatric,
          psychiatricDetails: _psychiatricDetails,
          otherIllnesses: [],
        ),
        surgicalHistory: _surgicalHistory,
        drugHistory: DrugHistory(
          currentMedications: _currentMedications,
          allergies: _allergies,
        ),
        familyHistory: FamilyHistory(
          father: _father,
          mother: _mother,
          siblings: _siblings,
          children: _children,
          otherRelevantHistory: _otherFamilyHistory,
        ),
        personalSocialHistory: PersonalSocialHistory(
          diet: _diet,
          appetite: _appetite,
          sleep: _sleep,
          bowelHabits: _bowelHabits,
          bladderHabits: _bladderHabits,
          smoking: _smoking,
          alcoholUse: _alcohol,
          substanceAbuse: _substanceAbuse,
          substanceDetails: _substanceDetails,
          exercise: _exercise,
          sexualHistory: _sexualHistory.isEmpty ? null : _sexualHistory,
          occupationalExposure: _occupationalExposure.isEmpty ? null : _occupationalExposure,
          travelHistory: _travelHistory.isEmpty ? null : _travelHistory,
          vaccinationHistory: _vaccinationHistory.isEmpty ? null : _vaccinationHistory,
        ),
        gynecologicalHistory: _showGynecologicalHistory
            ? GynecologicalHistory(
                menarche: _menarche,
                lastMenstrualPeriod: _lmp,
                menstrualCycle: _menstrualCycle,
                gravida: _gravida,
                para: _para,
                abortions: _abortions,
                livingChildren: _livingChildren,
                contraceptiveUse: _contraceptive,
                menopause: _menopause,
              )
            : null,
        reviewOfSystems: ReviewOfSystems(
          general: _generalController.text,
          cardiovascular: _cardiovascularController.text,
          respiratory: _respiratoryController.text,
          gastrointestinal: _giController.text,
          genitourinary: _guController.text,
          neurological: _neuroController.text,
          musculoskeletal: _musculoskeletalController.text,
          endocrine: _endocrineController.text,
          skin: _skinController.text,
          psychiatric: _psychiatricController.text,
        ),
        virtualExamination: VirtualPhysicalExamination(
          vitalSigns: VitalSigns(
            bloodPressure: _bpController.text,
            pulseRate: _pulseController.text,
            respiratoryRate: _rrController.text,
            temperature: _tempController.text,
            oxygenSaturation: _spo2Controller.text,
            weight: _weightController.text,
            height: _heightController.text,
            bmi: _bmiController.text,
          ),
          generalFindings: GeneralExaminationFindings(
            generalAppearance: _appearanceController.text,
            levelOfConsciousness: _consciousnessController.text,
            orientation: _orientationController.text,
            hydration: _hydrationController.text,
            pallor: _pallor,
            icterus: _icterus,
            cyanosis: _cyanosis,
            clubbing: _clubbing,
            edema: _edema,
            lymphadenopathy: _lymphadenopathy,
            nutritionalStatus: _nutritionalController.text,
            mobilityGait: _mobilityController.text,
          ),
          notes: _examNotesController.text,
        ),
        createdAt: DateTime.now(),
      );

      final result = await _consultationService.savePatientHistory(
        historyData: historyForm.toJson(),
      );

      if (result['success'] == true && mounted) {
        widget.onHistoryComplete?.call(result['historyId'] ?? '');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Patient history saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else if (mounted) {
        final msg = result['message']?.toString() ?? result['error']?.toString() ?? 'Save failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save history: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build sections list dynamically
    final sections = <_AccordionSection>[
      _AccordionSection(index: 0, title: 'Chief Complaint(s)', icon: Icons.sick_rounded, child: _buildChiefComplaintsSection()),
      _AccordionSection(index: 1, title: 'History of Present Illness', icon: Icons.history_edu_rounded, child: _buildHPISection()),
      _AccordionSection(index: 2, title: 'Past Medical History', icon: Icons.medical_services_rounded, child: _buildPastMedicalHistorySection()),
      _AccordionSection(index: 3, title: 'Past Surgical History', icon: Icons.cut_rounded, child: _buildSurgicalHistorySection()),
      _AccordionSection(index: 4, title: 'Drug History', icon: Icons.medication_rounded, child: _buildDrugHistorySection()),
      _AccordionSection(index: 5, title: 'Family History', icon: Icons.family_restroom_rounded, child: _buildFamilyHistorySection()),
      _AccordionSection(index: 6, title: 'Personal & Social History', icon: Icons.person_rounded, child: _buildPersonalSocialHistorySection()),
      if (_showGynecologicalHistory)
        _AccordionSection(index: 7, title: 'Gynecological History', icon: Icons.female_rounded, child: _buildGynecologicalHistorySection()),
      _AccordionSection(index: _showGynecologicalHistory ? 8 : 7, title: 'Review of Systems', icon: Icons.checklist_rounded, child: _buildReviewOfSystemsSection()),
      _AccordionSection(index: _showGynecologicalHistory ? 9 : 8, title: 'Virtual Physical Examination', icon: Icons.monitor_heart_rounded, child: _buildVirtualExaminationSection()),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: const Text(
          'Patient History',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton.icon(
              onPressed: _saveHistory,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Save'),
              style: TextButton.styleFrom(foregroundColor: Colors.green),
            ),
        ],
      ),
      body: Column(
        children: [
          // Expand All / Collapse All bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${sections.length} sections',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() {
                    _expandedSections.addAll(List.generate(sections.length, (i) => i));
                  }),
                  child: const Text('Expand All'),
                ),
                TextButton(
                  onPressed: () => setState(() => _expandedSections.clear()),
                  child: const Text('Collapse All'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: sections.length + 1, // +1 for save button at bottom
              itemBuilder: (ctx, i) {
                if (i == sections.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveHistory,
                        icon: _isSaving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_rounded),
                        label: Text(_isSaving ? 'Saving...' : 'Save Patient History'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  );
                }
                final sec = sections[i];
                final expanded = _expandedSections.contains(sec.index);
                return _buildAccordionTile(sec, expanded);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccordionTile(_AccordionSection sec, bool expanded) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: expanded ? AppColors.primaryColor : const Color(0xFFE2E8F0),
          width: expanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header — tap to toggle
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: () => setState(() {
              if (expanded) {
                _expandedSections.remove(sec.index);
              } else {
                _expandedSections.add(sec.index);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: expanded
                          ? AppColors.primaryColor
                          : AppColors.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(sec.icon,
                        color: expanded ? Colors.white : AppColors.primaryColor,
                        size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      sec.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: expanded ? AppColors.primaryColor : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Icon(
                    expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: expanded ? AppColors.primaryColor : const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),
          // Content
          if (expanded) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: sec.child,
            ),
          ],
        ],
      ),
    );
  }

  // ── Shared helpers ───────────────────────────────────────────────────────

  Widget _sectionHeader(String title) => Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
      );

  InputDecoration _inputDec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  Widget _buildField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(controller: controller, decoration: _inputDec(label), maxLines: maxLines),
    );
  }

  Widget _listHeader(List<String> cols, List<int> flex) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            ...List.generate(cols.length, (i) => Expanded(
              flex: flex[i],
              child: Text(cols[i], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF475569))),
            )),
            const SizedBox(width: 40),
          ],
        ),
      );

  Widget _listRow(List<String> vals, List<int> flex, VoidCallback onRemove) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            ...List.generate(vals.length, (i) => Expanded(
              flex: flex[i],
              child: Text(vals[i], style: const TextStyle(fontSize: 14)),
            )),
            IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20), onPressed: onRemove, visualDensity: VisualDensity.compact),
          ],
        ),
      );

  Widget _emptyState(String msg, IconData icon, {bool compact = false}) => Center(
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: compact ? 32 : 44, color: Colors.grey[400]),
            const SizedBox(height: 6),
            Text(msg, style: TextStyle(color: Colors.grey[500], fontSize: 13), textAlign: TextAlign.center),
          ]),
        ),
      );

  Widget _card({required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: child,
      );

  // ── Section 1: Chief Complaints ──────────────────────────────────────────

  Widget _buildChiefComplaintsSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Chief Complaint(s)'),
          const SizedBox(height: 6),
          const Text('List the patient\'s main complaints with duration',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(flex: 3, child: TextField(controller: _complaintController, decoration: _inputDec('Complaint'))),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: TextField(controller: _durationController, decoration: _inputDec('Duration', hint: 'e.g. 3 days'))),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addComplaint,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  minimumSize: const Size(48, 48),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_chiefComplaints.isNotEmpty) ...[
            _listHeader(['Complaint', 'Duration'], [3, 2]),
            const SizedBox(height: 8),
            ...List.generate(_chiefComplaints.length, (i) => _listRow(
              [_chiefComplaints[i].complaint, _chiefComplaints[i].duration], [3, 2],
              () => setState(() => _chiefComplaints.removeAt(i)),
            )),
          ] else
            _emptyState('Add complaints using the fields above', Icons.add_circle_outline),
        ],
      ),
    );
  }

  void _addComplaint() {
    if (_complaintController.text.trim().isEmpty) return;
    setState(() {
      _chiefComplaints.add(ChiefComplaint(
        complaint: _complaintController.text.trim(),
        duration: _durationController.text.trim(),
      ));
      _complaintController.clear();
      _durationController.clear();
    });
  }

  // ── Section 2: HPI ───────────────────────────────────────────────────────

  Widget _buildHPISection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('History of Present Illness (HPI)'),
          const SizedBox(height: 20),
          _buildField('Onset', _onsetController),
          _buildField('Duration', _hpiDurationController),
          _buildField('Progression', _progressionController),
          _buildField('Location', _locationController),
          _buildField('Radiation', _radiationController),
          _buildField('Character / Nature', _characterController),
          _buildField('Severity', _severityController),
          _buildField('Aggravating Factors', _aggravatingController, maxLines: 2),
          _buildField('Relieving Factors', _relievingController, maxLines: 2),
          _buildField('Associated Symptoms', _associatedController, maxLines: 2),
          _buildField('Previous Episodes', _previousController),
          _buildField('Treatment Taken', _treatmentController),
          _buildField('Additional Notes', _additionalController, maxLines: 3),
        ],
      ),
    );
  }

  // ── Section 3: Past Medical History ─────────────────────────────────────

  Widget _buildPastMedicalHistorySection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Past Medical History'),
          const SizedBox(height: 20),
          _conditionRow('Hypertension', _hypertension, (v) => setState(() => _hypertension = v), _hypertensionDetails, (v) => setState(() => _hypertensionDetails = v)),
          _conditionRow('Diabetes Mellitus', _diabetes, (v) => setState(() => _diabetes = v), _diabetesDetails, (v) => setState(() => _diabetesDetails = v)),
          _conditionRow('Ischemic Heart Disease', _ihd, (v) => setState(() => _ihd = v), _ihdDetails, (v) => setState(() => _ihdDetails = v)),
          _conditionRow('Asthma', _asthma, (v) => setState(() => _asthma = v), _asthmaDetails, (v) => setState(() => _asthmaDetails = v)),
          _conditionRow('Tuberculosis', _tb, (v) => setState(() => _tb = v), _tbDetails, (v) => setState(() => _tbDetails = v)),
          _conditionRow('Hepatitis', _hepatitis, (v) => setState(() => _hepatitis = v), _hepatitisDetails, (v) => setState(() => _hepatitisDetails = v)),
          _conditionRow('Thyroid Disease', _thyroid, (v) => setState(() => _thyroid = v), _thyroidDetails, (v) => setState(() => _thyroidDetails = v)),
          _conditionRow('Renal Disease', _renal, (v) => setState(() => _renal = v), _renalDetails, (v) => setState(() => _renalDetails = v)),
          _conditionRow('Epilepsy', _epilepsy, (v) => setState(() => _epilepsy = v), _epilepsyDetails, (v) => setState(() => _epilepsyDetails = v)),
          _conditionRow('Psychiatric Illness', _psychiatric, (v) => setState(() => _psychiatric = v), _psychiatricDetails, (v) => setState(() => _psychiatricDetails = v)),
        ],
      ),
    );
  }

  Widget _conditionRow(String name, bool value, Function(bool) toggle, String? details, Function(String?) onDetails) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: value ? AppColors.primaryColor.withValues(alpha: 0.4) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: Row(
              children: [
                Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                Switch(value: value, onChanged: toggle, activeThumbColor: AppColors.primaryColor),
                SizedBox(
                  width: 32,
                  child: Text(
                    value ? 'Yes' : 'No',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: value ? AppColors.primaryColor : const Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ),
          ),
          if (value)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                decoration: _inputDec('Details', hint: 'Duration, severity, treatment...'),
                controller: TextEditingController(text: details),
                onChanged: (v) => onDetails(v.isEmpty ? null : v),
              ),
            ),
        ],
      ),
    );
  }

  // ── Section 4: Surgical History ──────────────────────────────────────────

  Widget _buildSurgicalHistorySection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader('Past Surgical History'),
              ElevatedButton.icon(
                onPressed: _showAddSurgeryDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_surgicalHistory.isEmpty)
            _emptyState('No surgical procedures recorded', Icons.healing_outlined)
          else ...[
            _listHeader(['Surgery / Procedure', 'Year', 'Hospital'], [3, 1, 2]),
            const SizedBox(height: 8),
            ...List.generate(_surgicalHistory.length, (i) => _listRow(
              [
                _surgicalHistory[i].surgeryProcedure,
                _surgicalHistory[i].year.toString(),
                _surgicalHistory[i].hospitalRemarks ?? '',
              ],
              [3, 1, 2],
              () => setState(() => _surgicalHistory.removeAt(i)),
            )),
          ],
        ],
      ),
    );
  }

  void _showAddSurgeryDialog() {
    final procCtrl = TextEditingController();
    final yearCtrl = TextEditingController(text: DateTime.now().year.toString());
    final hospitalCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Surgical Procedure'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: procCtrl, decoration: _inputDec('Surgery / Procedure')),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: yearCtrl, decoration: _inputDec('Year'), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: hospitalCtrl, decoration: _inputDec('Hospital / Remarks'))),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (procCtrl.text.trim().isNotEmpty) {
                setState(() => _surgicalHistory.add(SurgicalHistory(
                  surgeryProcedure: procCtrl.text.trim(),
                  year: int.tryParse(yearCtrl.text.trim()) ?? DateTime.now().year,
                  hospitalRemarks: hospitalCtrl.text.trim().isEmpty ? null : hospitalCtrl.text.trim(),
                )));
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ── Section 5: Drug History ──────────────────────────────────────────────

  Widget _buildDrugHistorySection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Drug History'),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Current Medications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF475569))),
              TextButton.icon(onPressed: _showAddMedicationDialog, icon: const Icon(Icons.add, size: 16), label: const Text('Add')),
            ],
          ),
          const SizedBox(height: 8),
          if (_currentMedications.isEmpty)
            _emptyState('No current medications', Icons.medication_outlined, compact: true)
          else ...[
            _listHeader(['Medication', 'Dose', 'Frequency'], [3, 2, 2]),
            const SizedBox(height: 8),
            ...List.generate(_currentMedications.length, (i) => _listRow(
              [_currentMedications[i].medication, _currentMedications[i].dose, _currentMedications[i].frequency],
              [3, 2, 2],
              () => setState(() => _currentMedications.removeAt(i)),
            )),
          ],
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Allergies', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF475569))),
              TextButton.icon(onPressed: _showAddAllergyDialog, icon: const Icon(Icons.add, size: 16), label: const Text('Add')),
            ],
          ),
          const SizedBox(height: 8),
          if (_allergies.isEmpty)
            _emptyState('No known allergies', Icons.warning_amber_outlined, compact: true)
          else
            ...List.generate(_allergies.length, (i) {
              final a = _allergies[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(a.allergen, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        Text('${a.type.toString().split('.').last.toUpperCase()} allergy • ${a.reaction}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ]),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                      onPressed: () => setState(() => _allergies.removeAt(i)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showAddMedicationDialog() {
    final medCtrl = TextEditingController();
    final doseCtrl = TextEditingController();
    final freqCtrl = TextEditingController();
    final durCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Current Medication'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: medCtrl, decoration: _inputDec('Medication Name')),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: doseCtrl, decoration: _inputDec('Dose'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: freqCtrl, decoration: _inputDec('Frequency'))),
              ],
            ),
            const SizedBox(height: 10),
            TextField(controller: durCtrl, decoration: _inputDec('Duration')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (medCtrl.text.trim().isNotEmpty) {
                setState(() => _currentMedications.add(CurrentMedication(
                  medication: medCtrl.text.trim(),
                  dose: doseCtrl.text.trim(),
                  frequency: freqCtrl.text.trim(),
                  duration: durCtrl.text.trim(),
                )));
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddAllergyDialog() {
    final allergenCtrl = TextEditingController();
    final reactionCtrl = TextEditingController();
    AllergyType selectedType = AllergyType.drug;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Add Allergy'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<AllergyType>(
                initialValue: selectedType,
                decoration: _inputDec('Allergy Type'),
                items: [
                  const DropdownMenuItem(value: AllergyType.drug, child: Text('Drug Allergy')),
                  const DropdownMenuItem(value: AllergyType.food, child: Text('Food Allergy')),
                  const DropdownMenuItem(value: AllergyType.other, child: Text('Other Allergy')),
                ],
                onChanged: (v) => setS(() => selectedType = v!),
              ),
              const SizedBox(height: 10),
              TextField(controller: allergenCtrl, decoration: _inputDec('Allergen Name')),
              const SizedBox(height: 10),
              TextField(controller: reactionCtrl, decoration: _inputDec('Reaction / Symptoms')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (allergenCtrl.text.trim().isNotEmpty) {
                  setState(() => _allergies.add(Allergy(
                    type: selectedType,
                    allergen: allergenCtrl.text.trim(),
                    reaction: reactionCtrl.text.trim(),
                  )));
                }
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section 6: Family History ─────────────────────────────────────────────

  Widget _buildFamilyHistorySection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Family History'),
          const SizedBox(height: 20),
          _familyMemberRow('Father', _father, (v) => setState(() => _father = v)),
          const SizedBox(height: 12),
          _familyMemberRow('Mother', _mother, (v) => setState(() => _mother = v)),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          const Text('Other Relevant Family History',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF475569))),
          const SizedBox(height: 8),
          TextField(
            decoration: _inputDec('Describe hereditary conditions, patterns, etc.'),
            maxLines: 3,
            controller: TextEditingController(text: _otherFamilyHistory),
            onChanged: (v) => setState(() => _otherFamilyHistory = v.isEmpty ? null : v),
          ),
        ],
      ),
    );
  }

  Widget _familyMemberRow(String member, FamilyMemberHistory? h, Function(FamilyMemberHistory) onChanged) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(member, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF475569))),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  decoration: _inputDec('Disease / Condition'),
                  controller: TextEditingController(text: h?.diseaseCondition),
                  onChanged: (v) => onChanged(FamilyMemberHistory(
                    diseaseCondition: v.isEmpty ? null : v,
                    ageAtDiagnosis: h?.ageAtDiagnosis,
                  )),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  decoration: _inputDec('Age at Diagnosis'),
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(text: h?.ageAtDiagnosis?.toString()),
                  onChanged: (v) => onChanged(FamilyMemberHistory(
                    diseaseCondition: h?.diseaseCondition,
                    ageAtDiagnosis: int.tryParse(v),
                  )),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Section 7: Personal & Social History ────────────────────────────────

  Widget _buildPersonalSocialHistorySection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Personal & Social History'),
          const SizedBox(height: 20),
          _inlineField('Diet', _diet, (v) => setState(() => _diet = v)),
          _inlineField('Appetite', _appetite, (v) => setState(() => _appetite = v)),
          _inlineField('Sleep', _sleep, (v) => setState(() => _sleep = v)),
          _inlineField('Bowel Habits', _bowelHabits, (v) => setState(() => _bowelHabits = v)),
          _inlineField('Bladder Habits', _bladderHabits, (v) => setState(() => _bladderHabits = v)),
          _inlineField('Exercise', _exercise, (v) => setState(() => _exercise = v)),
          const SizedBox(height: 4),
          // Smoking
          _card(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Smoking', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF475569))),
              const SizedBox(height: 8),
              DropdownButtonFormField<SmokingStatus>(
                initialValue: _smoking,
                decoration: _inputDec('Status'),
                items: const [
                  DropdownMenuItem(value: SmokingStatus.never, child: Text('Never')),
                  DropdownMenuItem(value: SmokingStatus.former, child: Text('Former Smoker')),
                  DropdownMenuItem(value: SmokingStatus.current, child: Text('Current Smoker')),
                ],
                onChanged: (v) => setState(() => _smoking = v!),
              ),
            ],
          )),
          // Alcohol
          _card(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Alcohol Use', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF475569))),
              const SizedBox(height: 8),
              DropdownButtonFormField<AlcoholStatus>(
                initialValue: _alcohol,
                decoration: _inputDec('Status'),
                items: const [
                  DropdownMenuItem(value: AlcoholStatus.never, child: Text('Never')),
                  DropdownMenuItem(value: AlcoholStatus.occasional, child: Text('Occasional')),
                  DropdownMenuItem(value: AlcoholStatus.regular, child: Text('Regular')),
                ],
                onChanged: (v) => setState(() => _alcohol = v!),
              ),
            ],
          )),
          // Substance Abuse
          _card(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Expanded(child: Text('Substance Abuse', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                Switch(value: _substanceAbuse, onChanged: (v) => setState(() => _substanceAbuse = v), activeThumbColor: AppColors.primaryColor),
              ]),
              if (_substanceAbuse) ...[
                const SizedBox(height: 8),
                TextField(
                  decoration: _inputDec('Details'),
                  controller: TextEditingController(text: _substanceDetails),
                  onChanged: (v) => _substanceDetails = v.isEmpty ? null : v,
                ),
              ],
            ],
          )),
          _inlineField('Sexual History', _sexualHistory, (v) => setState(() => _sexualHistory = v)),
          _inlineField('Occupational Exposure', _occupationalExposure, (v) => setState(() => _occupationalExposure = v)),
          _inlineField('Travel History', _travelHistory, (v) => setState(() => _travelHistory = v)),
          _inlineField('Vaccination History', _vaccinationHistory, (v) => setState(() => _vaccinationHistory = v)),
        ],
      ),
    );
  }

  Widget _inlineField(String label, String value, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        decoration: _inputDec(label),
        controller: TextEditingController(text: value),
        onChanged: onChanged,
      ),
    );
  }

  // ── Section 8: Gynecological / Obstetric History ─────────────────────────

  Widget _buildGynecologicalHistorySection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Gynecological / Obstetric History'),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _card(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Menarche (age)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF475569))),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: _inputDec('Age in years'),
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: _menarche?.toString()),
                    onChanged: (v) => _menarche = int.tryParse(v),
                  ),
                ],
              ))),
              const SizedBox(width: 12),
              Expanded(child: _card(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Menstrual Cycle', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF475569))),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: _inputDec('e.g. Regular, 28 days'),
                    controller: TextEditingController(text: _menstrualCycle),
                    onChanged: (v) => setState(() => _menstrualCycle = v),
                  ),
                ],
              ))),
            ],
          ),
          const SizedBox(height: 4),
          _card(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Obstetric History (G P A L)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF475569))),
              const SizedBox(height: 12),
              Row(
                children: [
                  _obsField('G (Gravida)', _gravida, (v) => setState(() => _gravida = int.tryParse(v) ?? 0)),
                  const SizedBox(width: 8),
                  _obsField('P (Para)', _para, (v) => setState(() => _para = int.tryParse(v) ?? 0)),
                  const SizedBox(width: 8),
                  _obsField('A (Abortions)', _abortions, (v) => setState(() => _abortions = int.tryParse(v) ?? 0)),
                  const SizedBox(width: 8),
                  _obsField('L (Living)', _livingChildren, (v) => setState(() => _livingChildren = int.tryParse(v) ?? 0)),
                ],
              ),
            ],
          )),
          _card(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Contraceptive Use', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF475569))),
              const SizedBox(height: 8),
              TextField(
                decoration: _inputDec('Type and duration', hint: 'e.g. OCP × 2 years'),
                controller: TextEditingController(text: _contraceptive),
                onChanged: (v) => _contraceptive = v.isEmpty ? null : v,
              ),
            ],
          )),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Expanded(child: Text('Menopause', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                  Switch(value: _menopause, onChanged: (v) => setState(() => _menopause = v), activeThumbColor: AppColors.primaryColor),
                  Text(_menopause ? 'Yes' : 'No', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: _menopause ? AppColors.primaryColor : const Color(0xFF94A3B8),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _obsField(String label, int value, Function(String) onChanged) {
    return Expanded(child: Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        TextField(
          controller: TextEditingController(text: value.toString()),
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          ),
        ),
      ],
    ));
  }

  // ── Section 9: Review of Systems ─────────────────────────────────────────

  Widget _buildReviewOfSystemsSection() {
    final systems = [
      ('General', _generalController),
      ('Cardiovascular', _cardiovascularController),
      ('Respiratory', _respiratoryController),
      ('Gastrointestinal', _giController),
      ('Genitourinary', _guController),
      ('Neurological', _neuroController),
      ('Musculoskeletal', _musculoskeletalController),
      ('Endocrine', _endocrineController),
      ('Skin', _skinController),
      ('Psychiatric', _psychiatricController),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Review of Systems'),
          const SizedBox(height: 6),
          const Text('Indicate findings for each system (leave blank if unremarkable)',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          const SizedBox(height: 20),
          ...systems.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: s.$2,
              decoration: _inputDec(s.$1, hint: 'Findings or NAD (No Abnormality Detected)'),
              maxLines: 2,
            ),
          )),
        ],
      ),
    );
  }

  // ── Section 10: Virtual Physical Examination ─────────────────────────────

  Widget _buildVirtualExaminationSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Virtual Physical Examination'),
          const SizedBox(height: 20),
          const Text('Vital Signs (Self-Reported / Home Monitoring)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF475569))),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 3.2,
            children: [
              TextField(controller: _bpController, decoration: _inputDec('Blood Pressure', hint: 'mmHg')),
              TextField(controller: _pulseController, decoration: _inputDec('Pulse Rate', hint: 'bpm')),
              TextField(controller: _rrController, decoration: _inputDec('Respiratory Rate', hint: '/min')),
              TextField(controller: _tempController, decoration: _inputDec('Temperature', hint: '°F / °C')),
              TextField(controller: _spo2Controller, decoration: _inputDec('O₂ Saturation', hint: '%')),
              TextField(controller: _weightController, decoration: _inputDec('Weight', hint: 'kg')),
              TextField(controller: _heightController, decoration: _inputDec('Height', hint: 'cm')),
              TextField(controller: _bmiController, decoration: _inputDec('BMI', hint: 'kg/m²')),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Virtual General Examination Findings',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF475569))),
          const SizedBox(height: 12),
          TextField(controller: _appearanceController, decoration: _inputDec('General Appearance on Video')),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: TextField(controller: _consciousnessController, decoration: _inputDec('Level of Consciousness'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _orientationController, decoration: _inputDec('Orientation'))),
            ],
          ),
          const SizedBox(height: 10),
          TextField(controller: _hydrationController, decoration: _inputDec('Hydration')),
          const SizedBox(height: 16),
          const Text('Clinical Signs', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF475569))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _signChip('Pallor', _pallor, (v) => setState(() => _pallor = v)),
              _signChip('Icterus', _icterus, (v) => setState(() => _icterus = v)),
              _signChip('Cyanosis', _cyanosis, (v) => setState(() => _cyanosis = v)),
              _signChip('Clubbing', _clubbing, (v) => setState(() => _clubbing = v)),
              _signChip('Edema', _edema, (v) => setState(() => _edema = v)),
              _signChip('Lymphadenopathy', _lymphadenopathy, (v) => setState(() => _lymphadenopathy = v)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: _nutritionalController, decoration: _inputDec('Nutritional Status'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _mobilityController, decoration: _inputDec('Mobility / Gait (virtual)'))),
            ],
          ),
          const SizedBox(height: 10),
          TextField(controller: _examNotesController, decoration: _inputDec('Examination Notes'), maxLines: 3),
        ],
      ),
    );
  }

  Widget _signChip(String label, bool selected, Function(bool) onTap) {
    return GestureDetector(
      onTap: () => onTap(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primaryColor : const Color(0xFFCBD5E1)),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? Colors.white : const Color(0xFF475569),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        )),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _complaintController.dispose();
    _durationController.dispose();
    // Dispose all other controllers
    super.dispose();
  }
}

// Data class for accordion sections
class _AccordionSection {
  final int index;
  final String title;
  final IconData icon;
  final Widget child;
  const _AccordionSection({required this.index, required this.title, required this.icon, required this.child});
}
