import 'package:icare/services/api_service.dart';

class FamilyService {
  final ApiService _apiService = ApiService();

  // Manage Dependents
  Future<List<dynamic>> getDependents() async {
    try {
      final response = await _apiService.get('/family/dependents');
      return response.data['dependents'] ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<void> addDependent(Map<String, dynamic> data) async {
    await _apiService.post('/family/dependents', data);
  }

  Future<void> removeDependent(String dependentId) async {
    await _apiService.delete('/family/dependents/$dependentId');
  }

  // Dependent Specific DHR Access
  Future<Map<String, dynamic>> getDependentDHR(String dependentId) async {
    final response = await _apiService.get(
      '/family/dependents/$dependentId/dhr',
    );
    return response.data['dhr'] ?? {};
  }
}
