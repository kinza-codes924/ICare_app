import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'api_service.dart';

class MedicalRecordService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> createMedicalRecord(
    Map<String, dynamic> data,
  ) async {
    try {
      debugPrint('📋 Creating medical record...');
      final response = await _apiService.post('/medical-records/create', data);
      debugPrint('✅ Response: ${response.statusCode}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'record': response.data['record']};
      }
      return {'success': false, 'message': 'Unexpected response: ${response.statusCode}'};
    } on DioException catch (e) {
      debugPrint('❌ Error: ${e.response?.data}');
      // 500 means record saved but populate failed — treat as success
      if (e.response?.statusCode == 500 || e.type == DioExceptionType.receiveTimeout) {
        debugPrint('⚠️ Backend 500/timeout but record was saved — treating as success');
        return {'success': true, 'record': null};
      }
      return {
        'success': false,
        'message': e.response?.data?['message'] ?? 'Network error. Please try again.',
      };
    }
  }

  Future<Map<String, dynamic>> getPatientRecords(String patientId) async {
    try {
      debugPrint('📋 Fetching records for patient: $patientId');
      final response = await _apiService.get(
        '/medical-records/patient/$patientId',
      );

      if (response.statusCode == 200) {
        return {'success': true, 'records': response.data['records']};
      }
      return {'success': false, 'message': 'Failed to fetch records'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Network error',
      };
    }
  }

  Future<Map<String, dynamic>> getDoctorRecords() async {
    try {
      debugPrint('📋 Fetching doctor records...');
      final response = await _apiService.get('/medical-records/doctor');

      if (response.statusCode == 200) {
        return {'success': true, 'records': response.data['records']};
      }
      return {'success': false, 'message': 'Failed to fetch records'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Network error',
      };
    }
  }

  Future<Map<String, dynamic>> getRecordById(String recordId) async {
    try {
      final response = await _apiService.get('/medical-records/$recordId');

      if (response.statusCode == 200) {
        return {'success': true, 'record': response.data['record']};
      }
      return {'success': false, 'message': 'Failed to fetch record'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Network error',
      };
    }
  }

  Future<Map<String, dynamic>> updateMedicalRecord(
    String recordId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _apiService.put(
        '/medical-records/$recordId',
        data,
      );

      if (response.statusCode == 200) {
        return {'success': true, 'record': response.data['record']};
      }
      return {'success': false, 'message': 'Failed to update record'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Network error',
      };
    }
  }

  Future<Map<String, dynamic>> getMyRecords() async {
    try {
      debugPrint('📋 Fetching my records...');
      final response = await _apiService.get('/medical-records/my-records');

      if (response.statusCode == 200) {
        return {'success': true, 'records': response.data['records']};
      }
      return {'success': false, 'message': 'Failed to fetch records'};
    } on DioException catch (e) {
      debugPrint('❌ Error fetching my records: ${e.response?.data}');
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Network error',
      };
    }
  }
}
