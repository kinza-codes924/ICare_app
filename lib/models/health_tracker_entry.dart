class HealthTrackerEntry {
  final String? id;
  final String userId;
  final String vitalType;
  final String value;
  final String unit;
  final String notes;
  final DateTime timestamp;
  final String status;

  HealthTrackerEntry({
    this.id,
    required this.userId,
    required this.vitalType,
    required this.value,
    required this.unit,
    this.notes = '',
    required this.timestamp,
    this.status = 'Normal',
  });

  factory HealthTrackerEntry.fromJson(Map<String, dynamic> json) {
    return HealthTrackerEntry(
      id: json['_id'],
      userId: json['userId'],
      vitalType: json['vitalType'],
      value: json['value'],
      unit: json['unit'],
      notes: json['notes'] ?? '',
      timestamp: DateTime.parse(json['timestamp']).toLocal(),
      status: json['status'] ?? 'Normal',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'userId': userId,
      'vitalType': vitalType,
      'value': value,
      'unit': unit,
      'notes': notes,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
    };
  }

  HealthTrackerEntry copyWith({
    String? id,
    String? userId,
    String? vitalType,
    String? value,
    String? unit,
    String? notes,
    DateTime? timestamp,
    String? status,
  }) {
    return HealthTrackerEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      vitalType: vitalType ?? this.vitalType,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      notes: notes ?? this.notes,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
    );
  }
}

class VitalSummary {
  final int count;
  final double? average;
  final double? min;
  final double? max;
  final String? trend;

  VitalSummary({
    required this.count,
    this.average,
    this.min,
    this.max,
    this.trend,
  });

  factory VitalSummary.fromJson(Map<String, dynamic> json) {
    return VitalSummary(
      count: json['count'] ?? 0,
      average: json['average']?.toDouble(),
      min: json['min']?.toDouble(),
      max: json['max']?.toDouble(),
      trend: json['trend'],
    );
  }
}
