import 'package:flutter/material.dart';

/// Error Handling Service
///
/// Provides user-friendly error messages instead of raw technical errors
/// Centralizes error handling across the virtual hospital ecosystem
class ErrorHandlingService {
  static final ErrorHandlingService _instance = ErrorHandlingService._internal();
  factory ErrorHandlingService() => _instance;
  ErrorHandlingService._internal();

  /// Convert technical errors to user-friendly messages
  String getUserFriendlyMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Network errors
    if (errorString.contains('socket') || errorString.contains('network')) {
      return 'Unable to connect. Please check your internet connection and try again.';
    }

    // Timeout errors
    if (errorString.contains('timeout')) {
      return 'The request took too long. Please try again.';
    }

    // Authentication errors
    if (errorString.contains('unauthorized') || errorString.contains('401')) {
      return 'Your session has expired. Please log in again.';
    }

    if (errorString.contains('forbidden') || errorString.contains('403')) {
      return 'You don\'t have permission to perform this action.';
    }

    // Validation errors
    if (errorString.contains('validation') || errorString.contains('invalid')) {
      return 'Please check your input and try again.';
    }

    // Server errors
    if (errorString.contains('500') || errorString.contains('server error')) {
      return 'Something went wrong on our end. Our team has been notified.';
    }

    // Not found errors
    if (errorString.contains('404') || errorString.contains('not found')) {
      return 'The requested information could not be found.';
    }

    // Database errors
    if (errorString.contains('database') || errorString.contains('query')) {
      return 'Unable to retrieve data. Please try again later.';
    }

    // File upload errors
    if (errorString.contains('upload') || errorString.contains('file')) {
      return 'Unable to upload file. Please check the file size and format.';
    }

    // Payment errors
    if (errorString.contains('payment') || errorString.contains('transaction')) {
      return 'Payment processing failed. Please check your payment details.';
    }

    // Default message
    return 'Something went wrong. Please try again or contact support if the problem persists.';
  }

  /// Show error snackbar with user-friendly message
  void showErrorSnackbar(BuildContext context, dynamic error) {
    final message = getUserFriendlyMessage(error);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show success snackbar
  void showSuccessSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show info snackbar
  void showInfoSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF3B82F6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show warning snackbar
  void showWarningSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFF59E0B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show error dialog with retry option
  void showErrorDialog(
    BuildContext context, {
    required String title,
    required dynamic error,
    VoidCallback? onRetry,
  }) {
    final message = getUserFriendlyMessage(error);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.error_outline, color: Color(0xFFEF4444)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          if (onRetry != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                onRetry();
              },
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  /// Get error icon based on error type
  IconData getErrorIcon(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') || errorString.contains('socket')) {
      return Icons.wifi_off;
    }
    if (errorString.contains('unauthorized') || errorString.contains('forbidden')) {
      return Icons.lock;
    }
    if (errorString.contains('not found')) {
      return Icons.search_off;
    }
    if (errorString.contains('timeout')) {
      return Icons.access_time;
    }

    return Icons.error_outline;
  }

  /// Get error color based on severity
  Color getErrorColor(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('warning')) {
      return const Color(0xFFF59E0B);
    }
    if (errorString.contains('info')) {
      return const Color(0xFF3B82F6);
    }

    return const Color(0xFFEF4444);
  }
}

/// Healthcare-specific error messages
class HealthcareErrorMessages {
  // Consultation errors
  static const String consultationNotFound = 'Consultation record not found. Please contact support.';
  static const String consultationSaveFailed = 'Unable to save consultation. Please try again.';
  static const String consultationLoadFailed = 'Unable to load consultation details.';

  // Prescription errors
  static const String prescriptionNotFound = 'Prescription not found.';
  static const String prescriptionSendFailed = 'Unable to send prescription to pharmacy. Please try again.';
  static const String pharmacyNotAvailable = 'No pharmacies available at the moment. Please try again later.';

  // Lab test errors
  static const String labTestNotFound = 'Lab test request not found.';
  static const String labTestSendFailed = 'Unable to send lab test request. Please try again.';
  static const String labNotAvailable = 'No laboratories available at the moment. Please try again later.';
  static const String labReportUploadFailed = 'Unable to upload lab report. Please check the file and try again.';

  // Appointment errors
  static const String appointmentNotFound = 'Appointment not found.';
  static const String appointmentBookFailed = 'Unable to book appointment. Please try again.';
  static const String appointmentCancelFailed = 'Unable to cancel appointment. Please contact support.';
  static const String noAvailableSlots = 'No available appointment slots. Please try a different date.';

  // Health program errors
  static const String programNotFound = 'Health program not found.';
  static const String programEnrollFailed = 'Unable to enroll in program. Please try again.';
  static const String programAccessDenied = 'You don\'t have access to this program. Please contact your doctor.';

  // Referral errors
  static const String referralNotFound = 'Referral not found.';
  static const String referralCreateFailed = 'Unable to create referral. Please try again.';
  static const String specialistNotAvailable = 'No specialists available for this referral.';

  // Payment errors
  static const String paymentFailed = 'Payment processing failed. Please check your payment details.';
  static const String subscriptionUpdateFailed = 'Unable to update subscription. Please try again.';
  static const String insufficientBalance = 'Insufficient balance. Please add funds to your account.';

  // Medical record errors
  static const String recordNotFound = 'Medical record not found.';
  static const String recordAccessDenied = 'You don\'t have permission to access this record.';
  static const String recordUpdateFailed = 'Unable to update medical record. Please try again.';

  // Authentication errors
  static const String sessionExpired = 'Your session has expired. Please log in again.';
  static const String invalidCredentials = 'Invalid email or password. Please try again.';
  static const String accountLocked = 'Your account has been locked due to multiple failed login attempts. Please contact support.';
  static const String emailNotVerified = 'Please verify your email address before continuing.';
  static const String twoFactorRequired = 'Two-factor authentication is required. Please enter your verification code.';

  // Validation errors
  static const String invalidEmail = 'Please enter a valid email address.';
  static const String invalidPhone = 'Please enter a valid phone number.';
  static const String passwordTooWeak = 'Password must be at least 8 characters with uppercase, lowercase, and numbers.';
  static const String requiredFieldMissing = 'Please fill in all required fields.';
  static const String invalidDate = 'Please enter a valid date.';
  static const String invalidFileFormat = 'Invalid file format. Please upload a supported file type.';
  static const String fileTooLarge = 'File size exceeds the maximum limit. Please upload a smaller file.';
}
