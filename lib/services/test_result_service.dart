import 'api_service.dart';
import '../utils/error_handler.dart';
import 'notification_service.dart';

class TestResultService {
  static final ApiService _apiService = ApiService();

  /// Upload structured test results with auto-flagging
  Future<Map<String, dynamic>> uploadStructuredResults(
    String bookingId,
    List<Map<String, dynamic>> results,
    String? doctorId,
    String? patientId,
    String? testName,
  ) async {
    try {
      // Auto-calculate severity for each result
      final processedResults = results.map((result) {
        return _calculateSeverity(result);
      }).toList();

      // Check for critical values
      final hasCritical = processedResults.any(
        (r) => r['severity'] == 'critical',
      );

      // Get critical parameters if any
      final criticalParameters = processedResults
          .where((r) => r['severity'] == 'critical')
          .map((r) => r['testParameter'] as String)
          .toList();

      final response = await _apiService.post(
        '/laboratories/bookings/$bookingId/upload-structured-results',
        {'results': processedResults, 'criticalAlert': hasCritical},
      );

      // If critical values detected, send immediate notifications
      if (hasCritical && doctorId != null && patientId != null) {
        try {
          await NotificationService().sendCriticalAlert(
            bookingId: bookingId,
            doctorId: doctorId,
            patientId: patientId,
            testName: testName ?? 'Lab Test',
            criticalParameters: criticalParameters,
          );
        } catch (e) {
          // Log but don't fail the upload if notification fails
          ErrorHandler.logError(
            e,
            StackTrace.current,
            context: 'criticalAlertNotification',
          );
        }
      }

      return response.data;
    } catch (e, stackTrace) {
      ErrorHandler.logError(e, stackTrace, context: 'uploadStructuredResults');
      rethrow;
    }
  }

  /// Calculate severity based on reference ranges
  Map<String, dynamic> _calculateSeverity(Map<String, dynamic> result) {
    final value = double.tryParse(result['value']?.toString() ?? '0') ?? 0;
    final referenceRange = result['referenceRange'];

    if (referenceRange == null) {
      return {...result, 'severity': 'normal', 'isAbnormal': false};
    }

    final min = referenceRange['min'] as double?;
    final max = referenceRange['max'] as double?;

    bool isAbnormal = false;
    String severity = 'normal';

    if (min != null && max != null) {
      // Calculate how far outside the range
      if (value < min) {
        isAbnormal = true;
        final deviation = (min - value) / min;
        severity = _getSeverityFromDeviation(deviation);
      } else if (value > max) {
        isAbnormal = true;
        final deviation = (value - max) / max;
        severity = _getSeverityFromDeviation(deviation);
      }
    } else if (min != null && value < min) {
      isAbnormal = true;
      severity = 'low';
    } else if (max != null && value > max) {
      isAbnormal = true;
      severity = 'high';
    }

    return {...result, 'isAbnormal': isAbnormal, 'severity': severity};
  }

  /// Determine severity level based on deviation from normal range
  String _getSeverityFromDeviation(double deviation) {
    if (deviation > 0.5) {
      return 'critical'; // More than 50% outside range
    } else if (deviation > 0.25) {
      return 'abnormal'; // 25-50% outside range
    } else if (deviation > 0.1) {
      return 'borderline'; // 10-25% outside range
    } else {
      return 'borderline'; // Slightly outside range
    }
  }

  /// Get test result history for trend analysis
  Future<List<Map<String, dynamic>>> getResultHistory(
    String patientId,
    String testParameter,
  ) async {
    try {
      final response = await _apiService.get(
        '/laboratories/results/history/$patientId/$testParameter',
      );
      return List<Map<String, dynamic>>.from(response.data['results'] ?? []);
    } catch (e, stackTrace) {
      ErrorHandler.logError(e, stackTrace, context: 'getResultHistory');
      rethrow;
    }
  }

  /// Download structured results as JSON
  Future<Map<String, dynamic>> downloadStructuredResults(
    String bookingId,
  ) async {
    try {
      final response = await _apiService.get(
        '/laboratories/bookings/$bookingId/structured-results',
      );
      return response.data;
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        e,
        stackTrace,
        context: 'downloadStructuredResults',
      );
      rethrow;
    }
  }
}
