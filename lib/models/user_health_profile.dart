class UserHealthProfile {
  final String? id;
  final String userId;
  final String bloodGroup;
  final Height? height;
  final List<MedicalCondition> medicalConditions;
  final List<Allergy> allergies;
  final List<Medication> currentMedications;
  final List<HealthGoal> healthGoals;
  final List<EmergencyContact> emergencyContacts;
  final List<FamilyMedicalHistory> familyMedicalHistory;
  final Lifestyle lifestyle;
  final Insurance? insurance;

  UserHealthProfile({
    this.id,
    required this.userId,
    this.bloodGroup = 'Unknown',
    this.height,
    this.medicalConditions = const [],
    this.allergies = const [],
    this.currentMedications = const [],
    this.healthGoals = const [],
    this.emergencyContacts = const [],
    this.familyMedicalHistory = const [],
    required this.lifestyle,
    this.insurance,
  });

  factory UserHealthProfile.fromJson(Map<String, dynamic> json) {
    return UserHealthProfile(
      id: json['_id'],
      userId: json['userId'],
      bloodGroup: json['bloodGroup'] ?? 'Unknown',
      height: json['height'] != null ? Height.fromJson(json['height']) : null,
      medicalConditions: (json['medicalConditions'] as List?)
          ?.map((e) => MedicalCondition.fromJson(e))
          .toList() ?? [],
      allergies: (json['allergies'] as List?)
          ?.map((e) => Allergy.fromJson(e))
          .toList() ?? [],
      currentMedications: (json['currentMedications'] as List?)
          ?.map((e) => Medication.fromJson(e))
          .toList() ?? [],
      healthGoals: (json['healthGoals'] as List?)
          ?.map((e) => HealthGoal.fromJson(e))
          .toList() ?? [],
      emergencyContacts: (json['emergencyContacts'] as List?)
          ?.map((e) => EmergencyContact.fromJson(e))
          .toList() ?? [],
      familyMedicalHistory: (json['familyMedicalHistory'] as List?)
          ?.map((e) => FamilyMedicalHistory.fromJson(e))
          .toList() ?? [],
      lifestyle: Lifestyle.fromJson(json['lifestyle'] ?? {}),
      insurance: json['insurance'] != null ? Insurance.fromJson(json['insurance']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'userId': userId,
      'bloodGroup': bloodGroup,
      if (height != null) 'height': height!.toJson(),
      'medicalConditions': medicalConditions.map((e) => e.toJson()).toList(),
      'allergies': allergies.map((e) => e.toJson()).toList(),
      'currentMedications': currentMedications.map((e) => e.toJson()).toList(),
      'healthGoals': healthGoals.map((e) => e.toJson()).toList(),
      'emergencyContacts': emergencyContacts.map((e) => e.toJson()).toList(),
      'familyMedicalHistory': familyMedicalHistory.map((e) => e.toJson()).toList(),
      'lifestyle': lifestyle.toJson(),
      if (insurance != null) 'insurance': insurance!.toJson(),
    };
  }

  List<Medication> getActiveMedications() {
    return currentMedications.where((med) => med.isActive).toList();
  }

  List<MedicalCondition> getActiveConditions() {
    return medicalConditions.where((cond) => cond.isActive).toList();
  }

  EmergencyContact? getPrimaryEmergencyContact() {
    return emergencyContacts.firstWhere(
      (contact) => contact.isPrimary,
      orElse: () => emergencyContacts.isNotEmpty ? emergencyContacts[0] : EmergencyContact(name: '', phone: '', relation: ''),
    );
  }
}

class Height {
  final double? value;
  final String unit;

  Height({
    this.value,
    this.unit = 'cm',
  });

  factory Height.fromJson(Map<String, dynamic> json) {
    return Height(
      value: json['value']?.toDouble(),
      unit: json['unit'] ?? 'cm',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (value != null) 'value': value,
      'unit': unit,
    };
  }
}

class MedicalCondition {
  final String? id;
  final String name;
  final DateTime? diagnosedDate;
  final String? notes;
  final bool isActive;

  MedicalCondition({
    this.id,
    required this.name,
    this.diagnosedDate,
    this.notes,
    this.isActive = true,
  });

  factory MedicalCondition.fromJson(Map<String, dynamic> json) {
    return MedicalCondition(
      id: json['_id'],
      name: json['name'],
      diagnosedDate: json['diagnosedDate'] != null ? DateTime.parse(json['diagnosedDate']) : null,
      notes: json['notes'],
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'name': name,
      if (diagnosedDate != null) 'diagnosedDate': diagnosedDate!.toIso8601String(),
      if (notes != null) 'notes': notes,
      'isActive': isActive,
    };
  }
}

class Allergy {
  final String? id;
  final String allergen;
  final String type;
  final String severity;
  final String? reaction;
  final String? notes;

  Allergy({
    this.id,
    required this.allergen,
    this.type = 'Other',
    this.severity = 'Moderate',
    this.reaction,
    this.notes,
  });

  factory Allergy.fromJson(Map<String, dynamic> json) {
    return Allergy(
      id: json['_id'],
      allergen: json['allergen'],
      type: json['type'] ?? 'Other',
      severity: json['severity'] ?? 'Moderate',
      reaction: json['reaction'],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'allergen': allergen,
      'type': type,
      'severity': severity,
      if (reaction != null) 'reaction': reaction,
      if (notes != null) 'notes': notes,
    };
  }
}

class Medication {
  final String? id;
  final String name;
  final String? dosage;
  final String? frequency;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? prescribedBy;
  final String? purpose;
  final bool isActive;

  Medication({
    this.id,
    required this.name,
    this.dosage,
    this.frequency,
    this.startDate,
    this.endDate,
    this.prescribedBy,
    this.purpose,
    this.isActive = true,
  });

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      id: json['_id'],
      name: json['name'],
      dosage: json['dosage'],
      frequency: json['frequency'],
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      prescribedBy: json['prescribedBy'],
      purpose: json['purpose'],
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'name': name,
      if (dosage != null) 'dosage': dosage,
      if (frequency != null) 'frequency': frequency,
      if (startDate != null) 'startDate': startDate!.toIso8601String(),
      if (endDate != null) 'endDate': endDate!.toIso8601String(),
      if (prescribedBy != null) 'prescribedBy': prescribedBy,
      if (purpose != null) 'purpose': purpose,
      'isActive': isActive,
    };
  }
}

