import 'package:icare/models/clinical_audit.dart';
import 'package:icare/models/consultation.dart';
import 'package:icare/models/prescription.dart';
import 'package:icare/models/lab_test_request.dart';

/// Clinical Audit Service
///
/// Automatically audits consultations for quality assurance
/// Tracks metrics across the connected virtual hospital ecosystem
class ClinicalAuditService {
  static final ClinicalAuditService _instance = ClinicalAuditService._internal();
  factory ClinicalAuditService() => _instance;
  ClinicalAuditService._internal();

  /// Audit a completed consultation
  Future<ClinicalAudit> auditConsultation(
    Consultation consultation,
    List<Prescription>? prescriptions,
    List<LabTestRequest>? labTests,
  ) async {
    // Calculate quality scores
    final qualityScore = _calculateQualityScore(consultation, prescriptions, labTests);

    // Identify quality flags
    final flags = _identifyQualityFlags(consultation, prescriptions, labTests);

    // Determine audit status
    final status = flags.any((f) => f.severity == QualityFlagSeverity.critical || f.severity == QualityFlagSeverity.high)
        ? AuditStatus.flaggedForReview
        : AuditStatus.reviewed;

    final audit = ClinicalAudit(
      id: 'audit_${DateTime.now().millisecondsSinceEpoch}',
      consultationId: consultation.id,
      doctorId: consultation.doctorId,
      patientId: consultation.patientId,
      auditDate: DateTime.now(),
      qualityScore: qualityScore,
      flags: flags,
      status: status,
    );

    // In real implementation, save to backend
    await _saveAudit(audit);

    return audit;
  }

  /// Calculate quality score based on documentation completeness
  ConsultationQualityScore _calculateQualityScore(
    Consultation consultation,
    List<Prescription>? prescriptions,
    List<LabTestRequest>? labTests,
  ) {
    int documentationScore = _calculateDocumentationScore(consultation);
    int clinicalReasoningScore = _calculateClinicalReasoningScore(consultation);
    int prescriptionScore = _calculatePrescriptionScore(consultation, prescriptions);
    int followUpScore = _calculateFollowUpScore(consultation, labTests);

    int overallScore = ((documentationScore + clinicalReasoningScore + prescriptionScore + followUpScore) / 4).round();

    return ConsultationQualityScore(
      documentationCompleteness: documentationScore,
      clinicalReasoningScore: clinicalReasoningScore,
      prescriptionAppropriatenessScore: prescriptionScore,
      followUpPlanScore: followUpScore,
      overallScore: overallScore,
    );
  }

  /// Calculate documentation completeness score
  int _calculateDocumentationScore(Consultation consultation) {
    int score = 0;
    int maxScore = 0;

    // History section (40 points)
    maxScore += 40;
    if (consultation.history?.chiefComplaint.isNotEmpty ?? false) score += 10;
    if (consultation.history?.historyOfPresentIllness.isNotEmpty ?? false) score += 10;
    if (consultation.history?.pastMedicalHistory.isNotEmpty ?? false) score += 10;
    if (consultation.history?.medications.isNotEmpty ?? false) score += 10;

    // Examination section (30 points)
    maxScore += 30;
    if (consultation.examination != null) {
      score += 15;
      if (consultation.examination!.notes.isNotEmpty) score += 15;
    }

    // Diagnosis section (20 points)
    maxScore += 20;
    if (consultation.diagnosis != null) {
      if (consultation.diagnosis!.primaryDiagnosis.isNotEmpty) score += 10;
      if (consultation.diagnosis!.icdCode.isNotEmpty) score += 10;
    }

    // Treatment plan section (10 points)
    maxScore += 10;
    if (consultation.plan != null) {
      if (consultation.plan!.prescriptionIds.isNotEmpty ||
          consultation.plan!.labTestRequestIds.isNotEmpty ||
          consultation.plan!.healthProgramIds.isNotEmpty) {
        score += 10;
      }
    }

    return ((score / maxScore) * 100).round();
  }

