// Enhanced Prescription Model with Lifestyle Advice
// Updated as per client requirements - May 4, 2026

import 'package:icare/models/lifestyle_advice.dart';

class EnhancedPrescription {
  final String? id;
  final String patientId;
  final String doctorId;
  final String consultationId;
  
  // Patient History Reference
  final String? patientHistoryId;
  
  // SOAP Notes
  final SOAPNotes? soapNotes;
  
  // Doctor Notes (renamed from Diagnosis Notes)
  final String doctorNotes;
  
  // Diagnosis
  final List<DiagnosisItem> diagnoses;
  
  // Medications
  final List<PrescriptionMedicine> medicines;
  
  // Lab Tests
  final List<LabTestItem> labTests;
  
  // Lifestyle Advice (NEW)
  final LifestyleAdvice? lifestyleAdvice;
  
  // Referral & Follow-up
  final ReferralFollowUp? referralFollowUp;
  
  // Course Assignment
  final List<String> assignedCourseIds;
  
  // Status
  final PrescriptionStatus status;
  final bool isComplete;
  
  // Timestamps
  final DateTime prescribedAt;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  EnhancedPrescription({
    this.id,
    required this.patientId,
    required this.doctorId,
    required this.consultationId,
    this.patientHistoryId,
    this.soapNotes,
    required this.doctorNotes,
    required this.diagnoses,
    required this.medicines,
    required this.labTests,
    this.lifestyleAdvice,
    this.referralFollowUp,
    required this.assignedCourseIds,
    required this.status,
    required this.isComplete,
    required this.prescribedAt,
    this.expiresAt,
    required this.createdAt,
    this.updatedAt,
  });

  factory EnhancedPrescription.fromJson(Map<String, dynamic> json) {
    return EnhancedPrescription(
      id: json['_id'],
      patientId: json['patientId'] ?? '',
      doctorId: json['doctorId'] ?? '',
      consultationId: json['consultationId'] ?? '',
      patientHistoryId: json['patientHistoryId'],
      soapNotes: json['soapNotes'] != null ? SOAPNotes.fromJson(json['soapNotes']) : null,
      doctorNotes: json['doctorNotes'] ?? '',
      diagnoses: (json['diagnoses'] as List?)
          ?.map((e) => DiagnosisItem.fromJson(e))
          .toList() ?? [],
      medicines: (json['medicines'] as List?)
          ?.map((e) => PrescriptionMedicine.fromJson(e))
          .toList() ?? [],
      labTests: (json['labTests'] as List?)
          ?.map((e) => LabTestItem.fromJson(e))
          .toList() ?? [],
      lifestyleAdvice: json['lifestyleAdvice'] != null 
          ? LifestyleAdvice.fromJson(json['lifestyleAdvice']) : null,
      referralFollowUp: json['referralFollowUp'] != null 
          ? ReferralFollowUp.fromJson(json['referralFollowUp']) : null,
      assignedCourseIds: List<String>.from(json['assignedCourseIds'] ?? []),
      status: PrescriptionStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => PrescriptionStatus.draft,
      ),
      isComplete: json['isComplete'] ?? false,
      prescribedAt: DateTime.parse(json['prescribedAt']),
      expiresAt: json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : null,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'patientId': patientId,
      'doctorId': doctorId,
      'consultationId': consultationId,
      'patientHistoryId': patientHistoryId,
      'soapNotes': soapNotes?.toJson(),
      'doctorNotes': doctorNotes,
      'diagnoses': diagnoses.map((e) => e.toJson()).toList(),
      'medicines': medicines.map((e) => e.toJson()).toList(),
      'labTests': labTests.map((e) => e.toJson()).toList(),
      'lifestyleAdvice': lifestyleAdvice?.toJson(),
      'referralFollowUp': referralFollowUp?.toJson(),
      'assignedCourseIds': assignedCourseIds,
      'status': status.toString().split('.').last,
      'isComplete': isComplete,
      'prescribedAt': prescribedAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // Check if prescription is within 30-day active window
  bool get isWithinActiveWindow {
    final now = DateTime.now();
    final daysSincePrescribed = now.difference(prescribedAt).inDays;
    return daysSincePrescribed <= 30;
  }

  // Validation
  bool get hasMinimumRequiredFields {
    return diagnoses.isNotEmpty || medicines.isNotEmpty || labTests.isNotEmpty;
  }

  String? validateCompletion() {
    // Doctor notes OR SOAP notes must have some content
    final hasSoapContent = soapNotes != null && (
      soapNotes!.subjective.trim().isNotEmpty ||
      soapNotes!.objective.trim().isNotEmpty ||
      soapNotes!.assessment.trim().isNotEmpty ||
      soapNotes!.plan.trim().isNotEmpty
    );
    final hasNotes = doctorNotes.trim().isNotEmpty;

    if (!hasNotes && !hasSoapContent && !hasMinimumRequiredFields) {
      return 'Please add at least one item: diagnosis, medication, lab test, or doctor notes';
    }
    return null;
  }
}

// SOAP Notes
class SOAPNotes {
  final String subjective;
  final String objective;
  final String assessment;
  final String plan;