class HealthGoal {
  final String? id;
  final String goal;
  final DateTime? targetDate;
  final String status;
  final String? notes;

  HealthGoal({
    this.id,
    required this.goal,
    this.targetDate,
    this.status = 'Not Started',
    this.notes,
  });

  factory HealthGoal.fromJson(Map<String, dynamic> json) {
    return HealthGoal(
      id: json['_id'],
      goal: json['goal'],
      targetDate: json['targetDate'] != null ? DateTime.parse(json['targetDate']) : null,
      status: json['status'] ?? 'Not Started',
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'goal': goal,
      if (targetDate != null) 'targetDate': targetDate!.toIso8601String(),
      'status': status,
      if (notes != null) 'notes': notes,
    };
  }
}

class EmergencyContact {
  final String? id;
  final String name;
  final String phone;
  final String relation;
  final bool isPrimary;

  EmergencyContact({
    this.id,
    required this.name,
    required this.phone,
    required this.relation,
    this.isPrimary = false,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['_id'],
      name: json['name'],
      phone: json['phone'],
      relation: json['relation'],
      isPrimary: json['isPrimary'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'name': name,
      'phone': phone,
      'relation': relation,
      'isPrimary': isPrimary,
    };
  }
}

class FamilyMedicalHistory {
  final String? id;
  final String? relation;
  final String? condition;
  final String? notes;

  FamilyMedicalHistory({
    this.id,
    this.relation,
    this.condition,
    this.notes,
  });

  factory FamilyMedicalHistory.fromJson(Map<String, dynamic> json) {
    return FamilyMedicalHistory(
      id: json['_id'],
      relation: json['relation'],
      condition: json['condition'],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      if (relation != null) 'relation': relation,
      if (condition != null) 'condition': condition,
      if (notes != null) 'notes': notes,
    };
  }
}

class Lifestyle {
  final String smokingStatus;
  final String alcoholConsumption;
  final String exerciseFrequency;
  final String dietType;

  Lifestyle({
    this.smokingStatus = 'Unknown',
    this.alcoholConsumption = 'Unknown',
    this.exerciseFrequency = 'Unknown',
    this.dietType = 'Unknown',
  });

  factory Lifestyle.fromJson(Map<String, dynamic> json) {
    return Lifestyle(
      smokingStatus: json['smokingStatus'] ?? 'Unknown',
      alcoholConsumption: json['alcoholConsumption'] ?? 'Unknown',
      exerciseFrequency: json['exerciseFrequency'] ?? 'Unknown',
      dietType: json['dietType'] ?? 'Unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'smokingStatus': smokingStatus,
      'alcoholConsumption': alcoholConsumption,
      'exerciseFrequency': exerciseFrequency,
      'dietType': dietType,
    };
  }
}

class Insurance {
  final String? provider;
  final String? policyNumber;
  final DateTime? expiryDate;

  Insurance({
    this.provider,
    this.policyNumber,
    this.expiryDate,
  });

  factory Insurance.fromJson(Map<String, dynamic> json) {
    return Insurance(
      provider: json['provider'],
      policyNumber: json['policyNumber'],
      expiryDate: json['expiryDate'] != null ? DateTime.parse(json['expiryDate']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (provider != null) 'provider': provider,
      if (policyNumber != null) 'policyNumber': policyNumber,
      if (expiryDate != null) 'expiryDate': expiryDate!.toIso8601String(),
    };
  }
}
