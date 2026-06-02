import 'package:icare/services/api_service.dart';

class SecurityService {
  final ApiService _apiService = ApiService();

  // ── 2FA via Google Authenticator (TOTP) ─────────────────────────────────

  /// Generates TOTP secret and returns {success, qrCode, manualKey}
  Future<Map<String, dynamic>> setup2FA() async {
    try {
      final response = await _apiService.post('/auth/2fa/setup', {});
      final data = response.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return {'success': response.statusCode == 200};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Verifies the OTP entered by the user, enables 2FA on success
  Future<Map<String, dynamic>> enable2FAWithOtp(String otp) async {
    try {
      final response = await _apiService.post('/auth/2fa/enable', {'otp': otp, 'code': otp});
      final data = response.data;
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        return {'success': m['success'] ?? response.statusCode == 200, ...m};
      }
      return {'success': response.statusCode == 200};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> disable2FA() async {
    try {
      final response = await _apiService.post('/auth/2fa/disable', {});
      final data = response.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return {'success': response.statusCode == 200};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<bool> verify2FA(String code) async {
    try {
      final response = await _apiService.post('/auth/2fa/verify', {'code': code, 'otp': code});
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getSecuritySettings() async {
    try {
      final response = await _apiService.get('/security/settings');
      final data = response.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return {'success': false};
    } catch (_) {
      return {'success': false};
    }
  }

  // ── Login Activity ───────────────────────────────────────────────────────

  Future<List<dynamic>> getLoginActivity() async {
    try {
      final response = await _apiService.get('/auth/sessions');
      final data = response.data;
      if (data is Map) {
        final sessions = data['sessions'] ?? data['activity'] ?? data['logs'] ?? [];
        return sessions is List ? sessions : [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> revokeSession(String sessionId) async {
    try {
      await _apiService.delete('/auth/sessions/$sessionId');
    } catch (_) {}
  }

  // ── Biometrics ────────────────────────────────────────────────────────────
  Future<void> updateBiometricPreference(bool enabled) async {
    await _apiService.put('/security/biometrics', {'enabled': enabled});
  }

  // ── Security Audit Logs (Admin only) ─────────────────────────────────────
  Future<List<dynamic>> getSecurityLogs() async {
    try {
      final response = await _apiService.get('/security/audit-logs');
      return response.data['logs'] ?? [];
    } catch (e) {
      return [];
    }
  }

  // ── Data Consent ──────────────────────────────────────────────────────────
  Future<void> updateDataConsent(bool consented) async {
    await _apiService.post('/security/data-consent', {'consented': consented});
  }
}
