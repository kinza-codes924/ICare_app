import 'package:flutter/foundation.dart';
import 'package:icare/services/api_service.dart';

class SubscriptionService {
  final ApiService _apiService = ApiService();

  Future<List<dynamic>> getPlans() async {
    try {
      final response = await _apiService.get('/subscriptions/plans');
      if (response.data['success'] == true) {
        return response.data['plans'] as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint('Error getting plans: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getMySubscription() async {
    try {
      final response = await _apiService.get('/subscriptions/my-subscription');
      if (response.data['success'] == true) {
        return response.data['subscription'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting subscription: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> subscribe({
    required String planId,
    required String paymentMethod,
    required String transactionId,
  }) async {
    try {
      final response = await _apiService.post('/subscriptions/subscribe', {
        'planId': planId,
        'paymentMethod': paymentMethod,
        'transactionId': transactionId,
      });
      return response.data;
    } catch (e) {
      debugPrint('Error subscribing: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> cancelSubscription({String? reason}) async {
    try {
      final response = await _apiService.post('/subscriptions/cancel', {
        'reason': reason,
      });
      return response.data;
    } catch (e) {
      debugPrint('Error cancelling subscription: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
}
