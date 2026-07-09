import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import '../utils/shared_pref.dart';

class LifestyleService {
  static Future<Map<String, dynamic>> getTodayData() async {
    try {
      final token = await SharedPref().getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/lifestyle/today'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load lifestyle data');
      }
    } catch (e) {
      throw Exception('Error loading lifestyle data: $e');
    }
  }

  static Future<Map<String, dynamic>> updateData({
    double? waterIntake,
    double? sleepHours,
    int? steps,
    int? exercise,
    String? notes,
  }) async {
    try {
      final token = await SharedPref().getToken();
      final body = <String, dynamic>{};

      if (waterIntake != null) body['waterIntake'] = waterIntake;
      if (sleepHours != null) body['sleepHours'] = sleepHours;
      if (steps != null) body['steps'] = steps;
      if (exercise != null) body['exercise'] = exercise;
      if (notes != null) body['notes'] = notes;

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/lifestyle/update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to update lifestyle data');
      }
    } catch (e) {
      throw Exception('Error updating lifestyle data: $e');
    }
  }

  static Future<Map<String, dynamic>> getHistory({int days = 7}) async {
    try {
      final token = await SharedPref().getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/lifestyle/history?days=$days'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load history');
      }
    } catch (e) {
      throw Exception('Error loading history: $e');
    }
  }

  static Future<Map<String, dynamic>> getWeeklySummary() async {
    try {
      final token = await SharedPref().getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/lifestyle/weekly-summary'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load weekly summary');
      }
    } catch (e) {
      throw Exception('Error loading weekly summary: $e');
    }
  }
}
