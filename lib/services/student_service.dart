import 'package:flutter/foundation.dart';
import 'api_service.dart';

class StudentService {
  final ApiService _apiService = ApiService();

  // Add/Update student details
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.post(
        '/students/add_student_details',
        data,
      );
      return response.data;
    } catch (e) {
      debugPrint('Error updating student profile: $e');
      rethrow;
    }
  }

  // Get current student profile — endpoint may not exist, fail silently
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await _apiService.get('/students/me');
      return response.data ?? {};
    } catch (e) {
      return {}; // silent fail — endpoint not implemented
    }
  }

  // Get all students
  Future<List<dynamic>> getAllStudents() async {
    try {
      final response = await _apiService.get('/students/get_all_students');
      return response.data['students'];
    } catch (e) {
      debugPrint('Error getting all students: $e');
      rethrow;
    }
  }

  // Get student by ID
  Future<Map<String, dynamic>> getStudentById(String id) async {
    try {
      final response = await _apiService.get('/students/$id');
      return response.data['student'];
    } catch (e) {
      debugPrint('Error getting student by id: $e');
      rethrow;
    }
  }
}
