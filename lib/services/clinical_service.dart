import 'package:flutter/foundation.dart';
import 'package:icare/services/api_service.dart';

class ClinicalService {
  final ApiService _apiService = ApiService();

  // Intake Notes
  Future<void> saveIntakeNotes(
    String appointmentId,
    Map<String, dynamic> notes,
  ) async {
    await _apiService.post('/clinical/intake-notes/$appointmentId', notes);
  }

  Future<Map<String, dynamic>?> getIntakeNotes(String appointmentId) async {
    try {
      final response = await _apiService.get(
        '/clinical/intake-notes/$appointmentId',
      );
      return response.data['notes'];
    } catch (e) {
      return null;
    }
  }

  // SOAP Notes
  Future<void> saveSoapNotes(
    String appointmentId,
    Map<String, dynamic> notes,
  ) async {
    await _apiService.post('/clinical/soap-notes/$appointmentId', notes);
  }

  Future<Map<String, dynamic>> getSoapNotes(String appointmentId) async {
    try {
      final response = await _apiService.get(
        '/clinical/soap-notes/$appointmentId',
      );
      return response.data;
    } catch (e) {
      debugPrint('Error getting SOAP notes: $e');
      // If notes don't exist yet (404), return empty notes structure
      if (e.toString().contains('404')) {
        return {
          'subjective': '',
          'objective': '',
          'assessment': '',
          'plan': '',
        };
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getPatientHistory(String patientId) async {
    try {
      final response = await _apiService.get(
        '/doctors/patients/$patientId/history',
      );
      return response.data;
    } catch (e) {
      debugPrint('Error getting patient history: $e');
      rethrow;
    }
  }

  Future<void> addAddendum(
    String appointmentId,
    String type,
    String text,
  ) async {
    try {
      await _apiService.post('/clinical/addendum/$type/$appointmentId', {
        'text': text,
      });
    } catch (e) {
      debugPrint('Error adding addendum: $e');
      rethrow;
    }
  }

  // Referrals
  Future<Map<String, dynamic>> createReferral(
    Map<String, dynamic> referralData,
  ) async {
    try {
      final response = await _apiService.post(
        '/clinical/referrals',
        referralData,
      );
      return response.data;
    } catch (e) {
      debugPrint('Error creating referral: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<dynamic>> getMyReferrals() async {
    try {
      final response = await _apiService.get('/clinical/referrals/sent');
      if (response.data['success'] == true) {
        return response.data['referrals'] as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint('Error getting my referrals: $e');
      return [];
    }
  }

  Future<List<dynamic>> getReceivedReferrals() async {
    try {
      final response = await _apiService.get('/clinical/referrals/received');
      if (response.data['success'] == true) {
        return response.data['referrals'] as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint('Error getting received referrals: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> acceptReferral(String referralId) async {
    try {
      final response = await _apiService.post(
        '/clinical/referrals/$referralId/accept',
        {},
      );
      return response.data;
    } catch (e) {
      debugPrint('Error accepting referral: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> declineReferral(
    String referralId,
    String reason,
  ) async {
    try {
      final response = await _apiService.post(
        '/clinical/referrals/$referralId/decline',
        {'reason': reason},
      );
      return response.data;
    } catch (e) {
      debugPrint('Error declining referral: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Health Journey (Timeline)
  Future<List<dynamic>> getHealthJourney() async {
    try {
      final response = await _apiService.get('/clinical/health-journey');
      return response.data['timeline'] ?? [];
    } catch (e) {
      return [];
    }
  }

  // Lifestyle Tracker
  Future<void> logLifestyleActivity(Map<String, dynamic> activity) async {
    await _apiService.post('/clinical/lifestyle-logs', activity);
  }

  Future<Map<String, dynamic>> getLifestyleSummary() async {
    try {
      final response = await _apiService.get('/clinical/lifestyle-summary');
      return response.data['summary'] ?? {};
    } catch (e) {
      return {};
    }
  }
}
