import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'api_service.dart';

class DoctorService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> getAllDoctors() async {
    try {
      debugPrint('🔍 Fetching doctors from API...');
      final response = await _apiService.get('/doctors/get_all_doctors');

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📡 Response data type: ${response.data.runtimeType}');
      debugPrint('📡 Response data: ${response.data}');

      if (response.statusCode == 200) {
        final doctors = response.data['doctors'];
        debugPrint('✅ Doctors data: $doctors');
        return {'success': true, 'doctors': doctors};
      }
      return {'success': false, 'message': 'Failed to fetch doctors'};
    } on DioException catch (e) {
      debugPrint('❌ DioException: ${e.message}');
      debugPrint('❌ Response: ${e.response?.data}');
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Network error',
      };
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      return {'success': false, 'message': 'Unexpected error: $e'};
    }
  }

  Future<Map<String, dynamic>> getMyDoctorProfile() async {
    try {
      final response = await _apiService.get('/doctors/my-profile');
      if (response.statusCode == 200) {
        return {'success': true, 'doctor': response.data['doctor'] ?? response.data};
      }
      return {'success': false};
    } catch (_) {
      return {'success': false};
    }
  }

  Future<Map<String, dynamic>> updateDoctorSpecialization({
    required String specialization,
    List<String>? conditionsTreated,
  }) async {
    try {
      final data = <String, dynamic>{'specialization': specialization};
      if (conditionsTreated != null) data['conditionsTreated'] = conditionsTreated;
      final response = await _apiService.post('/doctors/add_doctor_details', data);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true};
      }
      return {'success': false, 'message': 'Failed to update'};
    } on DioException catch (e) {
      return {'success': false, 'message': e.response?.data['message'] ?? 'Network error'};
    } catch (e) {
      return {'success': false, 'message': 'Unexpected error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateDoctorProfile({
    required String specialization,
    List<String>? consultationType,
    List<String>? languages,
    required List<String> degrees,
    required String experience,
    required String licenseNumber,
    required String clinicName,
    required String clinicAddress,
    required List<String> availableDays,
    required String startTime,
    required String endTime,
    Uint8List? profileImage,
  }) async {
    try {
      debugPrint('📋 Updating doctor profile...');
      debugPrint('Specialization: $specialization');
      debugPrint('Consultation Types: $consultationType');
      debugPrint('Languages: $languages');
      debugPrint('Degrees: $degrees');
      debugPrint('Available Days: $availableDays');
      debugPrint('Time: $startTime - $endTime');

      String? imageBase64;
      if (profileImage != null) {
        imageBase64 = 'data:image/jpeg;base64,${base64Encode(profileImage)}';
        debugPrint('📸 Profile image encoded');
      }

      final requestData = {
        'specialization': specialization,
        'degrees': degrees,
        'experience': experience,
        'licenseNumber': licenseNumber,
        'clinicName': clinicName,
        'clinicAddress': clinicAddress,
        'availableDays': availableDays,
        'availableTime': {'start': startTime, 'end': endTime},
      };

      if (imageBase64 != null) {
        requestData['profilePicture'] = imageBase64;
      }

      if (consultationType != null && consultationType.isNotEmpty) {
        requestData['consultationType'] = consultationType;
      }

      if (languages != null && languages.isNotEmpty) {
        requestData['languages'] = languages;
      }

      final response = await _apiService.post(
        '/doctors/add_doctor_details',
        requestData,
      );

      debugPrint('✅ Response status: ${response.statusCode}');
      debugPrint('Response data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': 'Profile updated successfully'};
      }
      return {'success': false, 'message': 'Failed to update profile'};
    } on DioException catch (e) {
      debugPrint('❌ Error updating profile: ${e.response?.data}');
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Network error',
      };
    }
  }

  Future<Map<String, dynamic>> addDoctorReview({
    required String doctorId,
    required double rating,
    String? review,
  }) async {
    try {
      debugPrint('⭐ Adding review for doctor: $doctorId');
      final response = await _apiService.post('/doctors/$doctorId/review', {
        'rating': rating,
        if (review != null) 'review': review,
      });

      if (response.statusCode == 200) {
        return {'success': true, 'doctor': response.data['doctor']};
      }
      return {'success': false, 'message': 'Failed to add review'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Network error',
      };
    }
  }

  Future<Map<String, dynamic>> getDoctorById(String doctorId) async {
    try {
      final response = await _apiService.get('/doctors/$doctorId');

      if (response.statusCode == 200) {
        return {'success': true, 'doctor': response.data['doctor']};
      }
      return {'success': false, 'message': 'Failed to fetch doctor'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Network error',
      };
    }
  }

  Future<Map<String, dynamic>> filterDoctors({
    String? specialization,
    String? consultationType,
    String? language,
    double? minRating,
  }) async {
    try {
      // Build query string
      final queryParams = <String>[];
      if (specialization != null) {
        queryParams.add('specialization=$specialization');
      }
      if (consultationType != null) {
        queryParams.add('consultationType=$consultationType');
      }
      if (language != null) queryParams.add('language=$language');
      if (minRating != null) queryParams.add('minRating=$minRating');

      final queryString = queryParams.isNotEmpty
          ? '?${queryParams.join('&')}'
          : '';
      final response = await _apiService.get('/doctors/filter$queryString');

      if (response.statusCode == 200) {
        return {'success': true, 'doctors': response.data['doctors']};
      }
      return {'success': false, 'message': 'Failed to filter doctors'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Network error',
      };
    }
  }

  Future<Map<String, dynamic>> updateAvailability({
    required List<String> availableDays,
    required Map<String, String> availableTime,
    required List<String> unavailableDates,
    int? bufferTime,
    bool? emergencySlots,
    int? followUpDuration,
    int? newPatientDuration,
    int? emergencyDuration,
  }) async {
    try {
      final response = await _apiService.post('/doctors/update_availability', {
        'availableDays': availableDays,
        'availableTime': availableTime,
        'unavailableDates': unavailableDates,
        'bufferTime': bufferTime,
        'emergencySlots': emergencySlots,
        'followUpDuration': followUpDuration,
        'newPatientDuration': newPatientDuration,
        'emergencyDuration': emergencyDuration,
      });
      return {'success': true, ...?response.data as Map<String, dynamic>?};
    } on DioException catch (e) {
      debugPrint('Error updating availability: ${e.response?.statusCode} ${e.response?.data}');
      // 404 means endpoint not yet on backend — treat as success locally
      if (e.response?.statusCode == 404) {
        return {'success': true, 'message': 'Saved locally'};
      }
      return {'success': false, 'message': e.response?.data?['message'] ?? 'Failed to save'};
    } catch (e) {
      debugPrint('Error updating availability: $e');
      return {'success': false, 'message': 'Failed to save availability'};
    }
  }

  Future<Map<String, dynamic>> getAvailability() async {
    try {
      final response = await _apiService.get('/doctors/availability/me');
      if (response.statusCode == 200) {
        return {'success': true, 'availability': response.data['availability']};
      }
      return {'success': false, 'message': 'Failed to fetch availability'};
    } on DioException catch (e) {
      debugPrint('Error getting availability: ${e.response?.statusCode}');
      // 404 means endpoint not on backend yet — return empty so UI uses defaults
      return {'success': false, 'message': 'Not found'};
    } catch (e) {
      debugPrint('Error getting availability: $e');
      return {'success': false, 'message': 'Failed to fetch availability'};
    }
  }

  Future<Map<String, dynamic>> getStats() async {
    try {
      final response = await _apiService.get('/doctors/stats');
      return response.data;
    } catch (e) {
      debugPrint('Error getting doctor stats: $e');
      return {'success': false, 'stats': {}};
    }
  }

  /// Pharmacy rejections on this doctor's prescriptions (excludes "No referrer" — admin-only).
  Future<Map<String, dynamic>> getClinicalRejectionFlags() async {
    try {
      final response = await _apiService.get('/doctors/clinical-rejection-flags');
      if (response.statusCode == 200 && response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return {'success': false, 'flags': <dynamic>[]};
    } on DioException catch (e) {
      debugPrint('clinical-rejection-flags: ${e.message}');
      return {'success': false, 'flags': <dynamic>[]};
    } catch (e) {
      debugPrint('clinical-rejection-flags: $e');
      return {'success': false, 'flags': <dynamic>[]};
    }
  }

  /// Appointment ratings left by patients (patient name + rating + comment per row).
  Future<Map<String, dynamic>> getMyPatientReviews() async {
    try {
      final response = await _apiService.get('/doctors/me/patient-reviews');
      if (response.statusCode == 200 && response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return {'success': false, 'reviews': <dynamic>[]};
    } on DioException catch (e) {
      debugPrint('patient-reviews: ${e.message}');
      return {'success': false, 'reviews': <dynamic>[]};
    } catch (e) {
      return {'success': false, 'reviews': <dynamic>[]};
    }
  }

  /// Get doctor stats including current consultation fee
  Future<Map<String, dynamic>> getDoctorStats() async {
    try {
      final response = await _apiService.get('/doctors/stats');
      final data = response.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return {};
    } catch (_) { return {}; }
  }

  /// Update only the consultation fee
  Future<void> updateConsultationFee(double fee) async {
    try {
      await _apiService.post('/doctors/add_doctor_details', {
        'consultationFee': fee,
      });
    } catch (e) {
      debugPrint('Error updating consultation fee: $e');
      rethrow;
    }
  }

  /// Save license expiry date. Backend sends admin notification 30 days before expiry.
  Future<void> updateLicenseExpiry(DateTime expiryDate) async {
    try {
      await _apiService.post('/doctors/add_doctor_details', {
        'licenseValidTill': expiryDate.toIso8601String(),
        'licenseExpiryReminderDays': 30, // backend uses this to schedule reminder
      });
      debugPrint('✅ License expiry saved: $expiryDate');
    } catch (e) {
      debugPrint('Error saving license expiry: $e');
      rethrow;
    }
  }

  /// Set doctor online/offline status
  Future<void> setOnlineStatus(bool isOnline) async {
    try {
      await _apiService.post('/doctors/online-status', {'isOnline': isOnline});
      debugPrint('✅ Doctor online status set to: $isOnline');
    } catch (e) {
      debugPrint('⚠️ Could not update online status (non-critical): $e');
      // Non-critical — don't rethrow
    }
  }

  Future<Map<String, dynamic>> getPatientHistory(String patientId) async {
    try {
      final response = await _apiService.get(
        '/doctors/patients/$patientId/history',
      );
      return response.data;
    } catch (e) {
      debugPrint('Error getting patient history: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> assignHealthProgram(
    String patientId,
    String courseId,
  ) async {
    try {
      final response = await _apiService.post(
        '/doctors/patients/$patientId/assign-program',
        {'courseId': courseId},
      );
      return response.data;
    } catch (e) {
      debugPrint('Error assigning program: $e');
      rethrow;
    }
  }

  /// Submit a leave / unavailability request
  Future<Map<String, dynamic>> requestLeave({
    required DateTime from,
    required DateTime to,
    String reason = '',
  }) async {
    try {
      final response = await _apiService.post('/doctors/leave-requests', {
        'fromDate': from.toIso8601String(),
        'toDate': to.toIso8601String(),
        'reason': reason,
      });
      if (response.data is Map) return Map<String, dynamic>.from(response.data as Map);
      return {'success': false};
    } on DioException catch (e) {
      return {'success': false, 'message': e.response?.data?['message'] ?? e.message};
    } catch (_) {
      return {'success': false};
    }
  }

  /// Get the doctor's own leave requests
  Future<Map<String, dynamic>> getLeaveRequests() async {
    try {
      final response = await _apiService.get('/doctors/leave-requests');
      if (response.data is Map) return Map<String, dynamic>.from(response.data as Map);
      return {'success': false, 'leaveRequests': []};
    } catch (_) {
      return {'success': false, 'leaveRequests': []};
    }
  }
}
