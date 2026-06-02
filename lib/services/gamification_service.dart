import 'package:flutter/foundation.dart';
import 'package:icare/services/api_service.dart';

class GamificationService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> getMyStats() async {
    try {
      final response = await _apiService.get('/gamification/my-stats');
      return response.data;
    } catch (e) {
      debugPrint('Error getting gamification stats: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> awardPoints({
    required int points,
    required String reason,
  }) async {
    try {
      final response = await _apiService.post('/gamification/award-points', {
        'points': points,
        'reason': reason,
      });
      return response.data;
    } catch (e) {
      debugPrint('Error awarding points: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> logMetric() async {
    try {
      final response = await _apiService.post('/gamification/log-metric', {});
      return response.data;
    } catch (e) {
      debugPrint('Error logging metric for points: $e');
      return {'success': false};
    }
  }

  Future<Map<String, dynamic>> redeemReward(String rewardId) async {
    try {
      final response = await _apiService.post('/gamification/redeem', {'rewardId': rewardId});
      return response.data;
    } catch (e) {
      debugPrint('Error redeeming reward: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<dynamic>> getLeaderboard() async {
    try {
      final response = await _apiService.get('/gamification/leaderboard');
      if (response.data['success'] == true) {
        return response.data['leaderboard'] as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint('Error getting leaderboard: $e');
      return [];
    }
  }
}
