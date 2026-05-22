import 'api_service.dart';
import '../utils/error_handler.dart';

class TestCatalogService {
  static final ApiService _apiService = ApiService();

  /// Get all available tests from catalog
  Future<List<Map<String, dynamic>>> getAllTests() async {
    try {
      final response = await _apiService.get('/test-catalog');
      return List<Map<String, dynamic>>.from(response.data['tests'] ?? []);
    } catch (e, stackTrace) {
      ErrorHandler.logError(e, stackTrace, context: 'getAllTests');
      rethrow;
    }
  }

  /// Get test by ID
  Future<Map<String, dynamic>> getTestById(String testId) async {
    try {
      final response = await _apiService.get('/test-catalog/$testId');
      return response.data['test'];
    } catch (e, stackTrace) {
      ErrorHandler.logError(e, stackTrace, context: 'getTestById');
      rethrow;
    }
  }

  /// Get tests by category
  Future<List<Map<String, dynamic>>> getTestsByCategory(String category) async {
    try {
      final response = await _apiService.get(
        '/test-catalog/category/$category',
      );
      return List<Map<String, dynamic>>.from(response.data['tests'] ?? []);
    } catch (e, stackTrace) {
      ErrorHandler.logError(e, stackTrace, context: 'getTestsByCategory');
      rethrow;
    }
  }

  /// Search tests by name
  Future<List<Map<String, dynamic>>> searchTests(String query) async {
    try {
      final response = await _apiService.get('/test-catalog/search?q=$query');
      return List<Map<String, dynamic>>.from(response.data['tests'] ?? []);
    } catch (e, stackTrace) {
      ErrorHandler.logError(e, stackTrace, context: 'searchTests');
      rethrow;
    }
  }

  /// Create new test (Admin only)
  Future<Map<String, dynamic>> createTest(Map<String, dynamic> testData) async {
    try {
      final response = await _apiService.post('/test-catalog', testData);
      return response.data['test'];
    } catch (e, stackTrace) {
      ErrorHandler.logError(e, stackTrace, context: 'createTest');
      rethrow;
    }
  }

  /// Update test (Admin only)
  Future<Map<String, dynamic>> updateTest(
    String testId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _apiService.put('/test-catalog/$testId', updates);
      return response.data['test'];
    } catch (e, stackTrace) {
      ErrorHandler.logError(e, stackTrace, context: 'updateTest');
      rethrow;
    }
  }

  /// Delete test (Admin only)
  Future<void> deleteTest(String testId) async {
    try {
      await _apiService.delete('/test-catalog/$testId');
    } catch (e, stackTrace) {
      ErrorHandler.logError(e, stackTrace, context: 'deleteTest');
      rethrow;
    }
  }

  /// Get all categories
  Future<List<String>> getCategories() async {
    try {
      final response = await _apiService.get('/test-catalog/categories');
      return List<String>.from(response.data['categories'] ?? []);
    } catch (e, stackTrace) {
      ErrorHandler.logError(e, stackTrace, context: 'getCategories');
      rethrow;
    }
  }

  /// Get popular tests
  Future<List<Map<String, dynamic>>> getPopularTests({int limit = 10}) async {
    try {
      final response = await _apiService.get(
        '/test-catalog/popular?limit=$limit',
      );
      return List<Map<String, dynamic>>.from(response.data['tests'] ?? []);
    } catch (e, stackTrace) {
      ErrorHandler.logError(e, stackTrace, context: 'getPopularTests');
      rethrow;
    }
  }
}
