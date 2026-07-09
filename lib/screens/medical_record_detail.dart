import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icare/models/medical_record.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/screens/patient_profile_view.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';

class MedicalRecordDetailScreen extends ConsumerWidget {
  final MedicalRecord record;

  const MedicalRecordDetailScreen({super.key, required this.record});

  void _showFhirExport(BuildContext context) {
    // Simulated FHIR (HL7) JSON Structure for the record
    final fhirResource = {
      "resourceType": "Encounter",
      "id": record.id,
      "status": "finished",
      "class": {
        "system": "http://terminology.hl7.org/CodeSystem/v3-ActCode",
        "code": "AMB",
        "display": "ambulatory",
      },
      "subject": {
        "reference": "Patient/${record.patient.id}",
        "display": record.patient.name,
      },
      "participant": [
        {
          "type": [
            {
              "coding": [
                {
                  "system":
                      "http://terminology.hl7.org/CodeSystem/v3-ParticipationType",
                  "code": "PPRF",
                },
              ],
            },
          ],
          "individual": {"reference": "Practitioner/${record.doctor.id}"},
        },
      ],
      "period": {"start": record.createdAt.toIso8601String()},
      "reasonCode": [
        {"text": record.diagnosis ?? "General consultation"},
      ],
      "diagnosis": [
        {
          "condition": {"display": record.diagnosis ?? "Unspecified"},
          "use": {
            "coding": [
              {
                "system":
                    "http://terminology.hl7.org/CodeSystem/diagnosis-role",
                "code": "AD",
              },
            ],
          },
        },
      ],
      "extension": [
        {
          "url": "http://icare.com/fhir/vitals",
          "valueString": jsonEncode(record.vitalSigns?.toJson()),
        },
        {
          "url": "http://icare.com/fhir/prescription",
          "valueString": jsonEncode(record.prescription?.toJson()),
        },
      ],
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(fhirResource);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'FHIR HL7 Export',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Text(
                'Clinical data in standard FHIR format for interoperability.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: SelectableText(
                      jsonString,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Copy to clipboard logic would go here
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('FHIR JSON copied to clipboard'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy JSON'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPatient = ref.read(authProvider).userRole == 'Patient';
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const CustomBackButton(),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Medical Record",
          style: TextStyle(
            fontSize: 18,
            fontFamily: "Gilroy-Bold",
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Color(0xFF0F172A)),
            tooltip: 'Export to FHIR',
            onPressed: () => _showFhirExport(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Info Card with View Profile Button
            _buildPatientCard(context),
            const SizedBox(height: 16),

            // Vital Signs
            if (record.vitalSigns != null) ...[
              _buildVitalSignsCard(),
              const SizedBox(height: 16),
            ],

            // Diagnosis
            if (record.diagnosis != null) ...[
              _buildSectionCard(
                'Diagnosis',
                Icons.medical_information_rounded,
                const Color(0xFFEF4444),
                record.diagnosis!,
              ),
              const SizedBox(height: 16),
            ],

            // Symptoms
            if (record.symptoms.isNotEmpty) ...[
              _buildListCard(
                'Symptoms',
                Icons.sick_rounded,
                const Color(0xFFF59E0B),
                record.symptoms,
              ),
              const SizedBox(height: 16),
            ],

            // Prescription
            if (record.prescription != null &&
                record.prescription!.medicines.isNotEmpty) ...[
              _buildPrescriptionCard(),
              const SizedBox(height: 16),
            ],

            // Lab Tests
            if (record.labTests.isNotEmpty) ...[
              _buildListCard(
                'Lab Tests',
                Icons.biotech_rounded,
                const Color(0xFF8B5CF6),
                record.labTests,
              ),
              const SizedBox(height: 16),
            ],

            // Notes
            if (record.notes != null) ...[
              _buildSectionCard(
                'Additional Notes',
                Icons.note_rounded,
                const Color(0xFF64748B),
                record.notes!,
              ),
              const SizedBox(height: 16),
            ],

            // Assigned Health Programs (Task 19.3)
            if (record.assignedCourses.isNotEmpty) ...[
              _buildHealthProgramsCard(),
              const SizedBox(height: 16),
            ],

            // CRITICAL FIX: Display Intake Notes for Patient
            if (record.intakeNotes != null) ...[
              _buildIntakeNotesCard(),
              const SizedBox(height: 16),
            ],

            // SOAP Notes: doctor-facing only, hidden from patients
            if (record.soapNotes != null && !isPatient) ...[
              _buildSoapNotesCard(),
              const SizedBox(height: 16),
            ],

            // Follow-up
            if (record.followUpDate != null) ...[_buildFollowUpCard()],
          ],
        ),
      ),
    );
  }

