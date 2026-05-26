import 'package:dio/dio.dart';
import '../utils/shared_pref.dart';
import 'api_service.dart';
import 'api_config.dart';
import 'fcm_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();
  final SharedPref _sharedPref = SharedPref();

  // Hostinger backend expects: Patient, Doctor, Pharmacy, Laboratory etc
  String _capitalizeRole(String role) {
    if (role.isEmpty) return role;
    return role[0].toUpperCase() + role.substring(1).toLowerCase();
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phoneNumber,
    String? gender,
    String? dateOfBirth,
  }) async {
    try {
      Response? response;
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          final body = <String, dynamic>{
            'name': name,
            'username': name,
            'email': email,
            'password': password,
            'role': _capitalizeRole(role),
            'phone': phoneNumber ?? '',
          };
          if (gender != null) body['gender'] = gender;
          if (dateOfBirth != null) body['dateOfBirth'] = dateOfBirth;
          response = await _apiService.post(ApiConfig.register, body);
          break;
        } on DioException catch (e) {
          if (attempt == 3 || !_isNetworkError(e)) rethrow;
          await Future.delayed(const Duration(seconds: 5));
        }
      }

      final res = response!;
      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        final token = data['token']?.toString() ??
            data['data']?['token']?.toString() ?? '';
        if (token.isNotEmpty) await _saveToken(token);
        return {
          'success': true,
          'data': data,
          'message': data['message'] ?? 'Registration successful',
        };
      }
      final msg = (res.data as Map?)?['message']?.toString() ?? 'Registration failed';
      return {'success': false, 'message': msg};
    } on DioException catch (e) {
      return {'success': false, 'message': _friendlyError(e)};
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      Response? response;
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          response = await _apiService.post(
            ApiConfig.login,
            {'email': email, 'password': password},
          );
          break;
        } on DioException catch (e) {
          if (attempt == 3 || !_isNetworkError(e)) rethrow;
          await Future.delayed(const Duration(seconds: 5));
        }
      }

      final res = response!;
      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        // Hostinger returns token at top level, Vercel inside data
        final inner = data['data'] ?? data;
        final token = inner['token']?.toString() ?? data['token']?.toString() ?? '';
        if (token.isEmpty) {
          return {'success': false, 'message': 'No token received from server'};
        }
        await _saveToken(token);
        FcmService().getAndSaveToken();
        return {
          'success': true,
          'data': inner is Map ? inner : data,
          'message': data['message'] ?? 'Login successful',
        };
      }
      final msg = (res.data as Map?)?['message']?.toString() ?? 'Login failed (${res.statusCode})';
      return {'success': false, 'message': msg};
    } on DioException catch (e) {
      return {'success': false, 'message': _friendlyError(e)};
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  String _friendlyError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
        return 'Connection timed out. Please try again.';
      case DioExceptionType.receiveTimeout:
        return 'Server took too long to respond. Please try again.';
      case DioExceptionType.connectionError:
        return 'Cannot reach server. Please check your internet connection.';
      default:
        final msg = (e.response?.data as Map?)?['message']?.toString();
        return msg ?? 'Network error. Please try again.';
    }
  }

  bool _isNetworkError(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.response == null;
  }

  Future<void> _saveToken(String token) async {
    await _sharedPref.setToken(token.trim());
  }

  Future<String?> getToken() async {
    final token = await _sharedPref.getToken();
    return token?.trim();
  }

  Future<void> logout() async {
    await _sharedPref.remove('token');
    await _sharedPref.remove('userData');
    await _sharedPref.remove('userRole');
  }

  Future<Map<String, dynamic>> forgotPassword({required String email}) async {
    try {
      final response = await _apiService.post(ApiConfig.forgetPassword, {'email': email});
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'OTP sent to your email', 'otp': response.data['otp']};
      }
      return {'success': false, 'message': 'Failed to send OTP'};
    } on DioException catch (e) {
      return {'success': false, 'message': _friendlyError(e)};
    } catch (_) {
      return {'success': false, 'message': 'Unexpected error. Please try again.'};
    }
  }

  Future<Map<String, dynamic>> verifyOTP({required String email, required String code}) async {
    try {
      final response = await _apiService.post(ApiConfig.checkOTP, {'email': email, 'code': code});
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'OTP verified successfully'};
      }
      return {'success': false, 'message': 'Invalid OTP'};
    } on DioException catch (e) {
      return {'success': false, 'message': _friendlyError(e)};
    } catch (_) {
      return {'success': false, 'message': 'Unexpected error. Please try again.'};
    }
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      final response = await _apiService.post(ApiConfig.resetPassword, {
        'email': email,
        'password': password,
        'confirmpassword': confirmPassword,
      });
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Password reset successfully'};
      }
      return {'success': false, 'message': 'Failed to reset password'};
    } on DioException catch (e) {
      return {'success': false, 'message': _friendlyError(e)};
    } catch (_) {
      return {'success': false, 'message': 'Unexpected error. Please try again.'};
    }
  }

  // Email verification
  Future<Map<String, dynamic>> verifyEmail(String token) async {
    try {
      final response = await _apiService.post(
        '${ApiConfig.baseUrl}/auth/verify-email',
        {'token': token},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? 'Email verified successfully',
          'data': data['user'],
        };
      }

      return {
        'success': false,
        'message': (response.data as Map?)?['message'] ?? 'Verification failed',
      };
    } on DioException catch (e) {
      return {'success': false, 'message': _friendlyError(e)};
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Resend verification email
  Future<Map<String, dynamic>> resendVerificationEmail(String email) async {
    try {
      final response = await _apiService.post(
        '${ApiConfig.baseUrl}/auth/resend-verification',
        {'email': email},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? 'Verification email sent',
        };
      }

      return {
        'success': false,
        'message': (response.data as Map?)?['message'] ?? 'Failed to send email',
      };
    } on DioException catch (e) {
      return {'success': false, 'message': _friendlyError(e)};
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }
}
