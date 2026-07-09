import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:icare/utils/api_constants.dart';
import 'package:icare/utils/shared_pref.dart';

class ReminderService {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
  final SharedPref _sharedPref = SharedPref();

  Future<List<dynamic>> getMyReminders() async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.get(
        '/reminders',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data['reminders'] as List;
    } on DioException catch (e) {
      debugPrint('Error fetching reminders: ${e.message}');
      return [];
    }
  }

  Future<Map<String, dynamic>> createReminder(Map<String, dynamic> data) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.post(
        '/reminders',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  Future<void> deleteReminder(String id) async {
    try {
      final token = await _sharedPref.getToken();
      await _dio.delete(
        '/reminders/$id',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      debugPrint('Error deleting reminder: ${e.message}');
    }
  }

  /// Check for due reminders and trigger in-app notifications
  Future<void> checkDueReminders() async {
    try {
      final token = await _sharedPref.getToken();
      await _dio.get(
        '/reminders/check-due',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      debugPrint('Error checking due reminders: ${e.message}');
    }
  }
}