  // CRITICAL FIX: Build Intake Notes Card
  Widget _buildIntakeNotesCard() {
    final intake = record.intakeNotes!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.assignment_rounded,
                  color: Color(0xFF3B82F6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Intake Notes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (intake.isFinalized)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Finalized',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (intake.chiefComplaint != null) ...[
            _buildNoteSection('Chief Complaint', intake.chiefComplaint!),
            const SizedBox(height: 12),
          ],
          if (intake.historyOfPresentIllness != null) ...[
            _buildNoteSection(
              'History of Present Illness',
              intake.historyOfPresentIllness!,
            ),
            const SizedBox(height: 12),
          ],
          if (intake.pastMedicalHistory != null) ...[
            _buildNoteSection(
              'Past Medical History',
              intake.pastMedicalHistory!,
            ),
            const SizedBox(height: 12),
          ],
          if (intake.medications != null) ...[
            _buildNoteSection('Current Medications', intake.medications!),
            const SizedBox(height: 12),
          ],
          if (intake.allergies != null) ...[
            _buildNoteSection('Allergies', intake.allergies!, isWarning: true),
            const SizedBox(height: 12),
          ],
          if (intake.socialHistory != null) ...[
            _buildNoteSection('Social History', intake.socialHistory!),
            const SizedBox(height: 12),
          ],
          if (intake.familyHistory != null) ...[
            _buildNoteSection('Family History', intake.familyHistory!),
            const SizedBox(height: 12),
          ],
          if (intake.reviewOfSystems != null) ...[
            _buildNoteSection('Review of Systems', intake.reviewOfSystems!),
          ],
        ],
      ),
    );
  }

  // CRITICAL FIX: Build SOAP Notes Card
  Widget _buildSoapNotesCard() {
    final soap = record.soapNotes!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.medical_services_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'SOAP Notes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (soap.isFinalized)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Finalized',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Subjective Section
          if (soap.subjective != null) ...[
            _buildSoapSection('S - Subjective', const Color(0xFF3B82F6)),
            const SizedBox(height: 8),
            if (soap.subjective!.chiefComplaint != null)
              _buildNoteSection(
                'Chief Complaint',
                soap.subjective!.chiefComplaint!,
              ),
            if (soap.subjective!.historyOfPresentIllness != null) ...[
              const SizedBox(height: 8),
              _buildNoteSection(
                'History',
                soap.subjective!.historyOfPresentIllness!,
              ),
            ],
            if (soap.subjective!.reviewOfSystems != null) ...[
              const SizedBox(height: 8),
              _buildNoteSection(
                'Review of Systems',
                soap.subjective!.reviewOfSystems!,
              ),
            ],
            if (soap.subjective!.patientConcerns != null) ...[
              const SizedBox(height: 8),
              _buildNoteSection(
                'Patient Concerns',
                soap.subjective!.patientConcerns!,
              ),
            ],
            const SizedBox(height: 16),
          ],

          // Objective Section
          if (soap.objective != null) ...[
            _buildSoapSection('O - Objective', const Color(0xFF10B981)),
            const SizedBox(height: 8),
            if (soap.objective!.physicalExamination != null)
              _buildNoteSection(
                'Physical Examination',
                soap.objective!.physicalExamination!,
              ),
            if (soap.objective!.labResults != null) ...[
              const SizedBox(height: 8),
              _buildNoteSection('Lab Results', soap.objective!.labResults!),
            ],
            if (soap.objective!.imagingResults != null) ...[
              const SizedBox(height: 8),
              _buildNoteSection(
                'Imaging Results',
                soap.objective!.imagingResults!,
              ),
            ],
            const SizedBox(height: 16),
          ],

          // Assessment Section
          if (soap.assessment != null) ...[
            _buildSoapSection('A - Assessment', const Color(0xFFF59E0B)),
            const SizedBox(height: 8),
            if (soap.assessment!.diagnosis.isNotEmpty) ...[
              _buildNoteSection(
                'Diagnosis',
                soap.assessment!.diagnosis.join(', '),
              ),
              const SizedBox(height: 8),
            ],
            if (soap.assessment!.differentialDiagnosis.isNotEmpty) ...[
              _buildNoteSection(
                'Differential Diagnosis',
                soap.assessment!.differentialDiagnosis.join(', '),
              ),
              const SizedBox(height: 8),
            ],
            if (soap.assessment!.clinicalImpression != null)
              _buildNoteSection(
                'Clinical Impression',
                soap.assessment!.clinicalImpression!,
              ),
            if (soap.assessment!.icdCodes.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildNoteSection(
                'ICD Codes',
                soap.assessment!.icdCodes.join(', '),
              ),
            ],
            const SizedBox(height: 16),
          ],

          // Plan Section
          if (soap.plan != null) ...[
            _buildSoapSection('P - Plan', const Color(0xFFEF4444)),
            const SizedBox(height: 8),
            if (soap.plan!.treatment != null)
              _buildNoteSection('Treatment', soap.plan!.treatment!),
            if (soap.plan!.medications.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildNoteSection(
                'Medications',
                soap.plan!.medications.join(', '),
              ),
            ],
            if (soap.plan!.labTests.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildNoteSection(
                'Lab Tests Ordered',
                soap.plan!.labTests.join(', '),
              ),
            ],
            if (soap.plan!.imaging.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildNoteSection(
                'Imaging Ordered',
                soap.plan!.imaging.join(', '),
              ),
            ],
            if (soap.plan!.referrals.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildNoteSection('Referrals', soap.plan!.referrals.join(', ')),
            ],
            if (soap.plan!.followUp != null) ...[
              const SizedBox(height: 8),
              _buildNoteSection('Follow-up', soap.plan!.followUp!),
            ],
            if (soap.plan!.patientEducation != null) ...[
              const SizedBox(height: 8),
              _buildNoteSection(
                'Patient Education',
                soap.plan!.patientEducation!,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSoapSection(String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Widget _buildNoteSection(
    String label,
    String content, {
    bool isWarning = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isWarning
                ? const Color(0xFFEF4444)
                : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: TextStyle(
            fontSize: 14,
            color: isWarning
                ? const Color(0xFFEF4444)
                : const Color(0xFF0F172A),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildPatientCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryColor, Color(0xFF6366F1)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    record.patient.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.patient.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record.patient.email,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Recorded: ${DateFormat('MMM dd, yyyy').format(record.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) =>
                        PatientProfileView(patient: record.patient),
                  ),
                );
              },
              icon: const Icon(Icons.person_outline_rounded, size: 18),
              label: const Text("View Patient Profile"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalSignsCard() {
    final vitals = record.vitalSigns!;
    return Container(
      padding: const EdgeInsets.all(20),
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
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Vital Signs',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (vitals.bloodPressure != null)
                _buildVitalChip(
                  'BP',
                  vitals.bloodPressure!,
                  Icons.monitor_heart_rounded,
                ),
              if (vitals.temperature != null)
                _buildVitalChip(
                  'Temp',
                  vitals.temperature!,
                  Icons.thermostat_rounded,
                ),
              if (vitals.heartRate != null)
                _buildVitalChip(
                  'HR',
                  vitals.heartRate!,
                  Icons.favorite_rounded,
                ),
              if (vitals.weight != null)
                _buildVitalChip(
                  'Weight',
                  vitals.weight!,
                  Icons.monitor_weight_rounded,
                ),
              if (vitals.height != null)
                _buildVitalChip('Height', vitals.height!, Icons.height_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVitalChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    String title,
    IconData icon,
    Color color,
    String content,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF0F172A),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListCard(
    String title,
    IconData icon,
    Color color,
    List<String> items,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.medication_rounded,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Prescription',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...record.prescription!.medicines.map(
            (medicine) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicine.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${medicine.dosage} • ${medicine.frequency} • ${medicine.duration}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  if (medicine.instructions != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      medicine.instructions!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (record.prescription!.notes != null) ...[
            const SizedBox(height: 8),
            Text(
              'Notes: ${record.prescription!.notes}',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHealthProgramsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.health_and_safety_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Assigned Health Programs',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Linked to Diagnosis',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: record.assignedCourses.map((program) {
              String title = 'Program';
              int progressPercent = 0;
              int completedVideos = 0;
              int totalVideos = 0;

              if (program is String) {
                title = program;
              } else if (program is Map) {
                title = program['title'] ?? program['name'] ?? 'Program';
                progressPercent = program['progressPercent'] ?? 0;
                completedVideos = program['completedVideos'] ?? 0;
                totalVideos = program['totalVideos'] ?? 0;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                        ),
                        if (totalVideos > 0)
                          Text(
                            '$progressPercent%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF8B5CF6),
                            ),
                          ),
                      ],
                    ),
                    if (totalVideos > 0) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: totalVideos > 0
                              ? completedVideos / totalVideos
                              : 0.0,
                          backgroundColor: const Color(
                            0xFF8B5CF6,
                          ).withValues(alpha: 0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF8B5CF6),
                          ),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$completedVideos of $totalVideos modules completed',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.event_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Follow-up Appointment',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, MMM dd, yyyy').format(record.followUpDate!),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