  /// Calculate clinical reasoning score
  int _calculateClinicalReasoningScore(Consultation consultation) {
    int score = 100;

    // Check if diagnosis matches symptoms
    if (consultation.diagnosis == null) {
      score -= 50;
    } else {
      // Check if ICD code is provided
      if (consultation.diagnosis!.icdCode.isEmpty) score -= 20;

      // Check if differential diagnosis is considered
      if (consultation.diagnosis!.differentialDiagnosis.isEmpty) score -= 10;
    }

    // Check if examination findings support diagnosis
    if (consultation.examination == null || consultation.examination!.notes.isEmpty) {
      score -= 20;
    }

    return score.clamp(0, 100);
  }

  /// Calculate prescription appropriateness score
  int _calculatePrescriptionScore(Consultation consultation, List<Prescription>? prescriptions) {
    if (prescriptions == null || prescriptions.isEmpty) {
      // No prescriptions is fine if not needed
      return 100;
    }

    int score = 100;

    for (var prescription in prescriptions) {
      // Check for proper dosage instructions
      for (var medicine in prescription.medicines) {
        if (medicine.dosage.isEmpty || medicine.frequency.isEmpty) {
          score -= 15;
        }
      }

      // Check for drug allergies
      if (consultation.history?.allergies.isNotEmpty ?? false) {
        for (var medicine in prescription.medicines) {
          // In real implementation, check against allergy database
          // For now, just flag if patient has allergies
          score -= 5;
        }
      }
    }

    return score.clamp(0, 100);
  }

  /// Calculate follow-up plan score
  int _calculateFollowUpScore(Consultation consultation, List<LabTestRequest>? labTests) {
    int score = 100;

    // Check if follow-up is scheduled for chronic conditions
    if (consultation.diagnosis != null) {
      final chronicConditions = ['diabetes', 'hypertension', 'asthma', 'copd', 'heart'];
      final diagnosisLower = consultation.diagnosis!.primaryDiagnosis.toLowerCase();

      if (chronicConditions.any((c) => diagnosisLower.contains(c))) {
        if (consultation.plan?.followUpInstructions.isEmpty ?? true) {
          score -= 30;
        }
      }
    }

    // Check if lab tests have proper follow-up instructions
    if (labTests != null && labTests.isNotEmpty) {
      if (consultation.plan?.followUpInstructions.isEmpty ?? true) {
        score -= 20;
      }
    }

    return score.clamp(0, 100);
  }

  /// Identify quality flags
  List<QualityFlag> _identifyQualityFlags(
    Consultation consultation,
    List<Prescription>? prescriptions,
    List<LabTestRequest>? labTests,
  ) {
    List<QualityFlag> flags = [];

    // Check for incomplete documentation
    if (consultation.history?.chiefComplaint.isEmpty ?? true) {
      flags.add(QualityFlag(
        type: QualityFlagType.incompleteDocumentation,
        description: 'Missing chief complaint',
        severity: QualityFlagSeverity.high,
        flaggedAt: DateTime.now(),
      ));
    }

    // Check for missing vital signs
    if (consultation.examination == null) {
      flags.add(QualityFlag(
        type: QualityFlagType.missingVitalSigns,
        description: 'Vital signs not recorded',
        severity: QualityFlagSeverity.medium,
        flaggedAt: DateTime.now(),
      ));
    }

    // Check for missing diagnosis
    if (consultation.diagnosis == null || consultation.diagnosis!.primaryDiagnosis.isEmpty) {
      flags.add(QualityFlag(
        type: QualityFlagType.diagnosticInconsistency,
        description: 'No diagnosis documented',
        severity: QualityFlagSeverity.critical,
        flaggedAt: DateTime.now(),
      ));
    }

    // Check for prescriptions without proper documentation
    if (prescriptions != null && prescriptions.isNotEmpty) {
      // Check for potential drug interactions with current medications
      if (consultation.history?.medications.isNotEmpty ?? false) {
        flags.add(QualityFlag(
          type: QualityFlagType.drugInteraction,
          description: 'Patient on multiple medications - check for interactions',
          severity: QualityFlagSeverity.medium,
          flaggedAt: DateTime.now(),
        ));
      }
    }

    // Check for missing follow-up plan
    if (consultation.plan?.followUpInstructions.isEmpty ?? true) {
      if (labTests != null && labTests.isNotEmpty) {
        flags.add(QualityFlag(
          type: QualityFlagType.missingFollowUp,
          description: 'Lab tests ordered but no follow-up plan documented',
          severity: QualityFlagSeverity.high,
          flaggedAt: DateTime.now(),
        ));
      }
    }

    return flags;
  }

