import 'package:dio/dio.dart';
import 'package:icare/utils/api_constants.dart';
import 'package:icare/utils/shared_pref.dart';

class HealthSettingsService {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
  final SharedPref _sharedPref = SharedPref();

  // Get user health settings
  Future<Map<String, dynamic>> getSettings() async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.get(
        '/health/settings',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  // Update all settings
  Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> updates) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.put(
        '/health/settings',
        data: updates,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  // Toggle health mode
  Future<Map<String, dynamic>> toggleHealthMode({
    required bool enabled,
    List<String>? conditions,
  }) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.put(
        '/health/settings/health-mode',
        data: {
          'enabled': enabled,
          if (conditions != null) 'conditions': conditions,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  // Update tracker toggles
  Future<Map<String, dynamic>> updateTrackerToggles(Map<String, bool> trackedVitals) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.put(
        '/health/settings/tracker-toggles',
        data: {'trackedVitals': trackedVitals},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  // Update daily goals
  Future<Map<String, dynamic>> updateDailyGoals(Map<String, int> dailyGoals) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.put(
        '/health/settings/daily-goals',
        data: {'dailyGoals': dailyGoals},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  // Update unit preferences
  Future<Map<String, dynamic>> updateUnitPreferences(Map<String, String> unitPreferences) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.put(
        '/health/settings/unit-preferences',
        data: {'unitPreferences': unitPreferences},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  // Update reminders
  Future<Map<String, dynamic>> updateReminders(Map<String, dynamic> reminders) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.put(
        '/health/settings/reminders',
        data: {'reminders': reminders},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  // Update consultation preferences
  Future<Map<String, dynamic>> updateConsultationPreferences(Map<String, dynamic> preferences) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.put(
        '/health/settings/consultation-preferences',
        data: {'consultationPreferences': preferences},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  // Update pharmacy preferences
  Future<Map<String, dynamic>> updatePharmacyPreferences(Map<String, dynamic> preferences) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.put(
        '/health/settings/pharmacy-preferences',
        data: {'pharmacyPreferences': preferences},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  // Update lab preferences
  Future<Map<String, dynamic>> updateLabPreferences(Map<String, dynamic> preferences) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.put(
        '/health/settings/lab-preferences',
        data: {'labPreferences': preferences},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }
}
