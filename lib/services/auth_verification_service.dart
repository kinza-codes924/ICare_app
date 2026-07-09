import 'package:icare/services/api_service.dart';

class AuthVerificationService {
  final ApiService _api = ApiService();

  // ── PHONE OTP (Brevo SMS via backend) ────────────────────────────────────

  /// Sends a 6-digit OTP to [phone] via Brevo SMS.
  /// [phone] can be local format (03XXXXXXXXX) or E.164 (+923XXXXXXXXX).
  Future<void> sendPhoneOtp(String phone) async {
    final response = await _api.post('/auth/send-phone-otp', {'phone': phone.trim()});
    final data = (response.data as Map<String, dynamic>?) ?? {};
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Failed to send SMS verification code');
    }
  }

  /// Verifies [otp] against the code stored by the backend.
  /// Backend sets isPhoneVerified = true on success.
  Future<void> confirmPhoneOtp(String otp) async {
    final response = await _api.post('/auth/verify-phone-otp', {'otp': otp.trim()});
    final data = (response.data as Map<String, dynamic>?) ?? {};
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Invalid verification code');
    }
  }

  // ── EMAIL OTP (Brevo email via backend) ──────────────────────────────────

  Future<bool> sendEmailOtp() async {
    final response = await _api.post('/auth/send-email-otp', {});
    final data = (response.data as Map<String, dynamic>?) ?? {};
    if (data['success'] == true) return true;
    throw Exception(data['message'] ?? 'Failed to send verification email');
  }

  Future<void> confirmEmailOtp(String otp) async {
    final response = await _api.post('/auth/verify-email-otp', {'otp': otp.trim()});
    final data = (response.data as Map<String, dynamic>?) ?? {};
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Invalid verification code');
    }
  }
}