  SOAPNotes({
    required this.subjective,
    required this.objective,
    required this.assessment,
    required this.plan,
  });

  factory SOAPNotes.fromJson(Map<String, dynamic> json) {
    return SOAPNotes(
      subjective: json['subjective'] ?? '',
      objective: json['objective'] ?? '',
      assessment: json['assessment'] ?? '',
      plan: json['plan'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subjective': subjective,
      'objective': objective,
      'assessment': assessment,
      'plan': plan,
    };
  }
}

// Diagnosis Item with ICD-10
class DiagnosisItem {
  final String diagnosis;
  final String icd10Code;
  final String? notes;

  DiagnosisItem({
    required this.diagnosis,
    required this.icd10Code,
    this.notes,
  });

  factory DiagnosisItem.fromJson(Map<String, dynamic> json) {
    return DiagnosisItem(
      diagnosis: json['diagnosis'] ?? '',
      icd10Code: json['icd10Code'] ?? '',
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'diagnosis': diagnosis,
      'icd10Code': icd10Code,
      'notes': notes,
    };
  }
}

// Prescription Medicine
enum MedicineFormType { tablet, capsule, liquid, injection, cream, drops, inhaler, other }

extension MedicineFormTypeExtension on MedicineFormType {
  String get value => toString().split('.').last;
  String get displayName {
    switch (this) {
      case MedicineFormType.tablet: return 'Tablet';
      case MedicineFormType.capsule: return 'Capsule';
      case MedicineFormType.liquid: return 'Liquid / Syrup';
      case MedicineFormType.injection: return 'Injection';
      case MedicineFormType.cream: return 'Cream / Ointment';
      case MedicineFormType.drops: return 'Drops';
      case MedicineFormType.inhaler: return 'Inhaler';
      case MedicineFormType.other: return 'Other';
    }
  }
  static MedicineFormType fromString(String? val) {
    return MedicineFormType.values.firstWhere(
      (e) => e.value == (val ?? '').toLowerCase(),
      orElse: () => MedicineFormType.tablet,
    );
  }
}

class PrescriptionMedicine {
  final String medicineName;
  final String dose;
  final MedicineFormType formType;
  final MedicationFrequency frequency;
  final String duration;
  final String? notes;

  PrescriptionMedicine({
    required this.medicineName,
    required this.dose,
    this.formType = MedicineFormType.tablet,
    required this.frequency,
    required this.duration,
    this.notes,
  });

  factory PrescriptionMedicine.fromJson(Map<String, dynamic> json) {
    return PrescriptionMedicine(
      medicineName: json['medicineName'] ?? '',
      dose: json['dose'] ?? '',
      formType: MedicineFormTypeExtension.fromString(json['formType']?.toString()),
      frequency: MedicationFrequency.values.firstWhere(
        (e) => e.toString().split('.').last == json['frequency'],
        orElse: () => MedicationFrequency.od,
      ),
      duration: json['duration'] ?? '',
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'medicineName': medicineName,
      'dose': dose,
      'formType': formType.value,
      'frequency': frequency.toString().split('.').last,
      'duration': duration,
      'notes': notes,
    };
  }

