import 'package:dio/dio.dart';
import 'package:icare/services/api_service.dart';

class AuthVerificationService {
  final ApiService _api = ApiService();

  /// Pulls the backend's own message out of a failed request.
  ///
  /// The wrong-code path is a 400/403/429 response, not a 200 with
  /// success:false -- Dio throws on any non-2xx status before a caller ever
  /// gets to read response.data. Every method here used to do
  /// `if (data['success'] != true) throw Exception(data['message'])` AFTER
  /// awaiting the request, which is dead code for that path: the throw from
  /// Dio happens first, and its own message ("DioException [bad response]:
  /// ...") is what a wrong OTP actually surfaced -- not "Incorrect
  /// verification code". The screen still showed *something*, but not the
  /// warning a wrong code is supposed to produce, which read as the app
  /// having silently done nothing.
  String _messageFrom(DioException e, String fallback) {
    final body = e.response?.data;
    if (body is Map && body['message'] != null) {
      return body['message'].toString();
    }
    return fallback;
  }

  // ── PHONE OTP (Brevo SMS via backend) ────────────────────────────────────

  /// Sends a 6-digit OTP to [phone] via Brevo SMS.
  /// [phone] can be local format (03XXXXXXXXX) or E.164 (+923XXXXXXXXX).
  Future<void> sendPhoneOtp(String phone) async {
    try {
      final response = await _api.post('/auth/send-phone-otp', {'phone': phone.trim()});
      final data = (response.data as Map<String, dynamic>?) ?? {};
      if (data['success'] != true) {
        throw Exception(data['message'] ?? 'Failed to send SMS verification code');
      }
    } on DioException catch (e) {
      throw Exception(_messageFrom(e, 'Failed to send SMS verification code'));
    }
  }

  /// Verifies [otp] against the code stored by the backend.
  /// Backend sets isPhoneVerified = true on success.
  Future<void> confirmPhoneOtp(String otp) async {
    try {
      final response = await _api.post('/auth/verify-phone-otp', {'otp': otp.trim()});
      final data = (response.data as Map<String, dynamic>?) ?? {};
      if (data['success'] != true) {
        throw Exception(data['message'] ?? 'Incorrect verification code');
      }
    } on DioException catch (e) {
      // This is the common one: a wrong or expired code is a 400, and the
      // backend's own wording ("Incorrect verification code", "Verification
      // code has expired...") lives in e.response.data, not in a thrown
      // Exception's message -- Dio throws before this method's own check
      // ever runs.
      throw Exception(_messageFrom(e, 'Incorrect verification code'));
    }
  }

  // ── EMAIL OTP (Brevo email via backend) ──────────────────────────────────

  Future<bool> sendEmailOtp() async {
    try {
      final response = await _api.post('/auth/send-email-otp', {});
      final data = (response.data as Map<String, dynamic>?) ?? {};
      if (data['success'] == true) return true;
      throw Exception(data['message'] ?? 'Failed to send verification email');
    } on DioException catch (e) {
      throw Exception(_messageFrom(e, 'Failed to send verification email'));
    }
  }

  Future<void> confirmEmailOtp(String otp) async {
    try {
      final response = await _api.post('/auth/verify-email-otp', {'otp': otp.trim()});
      final data = (response.data as Map<String, dynamic>?) ?? {};
      if (data['success'] != true) {
        throw Exception(data['message'] ?? 'Incorrect verification code');
      }
    } on DioException catch (e) {
      throw Exception(_messageFrom(e, 'Incorrect verification code'));
    }
  }
}
