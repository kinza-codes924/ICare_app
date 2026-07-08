import 'dart:convert';
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

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      // Plain text — we decode JSON manually in the interceptor so that a
      // Vercel 502/504 HTML error page never reaches json.decode() and never
      // throws an uncaught FormatException in the browser.
      responseType: ResponseType.plain,
      headers: {
        'Content-Type': 'application/json',
        if (!kIsWeb) 'x-platform': _detectPlatform(),
      },
    ),
  );
  final SharedPref _sharedPref = SharedPref();

  ApiService._internal() {
    _dio.interceptors.add(InterceptorsWrapper(
      onResponse: (response, handler) {
        final ct = response.headers.value('content-type') ?? '';

        // Vercel 502/504 pages arrive as text/html — reject before json.decode
        if (ct.contains('text/html')) {
          return handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
              message: 'Backend unavailable (HTML response ${response.statusCode})',
            ),
            true,
          );
        }

        // Decode the raw string body into a Dart object so every caller
        // sees response.data as Map/List exactly as before.
        if (response.data is String && (response.data as String).isNotEmpty) {
          try {
            response.data = jsonDecode(response.data as String);
          } on FormatException {
            return handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                type: DioExceptionType.badResponse,
                message: 'Invalid JSON from server',
              ),
              true,
            );
          }
        }

        handler.next(response);
      },
      onError: (error, handler) {
        // Error responses (4xx/5xx) bypass onResponse entirely in Dio, so the
        // body is still the raw JSON string from ResponseType.plain. Decode
        // it here too, otherwise every `data is Map` check on error messages
        // across the app silently fails and falls back to a generic message.
        final response = error.response;
        if (response != null && response.data is String && (response.data as String).isNotEmpty) {
          try {
            response.data = jsonDecode(response.data as String);
          } catch (_) {
            // Leave as-is (e.g. HTML error page) — callers already guard with `is Map`
          }
        }
        handler.next(error);
      },
    ));
  }

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

  void forceSetToken(String token) {
    final trimmed = token.trim();
    _dio.options.headers['Authorization'] = 'Bearer $trimmed';
  }

  Future<Response> postMultipart(
    String endpoint,
    FormData formData, {
    String? token,
  }) async {
    await _setAuthToken(providedToken: token);
    return await _dio.post(
      endpoint,
      data: formData,
      options: Options(
        headers: {'Content-Type': 'multipart/form-data'},
        responseType: ResponseType.plain,
      ),
    );
  }
}
