import 'user.dart';

// Parses a UTC ISO-8601 string from MongoDB and converts to device local time.
DateTime _parsePkt(dynamic s) {
  final str = s?.toString() ?? '';
  if (str.isEmpty) return DateTime.now();
  try {
    final normalized = str.contains('Z') || str.contains('+') ? str : '${str}Z';
    return DateTime.parse(normalized).toLocal();
  } catch (_) {
    return DateTime.now();
  }
}

class MedicalRecord {
  final String id;
  final User patient;
  final User doctor;
  final String? appointmentId;
  final String? diagnosis;
  final List<String> symptoms;
  final Prescription? prescription;
  final List<String> labTests;
  final VitalSigns? vitalSigns;
  final String? notes;
  final DateTime? followUpDate;
  final List<dynamic> assignedCourses;
  final IntakeNotes? intakeNotes; // CRITICAL FIX: Add intake notes
  final SoapNotes? soapNotes; // CRITICAL FIX: Add SOAP notes
  final DateTime createdAt;
  final DateTime updatedAt;

  MedicalRecord({
    required this.id,
    required this.patient,
    required this.doctor,
    this.appointmentId,
    this.diagnosis,
    this.symptoms = const [],
    this.prescription,
    this.labTests = const [],
    this.vitalSigns,
    this.notes,
    this.followUpDate,
    this.assignedCourses = const [],
    this.intakeNotes,
    this.soapNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MedicalRecord.fromJson(Map<String, dynamic> json) {
    // Handle doctor field - can be either a populated object or just an ID string
    User? doctor;
    if (json['doctor'] != null) {
      if (json['doctor'] is Map<String, dynamic>) {
        doctor = User.fromJson(json['doctor']);
      } else if (json['doctor'] is String) {
        // If doctor is just an ID, create a minimal User object
        doctor = User(
          id: json['doctor'],
          name: 'Doctor',
          email: '',
          phoneNumber: '',
          role: 'doctor',
        );
      }
    }

    // Handle patient field - can be either a populated object or just an ID string
    User? patient;
    if (json['patient'] != null) {
      if (json['patient'] is Map<String, dynamic>) {
        patient = User.fromJson(json['patient']);
      } else if (json['patient'] is String) {
        patient = User(
          id: json['patient'],
          name: 'Patient',
          email: '',
          phoneNumber: '',
          role: 'patient',
        );
      }
    }

    // Handle appointment field - can be object, string, or null
    String? appointmentId;
    if (json['appointment'] != null) {
      if (json['appointment'] is Map<String, dynamic>) {
        appointmentId = json['appointment']['_id'];
      } else if (json['appointment'] is String) {
        appointmentId = json['appointment'];
      }
    }

    // Safely handle diagnosis field
    String? diagnosis;
    if (json['diagnosis'] != null) {
      if (json['diagnosis'] is String) {
        diagnosis = json['diagnosis'];
      } else if (json['diagnosis'] is List &&
          (json['diagnosis'] as List).isNotEmpty) {
        diagnosis = (json['diagnosis'] as List).first.toString();
      }
    }

    return MedicalRecord(
      id: json['_id'] ?? '',
      patient:
          patient ??
          User(
            id: '',
            name: 'Unknown',
            email: '',
            phoneNumber: '',
            role: 'patient',
          ),
      doctor:
          doctor ??
          User(
            id: '',
            name: 'Unknown',
            email: '',
            phoneNumber: '',
            role: 'doctor',
          ),
      appointmentId: appointmentId,
      diagnosis: diagnosis,
      symptoms: json['symptoms'] != null
          ? (json['symptoms'] is List
                ? List<String>.from(json['symptoms'])
                : [])
          : [],
      prescription: json['prescription'] != null && json['prescription'] is Map
          ? Prescription.fromJson(json['prescription'])
          : null,
      labTests: json['labTests'] != null
          ? (json['labTests'] is List
                ? List<String>.from(json['labTests'])
                : [])
          : [],
      vitalSigns: json['vitalSigns'] != null && json['vitalSigns'] is Map
          ? VitalSigns.fromJson(json['vitalSigns'])
          : null,
      notes: json['notes'] is String ? json['notes'] : null,
      followUpDate: json['followUpDate'] != null
          ? DateTime.parse(json['followUpDate'])
          : null,
      assignedCourses: json['assignedCourses'] != null
          ? (json['assignedCourses'] is List
                ? List<dynamic>.from(json['assignedCourses'])
                : [])
          : [],
      intakeNotes: json['intakeNotes'] != null && json['intakeNotes'] is Map
          ? IntakeNotes.fromJson(json['intakeNotes'])
          : null,
      soapNotes: json['soapNotes'] != null && json['soapNotes'] is Map
          ? SoapNotes.fromJson(json['soapNotes'])
          : null,
      createdAt: _parsePkt(json['createdAt']),
      updatedAt: _parsePkt(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patientId': patient.id,
      'appointmentId': appointmentId,
      'diagnosis': diagnosis,
      'symptoms': symptoms,
      'prescription': prescription?.toJson(),
      'labTests': labTests,
      'vitalSigns': vitalSigns?.toJson(),
      'notes': notes,
      'followUpDate': followUpDate?.toIso8601String(),
    };
  }
}

// CRITICAL FIX: Add IntakeNotes model
class IntakeNotes {
  final String? chiefComplaint;
  final String? historyOfPresentIllness;
  final String? pastMedicalHistory;
  final String? medications;
  final String? allergies;
  final String? socialHistory;
  final String? familyHistory;
  final String? reviewOfSystems;
  final bool isFinalized;

  IntakeNotes({
    this.chiefComplaint,
    this.historyOfPresentIllness,
    this.pastMedicalHistory,
    this.medications,
    this.allergies,
    this.socialHistory,
    this.familyHistory,
    this.reviewOfSystems,
    this.isFinalized = false,
  });

  factory IntakeNotes.fromJson(Map<String, dynamic> json) {
    return IntakeNotes(
      chiefComplaint: json['chiefComplaint'],
      historyOfPresentIllness: json['historyOfPresentIllness'],
      pastMedicalHistory: json['pastMedicalHistory'],
      medications: json['medications'],
      allergies: json['allergies'],
      socialHistory: json['socialHistory'],
      familyHistory: json['familyHistory'],
      reviewOfSystems: json['reviewOfSystems'],
      isFinalized: json['isFinalized'] ?? false,
    );
  }
}

// CRITICAL FIX: Add SoapNotes model
class SoapNotes {
  final SoapSubjective? subjective;
  final SoapObjective? objective;
  final SoapAssessment? assessment;
  final SoapPlan? plan;
  final bool isFinalized;

  SoapNotes({
    this.subjective,
    this.objective,
    this.assessment,
    this.plan,
    this.isFinalized = false,
  });

  factory SoapNotes.fromJson(Map<String, dynamic> json) {
    return SoapNotes(
      subjective: json['subjective'] != null
          ? SoapSubjective.fromJson(json['subjective'])
          : null,
      objective: json['objective'] != null
          ? SoapObjective.fromJson(json['objective'])
          : null,
      assessment: json['assessment'] != null
          ? SoapAssessment.fromJson(json['assessment'])
          : null,
      plan: json['plan'] != null ? SoapPlan.fromJson(json['plan']) : null,
      isFinalized: json['isFinalized'] ?? false,
    );
  }
}

class SoapSubjective {
  final String? chiefComplaint;
  final String? historyOfPresentIllness;
  final String? reviewOfSystems;
  final String? patientConcerns;

  SoapSubjective({
    this.chiefComplaint,
    this.historyOfPresentIllness,
    this.reviewOfSystems,
    this.patientConcerns,
  });

  factory SoapSubjective.fromJson(Map<String, dynamic> json) {
    return SoapSubjective(
      chiefComplaint: json['chiefComplaint'],
      historyOfPresentIllness: json['historyOfPresentIllness'],
      reviewOfSystems: json['reviewOfSystems'],
      patientConcerns: json['patientConcerns'],
    );
  }
}

class SoapObjective {
  final String? physicalExamination;
  final String? labResults;
  final String? imagingResults;

  SoapObjective({
    this.physicalExamination,
    this.labResults,
    this.imagingResults,
  });

  factory SoapObjective.fromJson(Map<String, dynamic> json) {
    return SoapObjective(
      physicalExamination: json['physicalExamination'],
      labResults: json['labResults'],
      imagingResults: json['imagingResults'],
    );
  }
}

class SoapAssessment {
  final List<String> diagnosis;
  final List<String> differentialDiagnosis;
  final String? clinicalImpression;
  final List<String> icdCodes;

  SoapAssessment({
    this.diagnosis = const [],
    this.differentialDiagnosis = const [],
    this.clinicalImpression,
    this.icdCodes = const [],
  });

  factory SoapAssessment.fromJson(Map<String, dynamic> json) {
    return SoapAssessment(
      diagnosis: json['diagnosis'] != null
          ? List<String>.from(json['diagnosis'])
          : [],
      differentialDiagnosis: json['differentialDiagnosis'] != null
          ? List<String>.from(json['differentialDiagnosis'])
          : [],
      clinicalImpression: json['clinicalImpression'],
      icdCodes: json['icdCodes'] != null
          ? List<String>.from(json['icdCodes'])
          : [],
    );
  }
}

class SoapPlan {
  final String? treatment;
  final List<String> medications;
  final List<String> labTests;
  final List<String> imaging;
  final List<String> referrals;
  final String? followUp;
  final String? patientEducation;

  SoapPlan({
    this.treatment,
    this.medications = const [],
    this.labTests = const [],
    this.imaging = const [],
    this.referrals = const [],
    this.followUp,
    this.patientEducation,
  });

  factory SoapPlan.fromJson(Map<String, dynamic> json) {
    return SoapPlan(
      treatment: json['treatment'],
      medications: json['medications'] != null
          ? List<String>.from(json['medications'])
          : [],
      labTests: json['labTests'] != null
          ? List<String>.from(json['labTests'])
          : [],
      imaging: json['imaging'] != null
          ? List<String>.from(json['imaging'])
          : [],
      referrals: json['referrals'] != null
          ? List<String>.from(json['referrals'])
          : [],
      followUp: json['followUp'],
      patientEducation: json['patientEducation'],
    );
  }
}

class Prescription {
  final List<Medicine> medicines;
  final String? notes;

  Prescription({this.medicines = const [], this.notes});

  factory Prescription.fromJson(Map<String, dynamic> json) {
    return Prescription(
      medicines: json['medicines'] != null
          ? (json['medicines'] as List)
                .map((m) => Medicine.fromJson(m))
                .toList()
          : [],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'medicines': medicines.map((m) => m.toJson()).toList(),
      'notes': notes,
    };
  }
}

class Medicine {
  final String name;
  final String dosage;
  final String frequency;
  final String duration;
  final String? instructions;

  Medicine({
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.duration,
    this.instructions,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      name: json['name'] ?? '',
      dosage: json['dosage'] ?? '',
      frequency: json['frequency'] ?? '',
      duration: json['duration'] ?? '',
      instructions: json['instructions'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'duration': duration,
      'instructions': instructions,
    };
  }
}

class VitalSigns {
  final String? bloodPressure;
  final String? temperature;
  final String? heartRate;
  final String? weight;
  final String? height;

  VitalSigns({
    this.bloodPressure,
    this.temperature,
    this.heartRate,
    this.weight,
    this.height,
  });

  factory VitalSigns.fromJson(Map<String, dynamic> json) {
    return VitalSigns(
      bloodPressure: json['bloodPressure'],
      temperature: json['temperature'],
      heartRate: json['heartRate'],
      weight: json['weight'],
      height: json['height'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bloodPressure': bloodPressure,
      'temperature': temperature,
      'heartRate': heartRate,
      'weight': weight,
      'height': height,
    };
  }
}
