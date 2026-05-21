import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:icare/models/appointment.dart';
import 'package:icare/models/appointment_detail.dart';
import 'package:icare/services/api_service.dart';

class AppointmentService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> bookAppointment({
    required String doctorId,
    required DateTime date,
    required String timeSlot,
    String? reason,
    bool isEmergency = false,
  }) async {
    try {
      debugPrint('📅 Booking appointment...');
      debugPrint('Doctor ID: $doctorId');
      debugPrint('Date: $date');
      debugPrint('Time Slot: $timeSlot');
      debugPrint('Reason: $reason');
      debugPrint('Emergency: $isEmergency');

      final response = await _apiService
          .post('/appointments/book_appointment', {
            'doctorId': doctorId,
            'date': date.toIso8601String(),
            'timeSlot': timeSlot,
            'reason': reason,
            if (isEmergency) 'isEmergency': true,
            if (isEmergency) 'type': 'emergency',
          });

      debugPrint('✅ Appointment booked successfully');
      debugPrint('Response: ${response.data}');

      final data = response.data as Map<String, dynamic>;

      return {
        'success': true,
        'message': data['message'] ?? 'Appointment booked successfully',
        'appointment': data['appointment'] != null
            ? Appointment.fromJson(data['appointment'])
            : null,
      };
    } on DioException catch (e) {
      debugPrint('❌ Appointment booking error: ${e.message}');
      debugPrint('Response: ${e.response?.data}');

      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to book appointment',
      };
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  Future<Map<String, dynamic>> getMyAppointmentsDetailed() async {
    try {
      debugPrint('📋 Fetching my appointments...');

      final response = await _apiService.get('/appointments/getAppointments');
      final data = response.data as Map<String, dynamic>;

      debugPrint('✅ Appointments fetched successfully');
      debugPrint('Count: ${data['count']}');
      debugPrint('Raw appointments data: ${data['appointments']}');

      final List<AppointmentDetail> appointments = [];
      if (data['appointments'] != null) {
        for (var appointmentJson in data['appointments']) {
          try {
            debugPrint('📝 Parsing appointment: $appointmentJson');
            appointments.add(AppointmentDetail.fromJson(appointmentJson));
          } catch (e) {
            debugPrint('⚠️ Error parsing appointment: $e');
            debugPrint('Appointment data: $appointmentJson');
          }
        }
      }

      debugPrint('✅ Successfully parsed ${appointments.length} appointments');

      return {
        'success': true,
        'appointments': appointments,
        'count': data['count'] ?? 0,
      };
    } on DioException catch (e) {
      debugPrint('❌ Get appointments error: ${e.message}');
      debugPrint('Response data: ${e.response?.data}');

      return {
        'success': false,
        'message':
            e.response?.data['message'] ?? 'Failed to fetch appointments',
        'appointments': <AppointmentDetail>[],
      };
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred',
        'appointments': <AppointmentDetail>[],
      };
    }
  }

  Future<Map<String, dynamic>> updateAppointmentStatus({
    required String appointmentId,
    required String status,
  }) async {
    try {
      debugPrint('📝 Updating appointment status...');
      debugPrint('Appointment ID: $appointmentId');
      debugPrint('New Status: $status');

      final response = await _apiService.put('/appointments/update_status', {
        'appointmentId': appointmentId,
        'status': status,
      });

      debugPrint('✅ Status updated successfully');

      final data = response.data as Map<String, dynamic>;

      return {
        'success': true,
        'message': data['message'] ?? 'Status updated successfully',
      };
    } on DioException catch (e) {
      debugPrint('❌ Update status error: ${e.message}');

      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to update status',
      };
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  Future<void> rateAppointment({
    required String appointmentId,
    required int rating,
    required String comment,
  }) async {
    try {
      await _apiService.post('/appointments/$appointmentId/rate', {
        'rating': rating,
        'comment': comment,
      });
    } catch (e) {
      debugPrint('❌ Rate appointment error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getDoctorProfile(String doctorId) async {
    try {
      final response = await _apiService.get('/doctors/$doctorId');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) return data['doctor'] as Map<String, dynamic>?;
      return null;
    } catch (e) {
      debugPrint('❌ Get doctor profile error: $e');
      return null;
    }
  }
}
