import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../utils/shared_pref.dart';
import 'api_config.dart';

String _detectPlatform() {
  if (kIsWeb) return 'web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.android: return 'android';
    case TargetPlatform.iOS: return 'ios';
    default: return 'unknown';
  }
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        // Only send x-platform on native mobile — web doesn't need it and it triggers CORS preflight
        if (!kIsWeb) 'x-platform': _detectPlatform(),
      },
    ),
  );
  final SharedPref _sharedPref = SharedPref();

  Future<void> _setAuthToken({String? providedToken}) async {
    String? token = providedToken ?? await _sharedPref.getToken();
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer ${token.trim()}';
    }
  }

  Future<Response> post(
    String endpoint,
    Map<String, dynamic> data, {
    String? token,
  }) async {
    await _setAuthToken(providedToken: token);
    return await _dio.post(endpoint, data: data);
  }

  Future<Response> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    String? token,
  }) async {
    await _setAuthToken(providedToken: token);
    return await _dio.get(endpoint, queryParameters: queryParameters);
  }

  Future<Response> put(
    String endpoint,
    Map<String, dynamic> data, {
    String? token,
  }) async {
    await _setAuthToken(providedToken: token);
    return await _dio.put(endpoint, data: data);
  }

  Future<Response> delete(String endpoint, {String? token}) async {
    await _setAuthToken(providedToken: token);
    return await _dio.delete(endpoint);
  }

  /// Force-set the Authorization header immediately (without reading SharedPref).
  /// Call this right after a successful login/signup to ensure the next
  /// API requests are authenticated without a SharedPref read delay.
  void forceSetToken(String token) {
    final trimmed = token.trim();
    _dio.options.headers['Authorization'] = 'Bearer $trimmed';
  }

  // Support for file uploads
  Future<Response> postMultipart(
    String endpoint,
    FormData formData, {
    String? token,
  }) async {
    await _setAuthToken(providedToken: token);
    return await _dio.post(
      endpoint,
      data: formData,
      options: Options(headers: {'Content-Type': 'multipart/form-data'}),
    );
  }
}
