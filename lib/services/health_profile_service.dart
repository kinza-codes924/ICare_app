import 'package:dio/dio.dart';
import 'package:icare/utils/api_constants.dart';
import 'package:icare/utils/shared_pref.dart';

class HealthProfileService {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
  final SharedPref _sharedPref = SharedPref();

  // Get user health profile
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.get(
        '/health/profile',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  // Update profile
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> updates) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.put(
        '/health/profile',
        data: updates,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  // Add medical condition
  Future<Map<String, dynamic>> addMedicalCondition({
    required String name,
    DateTime? diagnosedDate,
    String? notes,
  }) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.post(
        '/health/profile/conditions',
        data: {
          'name': name,
          if (diagnosedDate != null) 'diagnosedDate': diagnosedDate.toIso8601String(),
          if (notes != null) 'notes': notes,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  // Update medical condition
  Future<Map<String, dynamic>> updateMedicalCondition(
    String conditionId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.put(
        '/health/profile/conditions/$conditionId',
        data: updates,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  // Delete medical condition
  Future<Map<String, dynamic>> deleteMedicalCondition(String conditionId) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.delete(
        '/health/profile/conditions/$conditionId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  // Add allergy
  Future<Map<String, dynamic>> addAllergy({
    required String allergen,
    String? type,
    String? severity,
    String? reaction,
    String? notes,
  }) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.post(
        '/health/profile/allergies',
        data: {
          'allergen': allergen,
          if (type != null) 'type': type,
          if (severity != null) 'severity': severity,
          if (reaction != null) 'reaction': reaction,
          if (notes != null) 'notes': notes,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  // Delete allergy
  Future<Map<String, dynamic>> deleteAllergy(String allergyId) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.delete(
        '/health/profile/allergies/$allergyId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  // Add medication
  Future<Map<String, dynamic>> addMedication({
    required String name,
    String? dosage,
    String? frequency,
    DateTime? startDate,
    DateTime? endDate,
    String? prescribedBy,
    String? purpose,
  }) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.post(
        '/health/profile/medications',
        data: {
          'name': name,
          if (dosage != null) 'dosage': dosage,
          if (frequency != null) 'frequency': frequency,
          if (startDate != null) 'startDate': startDate.toIso8601String(),
          if (endDate != null) 'endDate': endDate.toIso8601String(),
          if (prescribedBy != null) 'prescribedBy': prescribedBy,
          if (purpose != null) 'purpose': purpose,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  // Delete medication
  Future<Map<String, dynamic>> deleteMedication(String medicationId) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.delete(
        '/health/profile/medications/$medicationId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  // Add emergency contact
  Future<Map<String, dynamic>> addEmergencyContact({
    required String name,
    required String phone,
    required String relation,
    bool isPrimary = false,
  }) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.post(
        '/health/profile/emergency-contacts',
        data: {
          'name': name,
          'phone': phone,
          'relation': relation,
          'isPrimary': isPrimary,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  // Delete emergency contact
  Future<Map<String, dynamic>> deleteEmergencyContact(String contactId) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.delete(
        '/health/profile/emergency-contacts/$contactId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }
}
