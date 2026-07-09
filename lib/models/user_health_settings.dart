class UserHealthSettings {
  final String? id;
  final String userId;
  final bool healthModeEnabled;
  final List<String> selectedConditions;
  final TrackedVitals trackedVitals;
  final DailyGoals dailyGoals;
  final UnitPreferences unitPreferences;
  final Reminders reminders;
  final ConsultationPreferences consultationPreferences;
  final PharmacyPreferences pharmacyPreferences;
  final LabPreferences labPreferences;
  final LearningPreferences learningPreferences;
  final NotificationPreferences notificationPreferences;

  UserHealthSettings({
    this.id,
    required this.userId,
    this.healthModeEnabled = false,
    this.selectedConditions = const ['General'],
    required this.trackedVitals,
    required this.dailyGoals,
    required this.unitPreferences,
    required this.reminders,
    required this.consultationPreferences,
    required this.pharmacyPreferences,
    required this.labPreferences,
    required this.learningPreferences,
    required this.notificationPreferences,
  });

  factory UserHealthSettings.fromJson(Map<String, dynamic> json) {
    return UserHealthSettings(
      id: json['_id'],
      userId: json['userId'],
      healthModeEnabled: json['healthModeEnabled'] ?? false,
      selectedConditions: List<String>.from(json['selectedConditions'] ?? ['General']),
      trackedVitals: TrackedVitals.fromJson(json['trackedVitals'] ?? {}),
      dailyGoals: DailyGoals.fromJson(json['dailyGoals'] ?? {}),
      unitPreferences: UnitPreferences.fromJson(json['unitPreferences'] ?? {}),
      reminders: Reminders.fromJson(json['reminders'] ?? {}),
      consultationPreferences: ConsultationPreferences.fromJson(json['consultationPreferences'] ?? {}),
      pharmacyPreferences: PharmacyPreferences.fromJson(json['pharmacyPreferences'] ?? {}),
      labPreferences: LabPreferences.fromJson(json['labPreferences'] ?? {}),
      learningPreferences: LearningPreferences.fromJson(json['learningPreferences'] ?? {}),
      notificationPreferences: NotificationPreferences.fromJson(json['notificationPreferences'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'userId': userId,
      'healthModeEnabled': healthModeEnabled,
      'selectedConditions': selectedConditions,
      'trackedVitals': trackedVitals.toJson(),
      'dailyGoals': dailyGoals.toJson(),
      'unitPreferences': unitPreferences.toJson(),
      'reminders': reminders.toJson(),
      'consultationPreferences': consultationPreferences.toJson(),
      'pharmacyPreferences': pharmacyPreferences.toJson(),
      'labPreferences': labPreferences.toJson(),
      'learningPreferences': learningPreferences.toJson(),
      'notificationPreferences': notificationPreferences.toJson(),
    };
  }
}

class TrackedVitals {
  final bool bloodPressure;
  final bool bloodSugar;
  final bool weight;
  final bool water;
  final bool medication;
  final bool steps;
  final bool sleep;
  final bool heartRate;
  final bool temperature;
  final bool oxygenLevel;

  TrackedVitals({
    this.bloodPressure = true,
    this.bloodSugar = true,
    this.weight = false,
    this.water = true,
    this.medication = true,
    this.steps = false,
    this.sleep = false,
    this.heartRate = true,
    this.temperature = false,
    this.oxygenLevel = false,
  });

  factory TrackedVitals.fromJson(Map<String, dynamic> json) {
    return TrackedVitals(
      bloodPressure: json['bloodPressure'] ?? true,
      bloodSugar: json['bloodSugar'] ?? true,
      weight: json['weight'] ?? false,
      water: json['water'] ?? true,
      medication: json['medication'] ?? true,
      steps: json['steps'] ?? false,
      sleep: json['sleep'] ?? false,
      heartRate: json['heartRate'] ?? true,
      temperature: json['temperature'] ?? false,
      oxygenLevel: json['oxygenLevel'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bloodPressure': bloodPressure,
      'bloodSugar': bloodSugar,
      'weight': weight,
      'water': water,
      'medication': medication,
      'steps': steps,
      'sleep': sleep,
      'heartRate': heartRate,
      'temperature': temperature,
      'oxygenLevel': oxygenLevel,
    };
  }
}

class DailyGoals {
  final int water;
  final int steps;
  final int sleep;

  DailyGoals({
    this.water = 8,
    this.steps = 10000,
    this.sleep = 8,
  });

  factory DailyGoals.fromJson(Map<String, dynamic> json) {
    return DailyGoals(
      water: json['water'] ?? 8,
      steps: json['steps'] ?? 10000,
      sleep: json['sleep'] ?? 8,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'water': water,
      'steps': steps,
      'sleep': sleep,
    };
  }
}

class UnitPreferences {
  final String weight;
  final String bloodSugar;

  UnitPreferences({
    this.weight = 'kg',
    this.bloodSugar = 'mg/dL',
  });

  factory UnitPreferences.fromJson(Map<String, dynamic> json) {
    return UnitPreferences(
      weight: json['weight'] ?? 'kg',
      bloodSugar: json['bloodSugar'] ?? 'mg/dL',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'weight': weight,
      'bloodSugar': bloodSugar,
    };
  }
}

class MedicationReminder {
  final String time;
  final bool enabled;
  final String? label;

  MedicationReminder({
    required this.time,
    this.enabled = true,
    this.label,
  });

  factory MedicationReminder.fromJson(Map<String, dynamic> json) {
    return MedicationReminder(
      time: json['time'],
      enabled: json['enabled'] ?? true,
      label: json['label'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'time': time,
      'enabled': enabled,
      if (label != null) 'label': label,
    };
  }
}

class WaterReminder {
  final int interval;
  final bool enabled;

  WaterReminder({
    this.interval = 120,
    this.enabled = false,
  });

  factory WaterReminder.fromJson(Map<String, dynamic> json) {
    return WaterReminder(
      interval: json['interval'] ?? 120,
      enabled: json['enabled'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'interval': interval,
      'enabled': enabled,
    };
  }
}

class HealthCheckReminder {
  final String time;
  final bool enabled;

  HealthCheckReminder({
    this.time = '09:00',
    this.enabled = false,
  });

  factory HealthCheckReminder.fromJson(Map<String, dynamic> json) {
    return HealthCheckReminder(
      time: json['time'] ?? '09:00',
      enabled: json['enabled'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'time': time,
      'enabled': enabled,
    };
  }
}

class Reminders {
  final List<MedicationReminder> medication;
  final WaterReminder water;
  final HealthCheckReminder healthCheck;

  Reminders({
    this.medication = const [],
    required this.water,
    required this.healthCheck,
  });

  factory Reminders.fromJson(Map<String, dynamic> json) {
    return Reminders(
      medication: (json['medication'] as List?)
          ?.map((e) => MedicationReminder.fromJson(e))
          .toList() ?? [],
      water: WaterReminder.fromJson(json['water'] ?? {}),
      healthCheck: HealthCheckReminder.fromJson(json['healthCheck'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'medication': medication.map((e) => e.toJson()).toList(),
      'water': water.toJson(),
      'healthCheck': healthCheck.toJson(),
    };
  }
}

class ConsultationPreferences {
  final String preferredLanguage;
  final String preferredDoctorGender;
  final bool allowHistoryAccess;
  final String videoQuality;

  ConsultationPreferences({
    this.preferredLanguage = 'English',
    this.preferredDoctorGender = 'No Preference',
    this.allowHistoryAccess = true,
    this.videoQuality = 'Auto',
  });

  factory ConsultationPreferences.fromJson(Map<String, dynamic> json) {
    return ConsultationPreferences(
      preferredLanguage: json['preferredLanguage'] ?? 'English',
      preferredDoctorGender: json['preferredDoctorGender'] ?? 'No Preference',
      allowHistoryAccess: json['allowHistoryAccess'] ?? true,
      videoQuality: json['videoQuality'] ?? 'Auto',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'preferredLanguage': preferredLanguage,
      'preferredDoctorGender': preferredDoctorGender,
      'allowHistoryAccess': allowHistoryAccess,
      'videoQuality': videoQuality,
    };
  }
}

class DeliveryAddress {
  final String? street;
  final String? city;
  final String? postalCode;
  final String? phone;

  DeliveryAddress({
    this.street,
    this.city,
    this.postalCode,
    this.phone,
  });

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) {
    return DeliveryAddress(
      street: json['street'],
      city: json['city'],
      postalCode: json['postalCode'],
      phone: json['phone'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (street != null) 'street': street,
      if (city != null) 'city': city,
      if (postalCode != null) 'postalCode': postalCode,
      if (phone != null) 'phone': phone,
    };
  }
}

class PharmacyPreferences {
  final String? preferredPharmacyId;
  final DeliveryAddress? defaultDeliveryAddress;
  final String deliveryPreference;

  PharmacyPreferences({
    this.preferredPharmacyId,
    this.defaultDeliveryAddress,
    this.deliveryPreference = 'Home Delivery',
  });

  factory PharmacyPreferences.fromJson(Map<String, dynamic> json) {
    return PharmacyPreferences(
      preferredPharmacyId: json['preferredPharmacyId'],
      defaultDeliveryAddress: json['defaultDeliveryAddress'] != null
          ? DeliveryAddress.fromJson(json['defaultDeliveryAddress'])
          : null,
      deliveryPreference: json['deliveryPreference'] ?? 'Home Delivery',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (preferredPharmacyId != null) 'preferredPharmacyId': preferredPharmacyId,
      if (defaultDeliveryAddress != null) 'defaultDeliveryAddress': defaultDeliveryAddress!.toJson(),
      'deliveryPreference': deliveryPreference,
    };
  }
}

class LabPreferences {
  final bool homeSampleCollection;
  final String reportDeliveryMethod;

  LabPreferences({
    this.homeSampleCollection = true,
    this.reportDeliveryMethod = 'All',
  });

  factory LabPreferences.fromJson(Map<String, dynamic> json) {
    return LabPreferences(
      homeSampleCollection: json['homeSampleCollection'] ?? true,
      reportDeliveryMethod: json['reportDeliveryMethod'] ?? 'All',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'homeSampleCollection': homeSampleCollection,
      'reportDeliveryMethod': reportDeliveryMethod,
    };
  }
}

class LearningPreferences {
  final bool notifyNewCourses;
  final bool notifyAssignments;
  final bool notifyCertificates;

  LearningPreferences({
    this.notifyNewCourses = true,
    this.notifyAssignments = true,
    this.notifyCertificates = true,
  });

  factory LearningPreferences.fromJson(Map<String, dynamic> json) {
    return LearningPreferences(
      notifyNewCourses: json['notifyNewCourses'] ?? true,
      notifyAssignments: json['notifyAssignments'] ?? true,
      notifyCertificates: json['notifyCertificates'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notifyNewCourses': notifyNewCourses,
      'notifyAssignments': notifyAssignments,
      'notifyCertificates': notifyCertificates,
    };
  }
}

class NotificationPreferences {
  final bool appointments;
  final bool prescriptions;
  final bool labResults;
  final bool promotions;
  final bool healthTips;

  NotificationPreferences({
    this.appointments = true,
    this.prescriptions = true,
    this.labResults = true,
    this.promotions = false,
    this.healthTips = true,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      appointments: json['appointments'] ?? true,
      prescriptions: json['prescriptions'] ?? true,
      labResults: json['labResults'] ?? true,
      promotions: json['promotions'] ?? false,
      healthTips: json['healthTips'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'appointments': appointments,
      'prescriptions': prescriptions,
      'labResults': labResults,
      'promotions': promotions,
      'healthTips': healthTips,
    };
  }
}
