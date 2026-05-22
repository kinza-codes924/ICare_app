import 'package:dio/dio.dart';
import 'api_service.dart';

class PrescriptionTemplateService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> getTemplates() async {
    try {
      final response = await _apiService.get('/prescription-templates');

      if (response.statusCode == 200) {
        return {'success': true, 'templates': response.data['templates']};
      }
      return {'success': false, 'message': 'Failed to fetch templates'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Network error',
      };
    }
  }

  Future<Map<String, dynamic>> createTemplate({
    required String name,
    required List<Map<String, String>> medicines,
  }) async {
    try {
      final response = await _apiService.post('/prescription-templates', {
        'name': name,
        'medicines': medicines,
      });

      if (response.statusCode == 201) {
        return {'success': true, 'template': response.data['template']};
      }
      return {'success': false, 'message': 'Failed to create template'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Network error',
      };
    }
  }

  Future<Map<String, dynamic>> updateTemplate({
    required String id,
    required String name,
    required List<Map<String, String>> medicines,
  }) async {
    try {
      final response = await _apiService.put('/prescription-templates/$id', {
        'name': name,
        'medicines': medicines,
      });

      if (response.statusCode == 200) {
        return {'success': true, 'template': response.data['template']};
      }
      return {'success': false, 'message': 'Failed to update template'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Network error',
      };
    }
  }

  Future<Map<String, dynamic>> deleteTemplate(String id) async {
    try {
      final response = await _apiService.delete('/prescription-templates/$id');

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Template deleted'};
      }
      return {'success': false, 'message': 'Failed to delete template'};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Network error',
      };
    }
  }
}
