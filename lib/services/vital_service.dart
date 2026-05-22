import 'package:dio/dio.dart';
import 'package:icare/utils/api_constants.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/models/vital.dart';

class VitalService {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
  final SharedPref _sharedPref = SharedPref();

  Future<Map<String, dynamic>> addVital(Vital vital) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.post(
        '/api/vitals',
        data: vital.toJson(),
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  Future<Map<String, dynamic>> getMyVitals() async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.get(
        '/api/vitals',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  Future<Map<String, dynamic>> deleteVital(String id) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.delete(
        '/api/vitals/$id',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }
}
