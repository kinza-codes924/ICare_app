import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// Centralized error handler for user-friendly error messages
class ErrorHandler {
  /// Convert technical errors to user-friendly messages
  static String getFriendlyMessage(dynamic error) {
    if (error is DioException) {
      return _handleDioError(error);
    } else if (error is Exception) {
      return _handleException(error);
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Get appropriate action button text
  static String getActionText(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Retry';
        case DioExceptionType.connectionError:
          return 'Check Connection';
        default:
          return 'Try Again';
      }
    }
    return 'OK';
  }

  /// Check if error is retryable
  static bool isRetryable(dynamic error) {
    if (error is DioException) {
      return error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError;
    }
    return false;
  }

  static String _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timed out. Please check your internet and try again.';

      case DioExceptionType.sendTimeout:
        return 'Request timed out. Please try again.';

      case DioExceptionType.receiveTimeout:
        return 'Server response timed out. Please try again.';

      case DioExceptionType.badResponse:
        return _handleHttpError(error.response?.statusCode);

      case DioExceptionType.cancel:
        return 'Request was cancelled.';

      case DioExceptionType.connectionError:
        return 'Unable to connect to server. Please check your internet connection.';

      case DioExceptionType.unknown:
      default:
        return 'Network error occurred. Please try again.';
    }
  }

  static String _handleHttpError(int? statusCode) {
    switch (statusCode) {
      case 400:
        return 'Invalid request. Please check your input and try again.';
      case 401:
        return 'Session expired. Please log in again.';
      case 403:
        return 'You don\'t have permission to perform this action.';
      case 404:
        return 'Requested resource not found.';
      case 409:
        return 'Conflict: This action cannot be completed.';
      case 422:
        return 'Validation failed. Please check your input.';
      case 429:
        return 'Too many requests. Please wait a moment and try again.';
      case 500:
        return 'Server error. Our team has been notified. Please try again later.';
      case 502:
      case 503:
        return 'Service temporarily unavailable. Please try again later.';
      default:
        return 'Request failed with status code: $statusCode';
    }
  }

  static String _handleException(Exception error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('timeout')) {
      return 'Operation timed out. Please try again.';
    } else if (errorString.contains('network') ||
        errorString.contains('connection')) {
      return 'Network error. Please check your connection.';
    } else if (errorString.contains('permission') ||
        errorString.contains('access')) {
      return 'Permission denied. Please check your access rights.';
    } else if (errorString.contains('not found')) {
      return 'Resource not found.';
    } else {
      return 'An error occurred. Please try again.';
    }
  }

  /// Show error snackbar with Dismiss always + optional Retry
  static void showSnackBar(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
  }) {
    final message = getFriendlyMessage(error);
    final canRetry = onRetry != null || isRetryable(error);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13, color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 6),
        // Always show Dismiss; show Retry only when applicable
        action: SnackBarAction(
          label: canRetry ? 'Retry' : 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            if (canRetry && onRetry != null) onRetry();
          },
        ),
      ),
    );
  }

  /// Log error for debugging (send to analytics/crash reporting)
  static void logError(
    dynamic error,
    StackTrace stackTrace, {
    String? context,
  }) {
    // TODO: Integrate with crash reporting service (Sentry, Firebase Crashlytics, etc.)
    print('ERROR LOG:');
    print('Context: ${context ?? "Unknown"}');
    print('Error: $error');
    print('StackTrace: $stackTrace');
    print('---');
  }
}
