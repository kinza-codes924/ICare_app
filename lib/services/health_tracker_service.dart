import 'package:dio/dio.dart';
import 'package:icare/utils/api_constants.dart';
import 'package:icare/utils/shared_pref.dart';

class HealthTrackerService {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
  final SharedPref _sharedPref = SharedPref();

  // Add new vital entry
  Future<Map<String, dynamic>> addEntry({
    required String vitalType,
    required String value,
    required String unit,
    String? notes,
    DateTime? timestamp,
  }) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.post(
        '/health/tracker/entries',
        data: {
          'vitalType': vitalType,
          'value': value,
          'unit': unit,
          if (notes != null) 'notes': notes,
          if (timestamp != null) 'timestamp': timestamp.toIso8601String(),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  // Get all entries with filters
  Future<Map<String, dynamic>> getEntries({
    String? vitalType,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    try {
      final token = await _sharedPref.getToken();
      final queryParams = <String, dynamic>{
        'limit': limit,
        if (vitalType != null) 'vitalType': vitalType,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
      };

      final response = await _dio.get(
        '/health/tracker/entries',
        queryParameters: queryParams,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  // Get latest entries (one per vital type)
  Future<Map<String, dynamic>> getLatestEntries() async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.get(
        '/health/tracker/entries/latest',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  // Get entries for specific vital type
  Future<Map<String, dynamic>> getEntriesByType(String vitalType, {int days = 30}) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.get(
        '/health/tracker/entries/$vitalType',
        queryParameters: {'days': days},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  // Get summary statistics
  Future<Map<String, dynamic>> getSummary(String vitalType, {int days = 7}) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.get(
        '/health/tracker/summary',
        queryParameters: {
          'vitalType': vitalType,
          'days': days,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  // Update entry
  Future<Map<String, dynamic>> updateEntry(
    String id, {
    String? value,
    String? notes,
    DateTime? timestamp,
  }) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.put(
        '/health/tracker/entries/$id',
        data: {
          if (value != null) 'value': value,
          if (notes != null) 'notes': notes,
          if (timestamp != null) 'timestamp': timestamp.toIso8601String(),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  // Delete entry
  Future<Map<String, dynamic>> deleteEntry(String id) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.delete(
        '/health/tracker/entries/$id',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  // Get dashboard data for Health Journey
  Future<Map<String, dynamic>> getDashboard() async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.get(
        '/health/tracker/dashboard',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }
}
