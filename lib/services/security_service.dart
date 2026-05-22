import 'package:icare/services/api_service.dart';

class SecurityService {
  final ApiService _apiService = ApiService();

  // 2FA Management
  Future<Map<String, dynamic>> enable2FA() async {
    final response = await _apiService.post('/security/2fa/enable', {});
    return response.data; // Should return QR code URL or secret
  }

  Future<void> disable2FA() async {
    await _apiService.post('/security/2fa/disable', {});
  }

  Future<bool> verify2FA(String code) async {
    try {
      final response = await _apiService.post('/security/2fa/verify', {
        'code': code,
      });
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Biometrics
  Future<void> updateBiometricPreference(bool enabled) async {
    await _apiService.put('/security/biometrics', {'enabled': enabled});
  }

  // Security Audit Logs (Admin only)
  Future<List<dynamic>> getSecurityLogs() async {
    try {
      final response = await _apiService.get('/security/audit-logs');
      return response.data['logs'] ?? [];
    } catch (e) {
      return [];
    }
  }

  // Data Consent
  Future<void> updateDataConsent(bool consented) async {
    await _apiService.post('/security/data-consent', {'consented': consented});
  }
}
