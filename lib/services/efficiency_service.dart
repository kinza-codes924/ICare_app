import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:icare/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EfficiencyService {
  final ApiService _apiService = ApiService();
  static const String _templatesKey = 'prescription_templates_local';

  // Prescription Templates — stored locally (backend endpoint not available)
  Future<List<dynamic>> getPrescriptionTemplates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_templatesKey);
      if (raw == null) return [];
      return List<dynamic>.from(jsonDecode(raw));
    } catch (e) {
      debugPrint('❌ getPrescriptionTemplates error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createPrescriptionTemplate(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await getPrescriptionTemplates();
      final newTemplate = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': data['name'],
        'drugs': data['drugs'],
      };
      existing.add(newTemplate);
      await prefs.setString(_templatesKey, jsonEncode(existing));
      debugPrint('✅ Template saved locally: ${data['name']}');
      return {'success': true};
    } catch (e) {
      debugPrint('❌ createPrescriptionTemplate error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updatePrescriptionTemplate(
    String templateId,
    Map<String, dynamic> data,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await getPrescriptionTemplates();
      final idx = existing.indexWhere((t) => t['id'] == templateId);
      if (idx != -1) {
        existing[idx] = {'id': templateId, ...data};
        await prefs.setString(_templatesKey, jsonEncode(existing));
      }
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deletePrescriptionTemplate(String templateId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await getPrescriptionTemplates();
      existing.removeWhere((t) => t['id'] == templateId);
      await prefs.setString(_templatesKey, jsonEncode(existing));
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Advanced Availability
  Future<void> updateAvailability(Map<String, dynamic> data) async {
    await _apiService.post('/efficiency/availability', data);
  }

  Future<Map<String, dynamic>> getAvailability() async {
    final response = await _apiService.get('/efficiency/availability');
    return response.data['availability'] ?? {};
  }

  // Drug Interaction Check
  Future<Map<String, dynamic>> checkDrugInteractions(
    List<String> drugIds,
  ) async {
    final response = await _apiService.post(
      '/efficiency/drug-interaction-check',
      {'drugIds': drugIds},
    );
    return response.data['results'] ?? {};
  }
}
