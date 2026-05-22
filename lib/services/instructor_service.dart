import 'package:flutter/foundation.dart';
import 'package:icare/services/api_service.dart';

class InstructorService {
  final ApiService _apiService = ApiService();
  String? _cachedInstructorId;

  // Q&A Management
  Future<List<dynamic>> getAllPendingQuestions() async {
    try {
      final response = await _apiService.get('/instructor/qa/pending');
      return response.data['questions'] ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<void> replyToQuestion(String questionId, String reply) async {
    await _apiService.post('/instructor/qa/reply', {
      'questionId': questionId,
      'reply': reply,
    });
  }

  // Earnings & Wallet
  Future<Map<String, dynamic>> getEarningsSummary() async {
    try {
      final response = await _apiService.get('/instructor/earnings/summary');
      return response.data['summary'] ?? {};
    } catch (e) {
      return {};
    }
  }

  Future<List<dynamic>> getPayoutHistory() async {
    try {
      final response = await _apiService.get('/instructor/earnings/payouts');
      return response.data['payouts'] ?? [];
    } catch (e) {
      return [];
    }
  }

  // Detailed Analytics
  Future<Map<String, dynamic>> getAssessmentAnalytics(String courseId) async {
    try {
      final response = await _apiService.get(
        '/instructor/analytics/assessments/$courseId',
      );
      return response.data['analytics'] ?? {};
    } catch (e) {
      return {};
    }
  }

  // Get instructor profile for logged-in instructor
  Future<Map<String, dynamic>> getMyProfile() async {
    final response = await _apiService.get('/instructors/me');
    final instructor = response.data['instructor'];
    // Cache the user_id (not profile _id) — courses/precautions are keyed by user_id
    _cachedInstructorId = instructor['user_id'] as String? ?? instructor['_id'];
    return instructor;
  }

  // Update/Create instructor profile
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final response = await _apiService.post(
      '/instructors/add_instructor_details',
      data,
    );
    return response.data['instructor'] ?? response.data['existingProfile'];
  }

  // Get all instructors (public)
  Future<List<dynamic>> getAllInstructors() async {
    final response = await _apiService.get('/instructors/get_all_instructors');
    return response.data['instructors'] as List;
  }

  // Get instructor by ID
  Future<Map<String, dynamic>> getInstructorById(String id) async {
    final response = await _apiService.get('/instructors/$id');
    return response.data['instructor'];
  }

  Future<String> _getInstructorId() async {
    if (_cachedInstructorId != null) {
      return _cachedInstructorId!;
    }
    final profile = await getMyProfile();
    // user_id is the User._id — this is what instructor_id in Course refers to
    return profile['user_id'] as String? ?? profile['_id'] as String;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // COURSES MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════

  // Get my courses — tries token-based endpoint first, falls back to query param
  Future<List<dynamic>> getMyCourses() async {
    try {
      // Try new token-based endpoint first
      final response = await _apiService.get('/instructors/my-courses');
      return response.data['courses'] as List;
    } catch (e) {
      debugPrint('my-courses failed, trying fallback: $e');
      try {
        // Fallback: use courses endpoint without instructorId filter
        // Backend will return all courses; we filter by token on backend
        final response = await _apiService.get('/instructors/courses');
        return response.data['courses'] as List;
      } catch (e2) {
        debugPrint('Error getting my courses: $e2');
        rethrow;
      }
    }
  }

  // Get all public courses
  Future<List<dynamic>> getAllCourses({
    String? visibility,
    String? search,
  }) async {
    String url = '/instructors/courses';
    List<String> params = [];

    if (visibility != null) params.add('visibility=$visibility');
    if (search != null && search.isNotEmpty) {
      params.add('q=${Uri.encodeComponent(search)}');
    }

    if (params.isNotEmpty) url += '?${params.join('&')}';

    final response = await _apiService.get(url);
    return response.data['courses'] as List;
  }

  // Get course by ID
  Future<Map<String, dynamic>> getCourseById(String id) async {
    final response = await _apiService.get('/instructors/courses/$id');
    return response.data['course'];
  }

  // Create course
  Future<Map<String, dynamic>> createCourse(Map<String, dynamic> data) async {
    final response = await _apiService.post('/instructors/courses', data);
    return response.data['course'];
  }

  // Update course
  Future<Map<String, dynamic>> updateCourse(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _apiService.put('/instructors/courses/$id', data);
    return response.data['course'];
  }

  // Delete course
  Future<void> deleteCourse(String id) async {
    await _apiService.delete('/instructors/courses/$id');
  }

  // Assign course to doctor/student
  Future<Map<String, dynamic>> assignCourse(
    String courseId,
    String targetUserId,
  ) async {
    try {
      final response = await _apiService.post('/instructors/courses/assign', {
        'courseId': courseId,
        'targetUserId': targetUserId,
      });
      return response.data;
    } catch (e) {
      debugPrint('Error assigning course: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PRECAUTIONS MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════

  // Get my precautions
  Future<List<dynamic>> getMyPrecautions() async {
    try {
      final instructorId = await _getInstructorId();
      final response = await _apiService.get(
        '/instructors/precautions?instructorId=$instructorId',
      );
      return response.data['precautions'] as List;
    } catch (e) {
      debugPrint('Error getting my precautions: $e');
      rethrow;
    }
  }

  // Get all precautions
  Future<List<dynamic>> getAllPrecautions({String? instructorId}) async {
    String url = '/instructors/precautions';
    if (instructorId != null) url += '?instructorId=$instructorId';

    final response = await _apiService.get(url);
    return response.data['precautions'] as List;
  }

  // Get precaution by ID
  Future<Map<String, dynamic>> getPrecautionById(String id) async {
    final response = await _apiService.get('/instructors/precautions/$id');
    return response.data['precaution'];
  }

  // Create precaution
  Future<Map<String, dynamic>> createPrecaution(
    Map<String, dynamic> data,
  ) async {
    final response = await _apiService.post('/instructors/precautions', data);
    return response.data['precaution'];
  }

  // Update precaution
  Future<Map<String, dynamic>> updatePrecaution(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _apiService.put(
      '/instructors/precautions/$id',
      data,
    );
    return response.data['precaution'];
  }

  // Delete precaution
  Future<void> deletePrecaution(String id) async {
    await _apiService.delete('/instructors/precautions/$id');
  }

  // STATISTICS
  // ═══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getStats() async {
    try {
      final response = await _apiService.get('/instructors/stats');
      return response.data['stats'] ?? {};
    } catch (e) {
      debugPrint('Error getting stats: $e');
      return {};
    }
  }

  // Get assigned learners (enrolled students)
  Future<List<dynamic>> getAssignedLearners() async {
    try {
      final response = await _apiService.get('/instructors/assigned-learners');
      return response.data['learners'] ?? [];
    } catch (e) {
      debugPrint('Error getting assigned learners: $e');
      rethrow;
    }
  }

  // Store video URL (URL-based — no file upload on Vercel serverless)
  Future<Map<String, dynamic>> uploadVideo({
    String? filePath,
    List<int>? bytes,
    required String fileName,
    String? videoUrl,
  }) async {
    try {
      // If a direct URL is provided, just return it
      if (videoUrl != null && videoUrl.isNotEmpty) {
        return {'success': true, 'videoUrl': videoUrl};
      }
      // Fallback: return empty (file upload not supported on Vercel)
      return {'success': false, 'message': 'Please provide a video URL (YouTube, Vimeo, or direct link)'};
    } catch (e) {
      debugPrint('❌ uploadVideo error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Store thumbnail URL
  Future<Map<String, dynamic>> uploadThumbnail({
    String? filePath,
    List<int>? bytes,
    required String fileName,
    String? thumbnailUrl,
  }) async {
    try {
      if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
        return {'success': true, 'thumbnailUrl': thumbnailUrl};
      }
      return {'success': false, 'message': 'Please provide a thumbnail URL'};
    } catch (e) {
      debugPrint('❌ uploadThumbnail error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
}
