import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:icare/utils/api_constants.dart';
import 'package:icare/utils/shared_pref.dart';

class ReceptionService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    // plain text prevents Dio transformer from calling jsonDecode on HTML error pages
    responseType: ResponseType.plain,
  ));
  final SharedPref _sharedPref = SharedPref();

  ReceptionService() {
    _dio.interceptors.add(InterceptorsWrapper(
      onResponse: (response, handler) {
        final ct = response.headers.value('content-type') ?? '';
        if (ct.contains('text/html')) {
          return handler.reject(DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
            message: 'Backend unavailable (HTML ${response.statusCode})',
          ), true);
        }
        if (response.data is String && (response.data as String).isNotEmpty) {
          try {
            response.data = jsonDecode(response.data as String);
          } on FormatException {
            return handler.reject(DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
              message: 'Invalid JSON from server',
            ), true);
          }
        }
        handler.next(response);
      },
    ));
  }

  Future<Options> _authOptions() async {
    final token = await _sharedPref.getToken();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<Map<String, dynamic>> getMyDoctors() async {
    try {
      final response = await _dio.get('/reception/doctors', options: await _authOptions());
      final data = response.data;
      if (data is Map && data['success'] == true) {
        return {'success': true, 'doctors': data['doctors'] ?? []};
      }
      return {'success': false, 'message': data is Map ? data['message'] : 'Failed to load doctors', 'doctors': []};
    } catch (e) {
      return {'success': false, 'message': e.toString(), 'doctors': []};
    }
  }

  Future<Map<String, dynamic>> createWalkIn({
    required String doctorId,
    required String patientName,
    String? patientAge,
    String? patientGender,
    String? reason,
  }) async {
    try {
      final response = await _dio.post(
        '/reception/walkin',
        data: {
          'doctorId': doctorId,
          'patientName': patientName,
          if (patientAge != null) 'patientAge': patientAge,
          if (patientGender != null) 'patientGender': patientGender,
          if (reason != null) 'reason': reason,
        },
        options: await _authOptions(),
      );
      final data = response.data;
      if (data is Map && data['success'] == true) {
        return {'success': true, 'consultation': data['consultation']};
      }
      return {'success': false, 'message': data is Map ? data['message'] : 'Failed to create walk-in'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> addProcedure({
    required String consultationId,
    required String name,
    required double price,
  }) async {
    try {
      final response = await _dio.post(
        '/reception/consultations/$consultationId/procedures',
        data: {'name': name, 'price': price},
        options: await _authOptions(),
      );
      final data = response.data;
      if (data is Map && data['success'] == true) {
        return {'success': true, 'procedures': data['procedures'] ?? []};
      }
      return {'success': false, 'message': data is Map ? data['message'] : 'Failed to add procedure'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> removeProcedure({
    required String consultationId,
    required String procedureId,
  }) async {
    try {
      final response = await _dio.delete(
        '/reception/consultations/$consultationId/procedures/$procedureId',
        options: await _authOptions(),
      );
      final data = response.data;
      if (data is Map && data['success'] == true) {
        return {'success': true, 'procedures': data['procedures'] ?? []};
      }
      return {'success': false, 'message': data is Map ? data['message'] : 'Failed to remove procedure'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getConsultation(String consultationId) async {
    try {
      final response = await _dio.get(
        '/reception/consultations/$consultationId',
        options: await _authOptions(),
      );
      final data = response.data;
      if (data is Map && data['success'] == true) {
        return {'success': true, 'consultation': data['consultation'], 'prescription': data['prescription']};
      }
      return {'success': false, 'message': data is Map ? data['message'] : 'Failed to load consultation'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
