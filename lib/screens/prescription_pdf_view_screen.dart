import 'package:flutter/material.dart';
import 'package:icare/models/enhanced_prescription.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

/// Prescription PDF-Style View Screen
/// Displays prescription in a single-page PDF-like format
/// As per client requirements - May 8, 2026
class PrescriptionPdfViewScreen extends StatelessWidget {
  final EnhancedPrescription prescription;
  final Map<String, dynamic>? patientData;
  final Map<String, dynamic>? doctorData;

  const PrescriptionPdfViewScreen({
    super.key,
    required this.prescription,
    this.patientData,
    this.doctorData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const CustomBackButton(),
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Prescription',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: AppColors.primaryColor),
            tooltip: 'Download PDF',
            onPressed: () {
              // TODO: Implement PDF download
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PDF download coming soon')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded, color: AppColors.primaryColor),
            tooltip: 'Share',
            onPressed: () {
              // TODO: Implement share
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share coming soon')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          margin: const EdgeInsets.symmetric(horizontal: 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ══════════════════════════════════════════════════════════
              // HEADER SECTION
              // ══════════════════════════════════════════════════════════
              _buildHeader(),

              const Divider(height: 1, thickness: 2),

              // ══════════════════════════════════════════════════════════
              // BODY SECTION
              // ══════════════════════════════════════════════════════════
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Diagnosis Section
                    if (prescription.diagnoses.isNotEmpty) ...[
                      _buildSectionTitle('Diagnosis', Icons.medical_services_rounded),
                      const SizedBox(height: 12),
                      ...prescription.diagnoses.map((diagnosis) => _buildDiagnosisItem(diagnosis)),
                      const SizedBox(height: 24),
                    ],

                    // Medications Section
                    if (prescription.medicines.isNotEmpty) ...[
                      _buildSectionTitle('Medications', Icons.medication_rounded),
                      const SizedBox(height: 12),
                      _buildMedicationsTable(),
                      const SizedBox(height: 24),
                    ],

                    // Lab Tests Section
                    if (prescription.labTests.isNotEmpty) ...[
                      _buildSectionTitle('Lab Tests', Icons.biotech_rounded),
                      const SizedBox(height: 12),
                      ...prescription.labTests.map((test) => _buildLabTestItem(test)),
                      const SizedBox(height: 24),
                    ],

                    // Doctor Notes Section
                    if (prescription.doctorNotes.isNotEmpty) ...[
                      _buildSectionTitle('Doctor Notes / Instructions', Icons.notes_rounded),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          prescription.doctorNotes,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                            height: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // SOAP Notes (if available)
                    if (prescription.soapNotes != null) ...[
                      _buildSectionTitle('Clinical Notes (SOAP)', Icons.description_rounded),
                      const SizedBox(height: 12),
                      _buildSOAPNotes(),
                      const SizedBox(height: 24),
                    ],

                    // Referral & Follow-up
                    if (prescription.referralFollowUp != null) ...[
                      _buildReferralFollowUp(),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),

              // ══════════════════════════════════════════════════════════
              // FOOTER SECTION
              // ══════════════════════════════════════════════════════════
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HEADER SECTION
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildHeader() {
    final prescriptionDate = DateFormat('dd MMM yyyy, hh:mm a').format(prescription.prescribedAt);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryColor.withValues(alpha: 0.05),
            AppColors.primaryColor.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Logo/Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primaryColor.withValues(alpha: 0.2)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Image.asset('assets/Asset 1.png', height: 36, width: 36, fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(Icons.local_hospital_rounded, color: AppColors.primaryColor, size: 24)),
              ),
              const SizedBox(width: 12),
              const Text(
                'iCare Telehealth',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'VERIFIED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Patient & Doctor Information Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient Information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PATIENT INFORMATION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow('Name', patientData?['name'] ?? 'N/A'),
                    _buildInfoRow('Age', patientData?['age']?.toString() ?? 'N/A'),
                    _buildInfoRow('Gender', patientData?['gender'] ?? 'N/A'),
                    _buildInfoRow('MR Number', patientData?['mrNumber'] ?? patientData?['id']?.toString().substring(0, 8) ?? 'N/A'),
                    _buildInfoRow('Date & Time', prescriptionDate),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Doctor Information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DOCTOR INFORMATION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow('Name', 'Dr. ${doctorData?['name'] ?? 'N/A'}'),
                    _buildInfoRow('PMDC License', doctorData?['pmdcLicense'] ?? doctorData?['licenseNumber'] ?? 'N/A'),
                    _buildInfoRow('Specialization', doctorData?['specialization'] ?? 'General Practitioner'),
                    _buildInfoRow('Phone', doctorData?['phone'] ?? 'N/A'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BODY SECTION COMPONENTS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primaryColor, size: 20),
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
    );
  }

  Widget _buildDiagnosisItem(DiagnosisItem diagnosis) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              diagnosis.icd10Code,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFFEF4444),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  diagnosis.diagnosis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (diagnosis.notes != null && diagnosis.notes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    diagnosis.notes!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationsTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Medicine Name',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Dose & Frequency',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Duration',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Table Rows
          ...prescription.medicines.asMap().entries.map((entry) {
            final index = entry.key;
            final medicine = entry.value;
            final isLast = index == prescription.medicines.length - 1;
            
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: isLast
                      ? BorderSide.none
                      : const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medicine.medicineName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (medicine.notes != null && medicine.notes!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            medicine.notes!,
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
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medicine.dose,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _getFrequencyLabel(medicine.frequency.toString()),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      medicine.duration,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _getFrequencyLabel(String frequency) {
    final labels = {
      'od': 'Once Daily',
      'bd': 'Twice Daily',
      'tds': 'Three Times',
      'qid': 'Four Times',
      'sos': 'As Needed',
      'stat': 'Immediately',
      'weekly': 'Weekly',
      'monthly': 'Monthly',
    };
    return labels[frequency.toLowerCase()] ?? frequency.toUpperCase();
  }

  Widget _buildLabTestItem(LabTestItem test) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              test.isUrgent ? Icons.priority_high_rounded : Icons.science_rounded,
              color: test.isUrgent ? Colors.red : const Color(0xFF3B82F6),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        test.testName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    if (test.isUrgent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'URGENT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.red,
                          ),
                        ),
                      ),
                  ],
                ),
                if (test.instructions != null && test.instructions!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    test.instructions!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSOAPNotes() {
    final soap = prescription.soapNotes!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (soap.subjective.isNotEmpty) ...[
            _buildSOAPSection('Subjective', soap.subjective),
            const SizedBox(height: 12),
          ],
          if (soap.objective.isNotEmpty) ...[
            _buildSOAPSection('Objective', soap.objective),
            const SizedBox(height: 12),
          ],
          if (soap.assessment.isNotEmpty) ...[
            _buildSOAPSection('Assessment', soap.assessment),
            const SizedBox(height: 12),
          ],
          if (soap.plan.isNotEmpty) ...[
            _buildSOAPSection('Plan', soap.plan),
          ],
        ],
      ),
    );
  }

  Widget _buildSOAPSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF0F172A),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildReferralFollowUp() {
    final referral = prescription.referralFollowUp!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.event_repeat_rounded, color: Color(0xFFF59E0B), size: 20),
              SizedBox(width: 8),
              Text(
                'Referral & Follow-up',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (referral.referralType != null && referral.referralType != 'none') ...[
            _buildInfoRow('Referral Type', referral.referralType?.toString() ?? ''),
            if (referral.referralSpecialty != null)
              _buildInfoRow('Specialty', referral.referralSpecialty!),
            if (referral.referralNotes != null)
              _buildInfoRow('Notes', referral.referralNotes!),
            const SizedBox(height: 8),
          ],
          if (referral.followUpDuration != null && referral.followUpDuration != 'none') ...[
            _buildInfoRow('Follow-up', _getFollowUpLabel(referral.followUpDuration!.toString())),
            if (referral.followUpDate != null)
              _buildInfoRow('Follow-up Date', DateFormat('dd MMM yyyy').format(referral.followUpDate!)),
            if (referral.followUpNotes != null)
              _buildInfoRow('Follow-up Notes', referral.followUpNotes!),
          ],
        ],
      ),
    );
  }

  String _getFollowUpLabel(String duration) {
    final labels = {
      'oneWeek': '1 Week',
      'twoWeeks': '2 Weeks',
      'oneMonth': '1 Month',
      'twoMonths': '2 Months',
      'threeMonths': '3 Months',
      'sixMonths': '6 Months',
    };
    return labels[duration] ?? duration;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FOOTER SECTION
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border(
          top: BorderSide(color: const Color(0xFFE2E8F0), width: 2),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Order Medicine Button
              if (prescription.medicines.isNotEmpty)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to pharmacy with prescription
                      context.push('/pharmacies', extra: {
                        'prescriptionId': prescription.id,
                        'medicines': prescription.medicines,
                      });
                    },
                    icon: const Icon(Icons.local_pharmacy_rounded, size: 20),
                    label: const Text('Order Medicine'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              if (prescription.medicines.isNotEmpty && prescription.labTests.isNotEmpty)
                const SizedBox(width: 12),
              // Order Lab Tests Button
              if (prescription.labTests.isNotEmpty)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to lab with prescription
                      context.push('/laboratories', extra: {
                        'prescriptionId': prescription.id,
                        'labTests': prescription.labTests,
                      });
                    },
                    icon: const Icon(Icons.biotech_rounded, size: 20),
                    label: const Text('Order Lab Tests'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Disclaimer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.blue, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This is a digital prescription. Valid for 30 days from issue date.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade900,
                      height: 1.4,
                    ),
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
