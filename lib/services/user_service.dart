import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'api_service.dart';

class UserService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> getUserProfile({String? token}) async {
    try {
      debugPrint("🌐 Calling /users/profile endpoint...");

      final response = await _apiService.get('/users/profile', token: token);

      debugPrint("📡 Response status: ${response.statusCode}");
      debugPrint("📡 Response data: ${response.data}");

      if (response.statusCode == 200) {
        final data = response.data;
        // Extract user map from various response formats:
        // 1. {success, user: {...}}  → use data['user']
        // 2. {_id, name, role, ...}  → use data directly (flat)
        Map<String, dynamic> userMap;
        if (data is Map && data['user'] is Map) {
          userMap = Map<String, dynamic>.from(data['user'] as Map);
        } else if (data is Map && (data.containsKey('_id') || data.containsKey('id'))) {
          userMap = Map<String, dynamic>.from(data);
        } else {
          debugPrint("❌ Unexpected profile response format: $data");
          return {'success': false, 'message': 'Invalid profile response'};
        }
        return {'success': true, 'user': userMap};
      }
      return {'success': false, 'message': 'Failed to fetch profile'};
    } on DioException catch (e) {
      debugPrint("❌ DioException in getUserProfile: ${e.message}");
      debugPrint("❌ Response: ${e.response?.data}");
      return {
        'success': false,
        'message': e.response?.data?['message'] ?? 'Network error',
      };
    } catch (e) {
      debugPrint("❌ Unexpected error in getUserProfile: $e");
      return {'success': false, 'message': 'Unexpected error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String phoneNumber,
    String? profilePicture,
    Uint8List? profileImage,
    String? cnic,
    String? age,
    String? gender,
    String? height,
    String? weight,
    String? address,
    String? existingConditions,
    String? healthGoals,
    List<Map<String, String>>? emergencyContacts,
  }) async {
    try {
      String? imageBase64;
      if (profileImage != null) {
        imageBase64 = 'data:image/jpeg;base64,${base64Encode(profileImage)}';
      }

      final response = await _apiService.put('/users/profile', {
        'name': name,
        'phoneNumber': phoneNumber,
        if (imageBase64 != null) 'profilePicture': imageBase64,
        if (profilePicture != null && imageBase64 == null) 'profilePicture': profilePicture,
        if (cnic != null) 'cnic': cnic,
        if (age != null) 'age': age,
        if (gender != null) 'gender': gender,
        if (height != null) 'height': height,
        if (weight != null) 'weight': weight,
        if (address != null) 'address': address,
        if (existingConditions != null) 'existingConditions': existingConditions,
        if (healthGoals != null) 'healthGoals': healthGoals,
        if (emergencyContacts != null && emergencyContacts.isNotEmpty) 'emergencyContacts': emergencyContacts,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        Map<String, dynamic> userMap;
        if (data is Map && data['user'] is Map) {
          userMap = Map<String, dynamic>.from(data['user'] as Map);
        } else if (data is Map && (data.containsKey('_id') || data.containsKey('id'))) {
          userMap = Map<String, dynamic>.from(data);
        } else {
          userMap = data is Map ? Map<String, dynamic>.from(data) : {};
        }
        return {'success': true, 'user': userMap};
      }
      return {'success': false, 'message': 'Failed to update profile'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Network error',
      };
    }
  }

  Future<Map<String, dynamic>> updateEmergencyContacts(List<Map<String, String>> contacts) async {
    try {
      final response = await _apiService.put('/users/profile', {
        'emergencyContacts': contacts,
      });
      if (response.statusCode == 200) return {'success': true};
      return {'success': false, 'message': 'Failed to update emergency contacts'};
    } on DioException catch (e) {
      return {'success': false, 'message': e.response?.data['message'] ?? 'Network error'};
    }
  }

  Future<Map<String, dynamic>> searchUsers({
    String? query,
    String? role,
  }) async {
    try {
      final response = await _apiService.get(
        '/users/search',
        queryParameters: {
          if (query != null) 'q': query,
          if (role != null) 'role': role,
        },
      );
      return response.data;
    } catch (e) {
      debugPrint('Error searching users: $e');
      rethrow;
    }
  }
}
