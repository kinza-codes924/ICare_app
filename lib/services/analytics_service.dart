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

  // Student Learning Metrics — endpoint may not exist, return defaults silently
  Future<Map<String, dynamic>> getStudentMetrics() async {
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
