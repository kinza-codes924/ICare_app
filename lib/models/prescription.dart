class Prescription {
  final String id;
  final String patientId;
  final String doctorId;
  final String consultationId;
  final List<PrescriptionMedicine> medicines;
  final PrescriptionStatus status;

  // Pharmacy fulfillment
  final String? pharmacyId;
  final DateTime? pharmacyAcceptedAt;
  final DateTime? pharmacyDispatchedAt;
  final DateTime? pharmacyDeliveredAt;

  // Patient action
  final bool patientWantsFulfillment;
  final String? deliveryAddress;

  // Timestamps
  final DateTime prescribedAt;
  final DateTime? expiresAt;

  Prescription({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.consultationId,
    required this.medicines,
    required this.status,
    this.pharmacyId,
    this.pharmacyAcceptedAt,
    this.pharmacyDispatchedAt,
    this.pharmacyDeliveredAt,
    required this.patientWantsFulfillment,
    this.deliveryAddress,
    required this.prescribedAt,
    this.expiresAt,
  });

  factory Prescription.fromJson(Map<String, dynamic> json) {
    return Prescription(
      id: json['_id'] ?? '',
      patientId: json['patientId'] ?? '',
      doctorId: json['doctorId'] ?? '',
      consultationId: json['consultationId'] ?? '',
      medicines: (json['medicines'] as List?)
          ?.map((m) => PrescriptionMedicine.fromJson(m))
          .toList() ?? [],
      status: PrescriptionStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => PrescriptionStatus.active,
      ),
      pharmacyId: json['pharmacyId'],
      pharmacyAcceptedAt: json['pharmacyAcceptedAt'] != null
          ? DateTime.parse(json['pharmacyAcceptedAt'])
          : null,
      pharmacyDispatchedAt: json['pharmacyDispatchedAt'] != null
          ? DateTime.parse(json['pharmacyDispatchedAt'])
          : null,
      pharmacyDeliveredAt: json['pharmacyDeliveredAt'] != null
          ? DateTime.parse(json['pharmacyDeliveredAt'])
          : null,
      patientWantsFulfillment: json['patientWantsFulfillment'] ?? false,
      deliveryAddress: json['deliveryAddress'],
      prescribedAt: DateTime.parse(json['prescribedAt']),
      expiresAt: json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'patientId': patientId,
      'doctorId': doctorId,
      'consultationId': consultationId,
      'medicines': medicines.map((m) => m.toJson()).toList(),
      'status': status.toString().split('.').last,
      'pharmacyId': pharmacyId,
      'pharmacyAcceptedAt': pharmacyAcceptedAt?.toIso8601String(),
      'pharmacyDispatchedAt': pharmacyDispatchedAt?.toUtc().toIso8601String(),
      'pharmacyDeliveredAt': pharmacyDeliveredAt?.toUtc().toIso8601String(),
      'patientWantsFulfillment': patientWantsFulfillment,
      'deliveryAddress': deliveryAddress,
      'prescribedAt': prescribedAt.toUtc().toIso8601String(),
      'expiresAt': expiresAt?.toUtc().toIso8601String(),
    };
  }
}

class PrescriptionMedicine {
  final String medicineName;
  final String dosage;
  final String frequency;
  final String duration;
  final String instructions;
  final int quantity;

  PrescriptionMedicine({
    required this.medicineName,
    required this.dosage,
    required this.frequency,
    required this.duration,
    required this.instructions,
    required this.quantity,
  });

  factory PrescriptionMedicine.fromJson(Map<String, dynamic> json) {
    return PrescriptionMedicine(
      medicineName: json['medicineName'] ?? '',
      dosage: json['dosage'] ?? '',
      frequency: json['frequency'] ?? '',
      duration: json['duration'] ?? '',
      instructions: json['instructions'] ?? '',
      quantity: json['quantity'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'medicineName': medicineName,
      'dosage': dosage,
      'frequency': frequency,
      'duration': duration,
      'instructions': instructions,
      'quantity': quantity,
    };
  }
}

enum PrescriptionStatus {
  active,
  fulfilled,
  expired,
  cancelled,
}
