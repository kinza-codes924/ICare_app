import 'api_service.dart';
import '../utils/error_handler.dart';

class LabAnalyticsService {
  static final ApiService _apiService = ApiService();

  /// Get comprehensive lab analytics
  Future<Map<String, dynamic>> getComprehensiveAnalytics({
    required String labId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await _apiService
          .post('/laboratories/$labId/analytics/comprehensive', {
            'startDate': startDate.toIso8601String(),
            'endDate': endDate.toIso8601String(),
          });
      return response.data['analytics'];
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        e,
        stackTrace,
        context: 'getComprehensiveAnalytics',
      );
      rethrow;
    }
  }

  /// Get average processing time (request to completion)
  Future<Map<String, dynamic>> getProcessingTimeMetrics(String labId) async {
    try {
      final response = await _apiService.get(
        '/laboratories/$labId/analytics/processing-time',
      );
      return response.data['metrics'];
      // Returns: {
      //   'averageHours': 24.5,
      //   'medianHours': 18.0,
      //   'fastest': 4.0,
      //   'slowest': 72.0,
      //   'withinSLA': 85.5 // percentage
      // }
    } catch (e, stackTrace) {
      ErrorHandler.logError(e, stackTrace, context: 'getProcessingTimeMetrics');
      rethrow;
    }
  }

  /// Get error and rejection rates
  Future<Map<String, dynamic>> getQualityMetrics(String labId) async {
    try {
      final response = await _apiService.get(
        '/laboratories/$labId/analytics/quality',
      );
      return response.data['metrics'];
      // Returns: {
      //   'errorRate': 2.5, // percentage
      //   'rejectionRate': 1.8,
      //   'totalErrors': 15,
      //   'totalRejections': 10,
      //   'commonErrors': [...]
      // }
    } catch (e, stackTrace) {
      ErrorHandler.logError(e, stackTrace, context: 'getQualityMetrics');
      rethrow;
    }
  }

  /// Get tests per day/week/month trends
  Future<List<Map<String, dynamic>>> getVolumeTrends({
    required String labId,
    required String period, // 'day', 'week', 'month'
    required int days,
  }) async {
    try {
      final response = await _apiService.get(
        '/laboratories/$labId/analytics/volume?period=$period&days=$days',
      );
      return List<Map<String, dynamic>>.from(response.data['trends'] ?? []);
    } catch (e, stackTrace) {
      ErrorHandler.logError(e, stackTrace, context: 'getVolumeTrends');
      rethrow;
    }
  }

  /// Get revenue breakdown by test type
  Future<Map<String, dynamic>> getRevenueAnalytics({
    required String labId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await _apiService
          .post('/laboratories/$labId/analytics/revenue', {
            'startDate': startDate.toIso8601String(),
            'endDate': endDate.toIso8601String(),
          });
      return response.data['revenue'];
      // Returns: {
      //   'totalRevenue': 125000,
      //   'byTestType': [...],
      //   'averagePerTest': 2500,
      //   'growth': 12.5 // percentage
      // }
    } catch (e, stackTrace) {
      ErrorHandler.logError(e, stackTrace, context: 'getRevenueAnalytics');
      rethrow;
    }
  }

  /// Get urgent cases statistics
  Future<Map<String, dynamic>> getUrgentCasesStats(String labId) async {
    try {
      final response = await _apiService.get(
        '/laboratories/$labId/analytics/urgent-cases',
      );
      return response.data['stats'];
      // Returns: {
      //   'totalUrgent': 45,
      //   'completedOnTime': 40,
      //   'averageResponseMinutes': 30,
      //   'criticalAlerts': 8
      // }
    } catch (e, stackTrace) {
      ErrorHandler.logError(e, stackTrace, context: 'getUrgentCasesStats');
      rethrow;
    }
  }

  /// Get technician performance metrics
  Future<List<Map<String, dynamic>>> getTechnicianPerformance(
    String labId,
  ) async {
    try {
      final response = await _apiService.get(
        '/laboratories/$labId/analytics/technicians',
      );
      return List<Map<String, dynamic>>.from(
        response.data['performance'] ?? [],
      );
      // Returns: [{
      //   'technicianId': '...',
      //   'name': '...',
      //   'testsProcessed': 150,
      //   'accuracyRate': 98.5,
      //   'averageTime': 2.5, // hours
      //   'rating': 4.8
      // }]
    } catch (e, stackTrace) {
      ErrorHandler.logError(e, stackTrace, context: 'getTechnicianPerformance');
      rethrow;
    }
  }

  /// Get peak hours analysis
  Future<Map<String, dynamic>> getPeakHoursAnalysis(String labId) async {
    try {
      final response = await _apiService.get(
        '/laboratories/$labId/analytics/peak-hours',
      );
      return response.data['analysis'];
      // Returns: {
      //   'busiestDay': 'Monday',
      //   'busiestHour': 10, // 10 AM
      //   'quietestDay': 'Sunday',
      //   'hourlyDistribution': {...}
      // }
    } catch (e, stackTrace) {
      ErrorHandler.logError(e, stackTrace, context: 'getPeakHoursAnalysis');
      rethrow;
    }
  }

  /// Get comparative analytics (vs other labs or previous periods)
  Future<Map<String, dynamic>> getComparativeAnalytics({
    required String labId,
    required String comparisonType, // 'period' or 'labs'
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await _apiService
          .post('/laboratories/$labId/analytics/comparative', {
            'comparisonType': comparisonType,
            'startDate': startDate?.toIso8601String(),
            'endDate': endDate?.toIso8601String(),
          });
      return response.data['comparison'];
    } catch (e, stackTrace) {
      ErrorHandler.logError(e, stackTrace, context: 'getComparativeAnalytics');
      rethrow;
    }
  }
}
