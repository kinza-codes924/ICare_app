import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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

        // 2FA: backend says OTP required — pass through without saving token
        if (data['requiresOtp'] == true) {
          return {
            'success': false,
            'requiresOtp': true,
            'tempToken': data['tempToken'],
            'emailSent': data['emailSent'],
            'message': data['message'] ?? 'Verification required',
          };
        }

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

  String _friendlyError(DioException e, {bool isSocialAuth = false}) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
        return 'Connection timed out. Please try again.';
      case DioExceptionType.receiveTimeout:
        return 'Server took too long to respond. Please try again.';
      case DioExceptionType.connectionError:
        return 'Cannot reach server. Please check your internet connection.';
      default:
        if (isSocialAuth && e.response?.statusCode == 404) {
          return 'Social sign-in is not yet enabled on this server. Please use email and password.';
        }
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
        final d = response.data as Map<String, dynamic>? ?? {};
        return {
          'success': true,
          'message': d['message'] ?? 'OTP sent',
          'emailSent': d['emailSent'] ?? false,
          'emailError': d['emailError'],
        };
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

  Future<Map<String, dynamic>> loginWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(
        clientId: '1076307742101-avj49igc93qipdcnqbqsk3u14gdcb2oh.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      );
      final account = await googleSignIn.signIn();
      if (account == null) return {'success': false, 'message': 'Sign-in cancelled'};
      final auth = await account.authentication;
      final idToken = auth.idToken;
      final accessToken = auth.accessToken;
      if (idToken == null && accessToken == null) {
        return {'success': false, 'message': 'Could not get Google token'};
      }
      final response = await _apiService.post('/auth/google', {
        if (idToken != null) 'idToken': idToken,
        if (accessToken != null) 'accessToken': accessToken,
        'email': account.email,
        'name': account.displayName ?? account.email.split('@').first,
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        final inner = data['data'] ?? data;
        final token = inner['token']?.toString() ?? data['token']?.toString() ?? '';
        if (token.isNotEmpty) {
          await _saveToken(token);
          FcmService().getAndSaveToken();
        }
        return {'success': true, 'data': inner is Map ? inner : data};
      }
      return {'success': false, 'message': (response.data as Map?)?['message'] ?? 'Google sign-in failed'};
    } on DioException catch (e) {
      return {'success': false, 'message': _friendlyError(e, isSocialAuth: true)};
    } catch (e) {
      return {'success': false, 'message': 'Google sign-in error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> loginWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: WebAuthenticationOptions(
          clientId: 'com.rmhealthsolutions.icare',
          redirectUri: Uri.parse('https://icare-backend-inky.vercel.app/api/auth/apple/callback'),
        ),
      );
      final identityToken = credential.identityToken;
      if (identityToken == null) return {'success': false, 'message': 'Could not get Apple token'};
      final name = [credential.givenName, credential.familyName]
          .where((s) => s != null && s.isNotEmpty).join(' ');
      final response = await _apiService.post('/auth/apple', {
        'identityToken': identityToken,
        'authorizationCode': credential.authorizationCode,
        'email': credential.email ?? '',
        'name': name,
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        final inner = data['data'] ?? data;
        final token = inner['token']?.toString() ?? data['token']?.toString() ?? '';
        if (token.isNotEmpty) {
          await _saveToken(token);
          FcmService().getAndSaveToken();
        }
        return {'success': true, 'data': inner is Map ? inner : data};
      }
      return {'success': false, 'message': (response.data as Map?)?['message'] ?? 'Apple sign-in failed'};
    } on DioException catch (e) {
      return {'success': false, 'message': _friendlyError(e, isSocialAuth: true)};
    } catch (e) {
      return {'success': false, 'message': 'Apple sign-in error: ${e.toString()}'};
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

  Future<Map<String, dynamic>> verify2FA({required String tempToken, required String otp}) async {
    try {
      final response = await _apiService.post('/auth/2fa/verify', {'tempToken': tempToken, 'otp': otp});
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true) {
          final inner = data['data'] as Map<String, dynamic>? ?? {};
          final token = inner['token']?.toString() ?? '';
          if (token.isNotEmpty) {
            await _saveToken(token);
            FcmService().getAndSaveToken();
          }
        }
        return data;
      }
      return {'success': false, 'message': (response.data as Map?)?['message'] ?? 'Verification failed'};
    } on DioException catch (e) {
      return {'success': false, 'message': _friendlyError(e)};
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }
}
