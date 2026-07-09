import 'user.dart';

class Doctor {
  final String id;
  final User user;
  final String? specialization;
  final String? pmdcNumber;
  final List<String> consultationType;
  final List<String> languages;
  final List<String> degrees;
  final String? experience;
  final String? licenseNumber;
  final String? clinicName;
  final String? clinicAddress;
  final List<String> availableDays;
  final AvailableTime? availableTime;
  final bool isApproved;
  final bool isOnline;
  final List<double> ratings;
  final List<String> reviews;
  final double? consultationFee;
  final List<String> conditionsTreated;
  final bool emergencySlots;

  Doctor({
    required this.id,
    required this.user,
    this.specialization,
    this.pmdcNumber,
    this.consultationType = const [],
    this.languages = const [],
    this.degrees = const [],
    this.experience,
    this.licenseNumber,
    this.clinicName,
    this.clinicAddress,
    this.availableDays = const [],
    this.availableTime,
    this.isApproved = false,
    this.isOnline = false,
    this.ratings = const [],
    this.reviews = const [],
    this.consultationFee,
    this.conditionsTreated = const [],
    this.emergencySlots = false,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    // Handle consultationType - can be String or List
    List<String> parseConsultationType(dynamic value) {
      if (value == null) return [];
      if (value is String) return [value];
      if (value is List) return List<String>.from(value);
      return [];
    }

    // Safe list parsing helper
    List<String> parseStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
      }
      return [];
    }

    // Safe ratings parsing
    List<double> parseRatings(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value
            .map((r) {
              if (r is num) return r.toDouble();
              if (r is String) return double.tryParse(r);
              return null;
            })
            .where((r) => r != null)
            .cast<double>()
            .toList();
      }
      return [];
    }

    // Support both nested-user format and flat format from API
    Map<String, dynamic> userJson;
    if (json['user'] is Map) {
      userJson = Map<String, dynamic>.from(json['user'] as Map);
      // If nested user lacks profilePicture, try top-level field as fallback
      if ((userJson['profilePicture'] == null || (userJson['profilePicture'] as String?) == '') &&
          json['profilePicture'] != null) {
        userJson = {...userJson, 'profilePicture': json['profilePicture']};
      }
    } else {
      userJson = <String, dynamic>{
        '_id': json['_id'] ?? json['id'] ?? '',
        'name': json['name'] ?? '',
        'email': json['email'] ?? '',
        'phoneNumber': json['phoneNumber'] ?? json['phone'] ?? '',
        'role': json['role'] ?? '',
        'profilePicture': json['profilePicture'],
      };
    }

    // availableTime can be a Map or a plain String like "9:00 AM - 5:00 PM"
    AvailableTime? parseAvailableTime(dynamic value) {
      if (value == null) return null;
      if (value is Map) {
        return AvailableTime.fromJson(Map<String, dynamic>.from(value));
      }
      if (value is String && value.isNotEmpty) {
        final parts = value.split(' - ');
        return AvailableTime(
          start: parts.isNotEmpty ? parts[0] : value,
          end: parts.length > 1 ? parts[1] : '',
        );
      }
      return null;
    }

    return Doctor(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      user: User.fromJson(userJson),
      specialization: json['specialization']?.toString(),
      pmdcNumber: json['pmdcNumber']?.toString(),
      consultationType: parseConsultationType(json['consultationType']),
      languages: parseStringList(json['languages']),
      degrees: parseStringList(json['degrees']),
      experience: json['experience']?.toString(),
      licenseNumber: json['licenseNumber']?.toString(),
      clinicName: json['clinicName']?.toString(),
      clinicAddress: json['clinicAddress']?.toString(),
      availableDays: parseStringList(json['availableDays']),
      availableTime: parseAvailableTime(json['availableTime']),
      isApproved: json['isApproved'] == true,
      isOnline: json['isOnline'] == true,
      ratings: parseRatings(json['ratings']),
      reviews: parseStringList(json['reviews']),
      consultationFee: (json['consultationFee'] ?? json['consultation_fee'])?.toDouble(),
      conditionsTreated: parseStringList(json['conditionsTreated'] ?? json['conditions_treated']),
      emergencySlots: json['emergencySlots'] == true || json['availability']?['emergencySlots'] == true,
    );
  }

  double get averageRating {
    if (ratings.isEmpty) return 0.0;
    return ratings.reduce((a, b) => a + b) / ratings.length;
  }

  int get reviewCount => reviews.length;
}

class AvailableTime {
  final String start;
  final String end;

  AvailableTime({required this.start, required this.end});

  factory AvailableTime.fromJson(Map<String, dynamic> json) {
    return AvailableTime(start: json['start'] ?? '', end: json['end'] ?? '');
  }

  Map<String, dynamic> toJson() {
    return {'start': start, 'end': end};
  }
}