  String get frequencyDisplay {
    switch (frequency) {
      case MedicationFrequency.od:
        return 'Once Daily (OD)';
      case MedicationFrequency.bd:
        return 'Twice Daily (BD)';
      case MedicationFrequency.tds:
        return 'Three Times Daily (TDS)';
      case MedicationFrequency.qid:
        return 'Four Times Daily (QID)';
      case MedicationFrequency.sos:
        return 'As Needed (SOS)';
      case MedicationFrequency.stat:
        return 'Immediately (STAT)';
      case MedicationFrequency.weekly:
        return 'Weekly';
      case MedicationFrequency.monthly:
        return 'Monthly';
    }
  }
}

enum MedicationFrequency {
  od,    // Once daily
  bd,    // Twice daily
  tds,   // Three times daily
  qid,   // Four times daily
  sos,   // As needed
  stat,  // Immediately
  weekly,
  monthly,
}

// Lab Test Item
class LabTestItem {
  final String testName;
  final String? instructions;
  final bool isUrgent;

  LabTestItem({
    required this.testName,
    this.instructions,
    required this.isUrgent,
  });

  factory LabTestItem.fromJson(Map<String, dynamic> json) {
    return LabTestItem(
      testName: json['testName'] ?? '',
      instructions: json['instructions'],
      isUrgent: json['isUrgent'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'testName': testName,
      'instructions': instructions,
      'isUrgent': isUrgent,
    };
  }
}

// Referral & Follow-up
class ReferralFollowUp {
  final ReferralType? referralType;
  final String? referralSpecialty;
  final String? referralNotes;
  final FollowUpDuration? followUpDuration;
  final DateTime? followUpDate;
  final String? followUpNotes;

  ReferralFollowUp({
    this.referralType,
    this.referralSpecialty,
    this.referralNotes,
    this.followUpDuration,
    this.followUpDate,
    this.followUpNotes,
  });

  factory ReferralFollowUp.fromJson(Map<String, dynamic> json) {
    return ReferralFollowUp(
      referralType: json['referralType'] != null
          ? ReferralType.values.firstWhere(
              (e) => e.toString().split('.').last == json['referralType'],
              orElse: () => ReferralType.none,
            )
          : null,
      referralSpecialty: json['referralSpecialty'],
      referralNotes: json['referralNotes'],
      followUpDuration: json['followUpDuration'] != null
          ? FollowUpDuration.values.firstWhere(
              (e) => e.toString().split('.').last == json['followUpDuration'],
              orElse: () => FollowUpDuration.none,
            )
          : null,
      followUpDate: json['followUpDate'] != null 
          ? DateTime.parse(json['followUpDate']) : null,
      followUpNotes: json['followUpNotes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'referralType': referralType?.toString().split('.').last,
      'referralSpecialty': referralSpecialty,
      'referralNotes': referralNotes,
      'followUpDuration': followUpDuration?.toString().split('.').last,
      'followUpDate': followUpDate?.toIso8601String(),
      'followUpNotes': followUpNotes,
    };
  }
}

enum ReferralType {
  none,
  emergency,
  hospital,
  specialist,
}

enum FollowUpDuration {
  none,
  threeDays,
  oneWeek,
  tenDays,
  twoWeeks,
  fifteenDays,
  oneMonth,
  twoMonths,
  threeMonths,
  sixMonths,
}

extension FollowUpDurationExtension on FollowUpDuration {
  String get display {
    switch (this) {
      case FollowUpDuration.none:
        return 'No Follow-up';
      case FollowUpDuration.threeDays:
        return '3 Days';
      case FollowUpDuration.oneWeek:
        return '1 Week';
      case FollowUpDuration.tenDays:
        return '10 Days';
      case FollowUpDuration.twoWeeks:
        return '2 Weeks';
      case FollowUpDuration.fifteenDays:
        return '15 Days';
      case FollowUpDuration.oneMonth:
        return '1 Month';
      case FollowUpDuration.twoMonths:
        return '2 Months';
      case FollowUpDuration.threeMonths:
        return '3 Months';
      case FollowUpDuration.sixMonths:
        return '6 Months';
    }
  }
}

enum PrescriptionStatus {
  draft,
  active,
  expired,
  cancelled,
}

// Common Lab Tests
class CommonLabTests {
  static const List<String> tests = [
    'CBC (Complete Blood Count)',
    'Blood Glucose Fasting',
    'Lipid Profile',
    'LFTs (Liver Function Tests)',
    'RFTs (Renal Function Tests)',
    'HbA1c',
    'Thyroid Profile',
    'Urine Analysis',
    'ECG',
    'Chest X-Ray',
    'Ultrasound Abdomen',
  ];
}