  Future<void> _saveAudit(ClinicalAudit audit) async {
    // In real implementation, save to backend
    await Future.delayed(const Duration(milliseconds: 100));
  }

  /// Get quality metrics for a doctor
  Future<DoctorQualityMetrics> getDoctorQualityMetrics(String doctorId, DateTime startDate, DateTime endDate) async {
    // In real implementation, fetch from backend
    await Future.delayed(const Duration(milliseconds: 500));

    return DoctorQualityMetrics(
      doctorId: doctorId,
      period: '${startDate.toString().split(' ')[0]} to ${endDate.toString().split(' ')[0]}',
      totalConsultations: 45,
      averageQualityScore: 87,
      documentationCompleteness: 92,
      clinicalReasoningScore: 85,
      prescriptionAppropriatenessScore: 88,
      followUpPlanScore: 83,
      criticalFlags: 2,
      highFlags: 5,
      mediumFlags: 12,
      lowFlags: 8,
    );
  }

  /// Get system-wide quality metrics
  Future<SystemQualityMetrics> getSystemQualityMetrics(DateTime startDate, DateTime endDate) async {
    // In real implementation, fetch from backend
    await Future.delayed(const Duration(milliseconds: 500));

    return SystemQualityMetrics(
      period: '${startDate.toString().split(' ')[0]} to ${endDate.toString().split(' ')[0]}',
      totalConsultations: 1247,
      averageQualityScore: 89,
      documentationCompleteness: 94,
      clinicalReasoningScore: 87,
      prescriptionAppropriatenessScore: 90,
      followUpPlanScore: 85,
      consultationsFlaggedForReview: 34,
      averageLabTurnaroundTime: 2.3,
      averagePharmacyFulfillmentTime: 4.5,
      prescriptionComplianceRate: 89,
    );
  }
}

class DoctorQualityMetrics {
  final String doctorId;
  final String period;
  final int totalConsultations;
  final int averageQualityScore;
  final int documentationCompleteness;
  final int clinicalReasoningScore;
  final int prescriptionAppropriatenessScore;
  final int followUpPlanScore;
  final int criticalFlags;
  final int highFlags;
  final int mediumFlags;
  final int lowFlags;

  DoctorQualityMetrics({
    required this.doctorId,
    required this.period,
    required this.totalConsultations,
    required this.averageQualityScore,
    required this.documentationCompleteness,
    required this.clinicalReasoningScore,
    required this.prescriptionAppropriatenessScore,
    required this.followUpPlanScore,
    required this.criticalFlags,
    required this.highFlags,
    required this.mediumFlags,
    required this.lowFlags,
  });
}

class SystemQualityMetrics {
  final String period;
  final int totalConsultations;
  final int averageQualityScore;
  final int documentationCompleteness;
  final int clinicalReasoningScore;
  final int prescriptionAppropriatenessScore;
  final int followUpPlanScore;
  final int consultationsFlaggedForReview;
  final double averageLabTurnaroundTime;
  final double averagePharmacyFulfillmentTime;
  final int prescriptionComplianceRate;

  SystemQualityMetrics({
    required this.period,
    required this.totalConsultations,
    required this.averageQualityScore,
    required this.documentationCompleteness,
    required this.clinicalReasoningScore,
    required this.prescriptionAppropriatenessScore,
    required this.followUpPlanScore,
    required this.consultationsFlaggedForReview,
    required this.averageLabTurnaroundTime,
    required this.averagePharmacyFulfillmentTime,
    required this.prescriptionComplianceRate,
  });
}
