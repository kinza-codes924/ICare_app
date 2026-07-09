import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'api_service.dart';
import '../models/referral.dart';

class ReferralService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> createReferral(Map<String, dynamic> data) async {
    try {
      debugPrint('🔄 Creating referral...');
      final response = await _apiService.post('/clinical/referrals', data);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'referral': Referral.fromJson(response.data['referral']),
        };
      }
      return {'success': false, 'message': 'Failed to create referral'};
    } on DioException catch (e) {
      debugPrint('❌ Error: ${e.response?.data}');
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Network error',
      };
    }
  }

  Future<Map<String, dynamic>> getMyReferrals() async {
    try {
      debugPrint('📋 Fetching my referrals...');
      final response = await _apiService.get('/clinical/referrals/my');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['referrals'];
        final referrals = data.map((r) => Referral.fromJson(r)).toList();
        return {'success': true, 'referrals': referrals};
      }
      return {'success': false, 'message': 'Failed to fetch referrals'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Network error',
      };
    }
  }

  Future<Map<String, dynamic>> getReceivedReferrals() async {
    try {
      debugPrint('📋 Fetching received referrals...');
      final response = await _apiService.get('/clinical/referrals/received');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['referrals'];
        final referrals = data.map((r) => Referral.fromJson(r)).toList();
        return {'success': true, 'referrals': referrals};
      }
      return {'success': false, 'message': 'Failed to fetch referrals'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Network error',
      };
    }
  }

  Future<Map<String, dynamic>> acceptReferral(String referralId) async {
    try {
      final response = await _apiService.put(
        '/clinical/referrals/$referralId/accept',
        {},
      );

      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {'success': false, 'message': 'Failed to accept referral'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Network error',
      };
    }
  }

  Future<Map<String, dynamic>> declineReferral(
    String referralId,
    String reason,
  ) async {
    try {
      final response = await _apiService.put(
        '/clinical/referrals/$referralId/decline',
        {'reason': reason},
      );

      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {'success': false, 'message': 'Failed to decline referral'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Network error',
      };
    }
  }

  Future<Map<String, dynamic>> completeReferral(
    String referralId,
    String summary,
  ) async {
    try {
      final response = await _apiService.put(
        '/clinical/referrals/$referralId/complete',
        {'consultationSummary': summary},
      );

      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {'success': false, 'message': 'Failed to complete referral'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Network error',
      };
    }
  }
}
