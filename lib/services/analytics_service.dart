import 'package:flutter/foundation.dart';
import 'package:icare/services/api_service.dart';

class AnalyticsService {
  final ApiService _apiService = ApiService();

  // Overall Platform Stats (Admin only)
  Future<Map<String, dynamic>> getPlatformStats() async {
    try {
      final response = await _apiService.get('/analytics/platform-stats');
      return response.data['stats'] ?? {};
    } catch (e) {
      return {};
    }
  }

  // Monthly Revenue & Usage Trends
  Future<List<dynamic>> getRevenueTrends() async {
    try {
      final response = await _apiService.get('/analytics/revenue-trends');
      return response.data['trends'] ?? [];
    } catch (e) {
      return [];
    }
  }

  // Geographic Distribution
  Future<List<dynamic>> getGeoDistribution() async {
    try {
      final response = await _apiService.get('/analytics/geo-distribution');
      return response.data['distribution'] ?? [];
    } catch (e) {
      return [];
    }
  }

  // Clinical Quality Metrics
  Future<Map<String, dynamic>> getClinicalQualityMetrics() async {
    try {
      final response = await _apiService.get('/analytics/clinical-quality');
      return response.data['metrics'] ?? {};
    } catch (e) {
      return {};
    }
  }

  // Data Export
  Future<String> exportReport(String reportType) async {
    final response = await _apiService.post('/analytics/export', {
      'type': reportType,
    });
    return response.data['downloadUrl'] ?? '';
  }

  // Student Learning Metrics — engagement rate, average quiz score and
  // estimated time spent, computed server-side from the student's lesson
  // completions and quiz attempts. Falls back to zeros if the call fails so
  // the dashboard still renders.
  Future<Map<String, dynamic>> getStudentMetrics() async {
    try {
      final response = await _apiService.get('/analytics/student-stats');
      final analytics = response.data['analytics'];
      if (analytics is Map) return Map<String, dynamic>.from(analytics);
    } catch (e) {
      debugPrint('Error getting student metrics: $e');
    }
    return {'engagementRate': '0%', 'avgQuizScore': '0%', 'timeSpent': '0 hrs'};
  }

  // Instructor Analytics
  Future<Map<String, dynamic>> getInstructorAnalytics() async {
    try {
      final response = await _apiService.get('/analytics/instructor-stats');
      return response.data['analytics'] ?? {};
    } catch (e) {
      return {};
    }
  }
}
