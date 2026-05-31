import 'package:icare/models/user.dart';

class AppointmentDetail {
  final String id;
  final User? doctor;
  final User? patient;
  final DateTime date;
  final String timeSlot;
  final String? reason;
  final String status;
  final String? channelName;
  final String? consultationType;
  final int? durationMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppointmentDetail({
    required this.id,
    this.doctor,
    this.patient,
    required this.date,
    required this.timeSlot,
    this.reason,
    required this.status,
    this.channelName,
    this.consultationType,
    this.durationMinutes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppointmentDetail.fromJson(Map<String, dynamic> json) {
    User? doctor;
    User? patient;

    try {
      if (json['doctor'] != null && json['doctor'] is Map) {
        doctor = User.fromJson(json['doctor'] as Map<String, dynamic>);
      } else if (json['doctor_name'] != null || json['doctor_email'] != null) {
        // Flat format from backend
        doctor = User(
          id: json['doctor_id']?.toString() ?? '',
          name: json['doctor_name']?.toString() ?? 'Doctor',
          email: json['doctor_email']?.toString() ?? '',
          phoneNumber: json['doctor_phone']?.toString() ?? '',
          role: 'doctor',
        );
      }
    } catch (e) {
      print('⚠️ Error parsing doctor: $e');
    }

    try {
      if (json['patient'] != null && json['patient'] is Map) {
        patient = User.fromJson(json['patient'] as Map<String, dynamic>);
      } else if (json['patient_name'] != null || json['patient_id'] != null) {
        // Flat format from backend
        patient = User(
          id: json['patient_id']?.toString() ?? '',
          name: json['patient_name']?.toString() ?? 'Patient',
          email: '',
          phoneNumber: '',
          role: 'patient',
          age: json['patient_age']?.toString(),
          gender: json['patient_gender']?.toString(),
          profilePicture: json['patient_profilePicture']?.toString() ??
              json['patient_profile_picture']?.toString() ??
              json['patientProfilePicture']?.toString(),
        );
      }
    } catch (e) {
      print('⚠️ Error parsing patient: $e');
    }

    // Backend returns appointment_date / appointment_time; some paths use date / timeSlot
    final rawDate = json['date'] ?? json['appointment_date'];
    final parsedDate = rawDate != null
        ? DateTime.tryParse(rawDate.toString()) ?? DateTime.now()
        : DateTime.now();

    return AppointmentDetail(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      doctor: doctor,
      patient: patient,
      date: parsedDate,
      timeSlot: json['timeSlot']?.toString() ?? json['appointment_time']?.toString() ?? '',
      reason: json['reason']?.toString() ?? json['notes']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      channelName: json['channel_name']?.toString(),
      consultationType: json['consultation_type']?.toString(),
      durationMinutes: json['durationMinutes'] is num
          ? (json['durationMinutes'] as num).toInt()
          : int.tryParse(json['durationMinutes']?.toString() ?? ''),
      createdAt: DateTime.tryParse(
        json['createdAt']?.toString() ?? '',
      ) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(
        json['updatedAt']?.toString() ?? '',
      ) ?? DateTime.now(),
    );
  }

  String get doctorName => doctor?.name ?? 'Doctor';
  String get doctorEmail => doctor?.email ?? 'N/A';
  String get patientName => patient?.name ?? 'Patient';
}
