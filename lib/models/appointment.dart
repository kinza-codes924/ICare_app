class Appointment {
  final String id;
  final String doctorId;
  final String patientId;
  final DateTime date;
  final String timeSlot;
  final String? reason;
  final String status;
  final String? cancellationReason;
  final String? cancelledBy;
  final DateTime? cancelledAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Appointment({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.date,
    required this.timeSlot,
    this.reason,
    required this.status,
    this.cancellationReason,
    this.cancelledBy,
    this.cancelledAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['_id'] ?? json['id'] ?? '',
      // Backend may send doctor_id (snake_case) or doctor (populated object)
      doctorId: json['doctor_id'] as String? ??
          (json['doctor'] is String
              ? json['doctor'] as String
              : (json['doctor'] as Map<String, dynamic>?)?['_id'] as String? ??
                    ''),
      patientId: json['patient_id'] as String? ??
          (json['patient'] is String
              ? json['patient'] as String
              : (json['patient'] as Map<String, dynamic>?)?['_id'] as String? ??
                    ''),
      // Backend may send appointment_date (date-only string) or date (ISO)
      date: _parseDate(json['appointment_date'] ?? json['date']),
      timeSlot: json['appointment_time'] as String? ??
          json['timeSlot'] as String? ??
          '',
      reason: json['reason'] as String? ?? json['notes'] as String?,
      status: json['status'] as String? ?? 'pending',
      cancellationReason: json['cancellationReason'] as String?,
      cancelledBy: json['cancelledBy'] as String?,
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.tryParse(json['cancelledAt'] as String)
          : null,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }

  Map<String, dynamic> toJson() {
    return {
      'doctorId': doctorId,
      'date': date.toIso8601String(),
      'timeSlot': timeSlot,
      'reason': reason,
    };
  }
}
