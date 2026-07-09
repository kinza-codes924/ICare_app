import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import '../utils/shared_pref.dart';
import '../data/icd10_codes.dart';

final _sharedPref = SharedPref();

class ICDService {
  static Future<List<dynamic>> searchICDCodes(String query) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/icd-codes/search?query=$query'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['results'] ?? [];
      } else {
        debugPrint('API returned ${response.statusCode}, using local ICD data');
        return ICD10Data.searchCodes(query);
      }
    } catch (e) {
      debugPrint('API error, using local ICD data: $e');
      return ICD10Data.searchCodes(query);
    }
  }

  static Future<List<String>> getCategories() async {
    try {
      final token = await _sharedPref.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/icd-codes/categories'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['categories'] ?? []);
      } else {
        debugPrint('API returned ${response.statusCode}, using local ICD data');
        return ICD10Data.getCategoryNames();
      }
    } catch (e) {
      debugPrint('API error, using local ICD data: $e');
      return ICD10Data.getCategoryNames();
    }
  }

  static Future<List<dynamic>> getCodesByCategory(String category) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/icd-codes/category/$category'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['codes'] ?? [];
      } else {
        debugPrint('API returned ${response.statusCode}, using local ICD data');
        return ICD10Data.getCodesByCategory(category);
      }
    } catch (e) {
      debugPrint('API error, using local ICD data: $e');
      return ICD10Data.getCodesByCategory(category);
    }
  }
}
