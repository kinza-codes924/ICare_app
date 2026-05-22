import 'package:flutter/foundation.dart';
import 'package:icare/models/course.dart';
import 'package:icare/services/api_service.dart';

class CourseService {
  final ApiService _apiService = ApiService();

  // ═══════════════════════════════════════════════════════════════════════
  // COURSE CRUD OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════

  /// Create a new course (instructor only)
  Future<Course> createCourse(Map<String, dynamic> courseData) async {
    final response = await _apiService.post('/courses', courseData);
    return Course.fromJson(response.data['course']);
  }

  /// Get all courses with optional filters
  Future<List<Course>> getCourses({
    String? category,
    String? targetAudience,
    String? difficulty,
    bool? isPublished,
    String? instructorId,
    String? healthCondition,
  }) async {
    final queryParams = <String, dynamic>{};

    if (category != null) queryParams['category'] = category;
    if (targetAudience != null) queryParams['targetAudience'] = targetAudience;
    if (difficulty != null) queryParams['difficulty'] = difficulty;
    if (isPublished != null) {
      queryParams['isPublished'] = isPublished.toString();
    }
    if (instructorId != null) queryParams['instructorId'] = instructorId;
    if (healthCondition != null) {
      queryParams['healthCondition'] = healthCondition;
    }

    final response = await _apiService.get(
      '/courses',
      queryParameters: queryParams,
    );
    final courses = (response.data['courses'] as List)
        .map((json) => Course.fromJson(json))
        .toList();
    return courses;
  }

  /// Get my courses (for instructors)
  Future<List<Course>> getMyCourses() async {
    final response = await _apiService.get('/courses');
    final courses = (response.data['courses'] as List)
        .map((json) => Course.fromJson(json))
        .toList();
    return courses;
  }

  /// Get course by ID
  Future<Course> getCourseById(String id) async {
    final response = await _apiService.get('/courses/$id');
    return Course.fromJson(response.data['course']);
  }

  /// Update course (instructor only)
  Future<Course> updateCourse(
    String id,
    Map<String, dynamic> courseData,
  ) async {
    final response = await _apiService.put('/courses/$id', courseData);
    return Course.fromJson(response.data['course']);
  }

  /// Delete course
  Future<void> deleteCourse(String id) async {
    await _apiService.delete('/courses/$id');
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PUBLISH/UNPUBLISH OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════

  /// Publish a course
  Future<Course> publishCourse(String id) async {
    final response = await _apiService.post('/courses/$id/publish', {});
    return Course.fromJson(response.data['course']);
  }

  /// Unpublish a course
  Future<Course> unpublishCourse(String id) async {
    final response = await _apiService.post('/courses/$id/unpublish', {});
    return Course.fromJson(response.data['course']);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════════

  /// Get published health programs for patients
  Future<List<Course>> getHealthPrograms({String? healthCondition}) async {
    return getCourses(
      category: 'HealthProgram',
      isPublished: true,
      healthCondition: healthCondition,
    );
  }

  /// Get published professional courses for doctors
  Future<List<Course>> getProfessionalCourses({String? difficulty}) async {
    return getCourses(
      category: 'ProfessionalCourse',
      isPublished: true,
      difficulty: difficulty,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STUDENT / PUBLIC METHODS
  // ═══════════════════════════════════════════════════════════════════════

  // List all public courses
  Future<List<dynamic>> listPublicCourses() async {
    try {
      final response = await _apiService.get('/students/courses');
      return response.data['courses'] ?? [];
    } catch (e) {
      debugPrint('Error listing public courses: $e');
      rethrow;
    }
  }

  // Get course details by ID
  Future<Map<String, dynamic>> getCourseDetails(String courseId) async {
    try {
      final response = await _apiService.get('/students/courses/$courseId');
      return response.data['course'];
    } catch (e) {
      debugPrint('Error getting course details: $e');
      rethrow;
    }
  }

  // Buy/Enroll in a course
  Future<Map<String, dynamic>> buyCourse(String courseId) async {
    try {
      debugPrint('Attempting to buy course: $courseId');
      final response = await _apiService.post('/students/courses/enrollments', {
        'courseId': courseId,
      });
      debugPrint('Buy course response: ${response.data}');
      return response.data;
    } catch (e) {
      debugPrint('Error buying course: $e');
      rethrow;
    }
  }

  /// Assign a health program to a patient (by doctor or instructor)
  Future<Map<String, dynamic>> assignHealthProgram(
    String patientId,
    String courseId,
  ) async {
    try {
      final response = await _apiService.post('/clinical/assign-program', {
        'patientId': patientId,
        'courseId': courseId,
        'assignedAt': DateTime.now().toIso8601String(),
      });
      return response.data;
    } catch (e) {
      debugPrint('Error assigning health program: $e');
      rethrow;
    }
  }

  /// Get learners assigned to instructor's courses
  Future<List<dynamic>> getAssignedLearners() async {
    try {
      final response = await _apiService.get('/instructor/learners');
      return response.data['learners'] ?? [];
    } catch (e) {
      debugPrint('Error fetching assigned learners: $e');
      return [];
    }
  }

  // Get my purchased courses
  Future<List<dynamic>> myPurchases() async {
    try {
      final response = await _apiService.get(
        '/students/courses/enrollments/my',
      );
      return response.data['items'] ?? response.data['enrollments'] ?? [];
    } catch (e) {
      debugPrint('Error getting my purchases: $e');
      rethrow;
    }
  }

  // Update course progress
  Future<Map<String, dynamic>> updateProgress(
    String enrollmentId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _apiService.put(
        '/students/courses/enrollments/$enrollmentId/progress',
        data,
      );
      return response.data;
    } catch (e) {
      debugPrint('Error updating progress: $e');
      rethrow;
    }
  }

  // Get my certificates
  Future<List<dynamic>> myCertificates() async {
    try {
      final response = await _apiService.get(
        '/students/courses/certificates/my',
      );
      return response.data['certificates'] ?? [];
    } catch (e) {
      debugPrint('Error getting my certificates: $e');
      rethrow;
    }
  }

  // Submit quiz result
  Future<Map<String, dynamic>> submitQuizResult(
    String enrollmentId,
    Map<String, dynamic> quizData,
  ) async {
    try {
      final response = await _apiService.put(
        '/students/courses/enrollments/$enrollmentId/progress',
        {
          'quizResult': {
            'moduleIndex': quizData['moduleIndex'] ?? 0,
            'score': quizData['score'] ?? 0,
            'totalQuestions': quizData['totalQuestions'] ?? 0,
            'passed': quizData['passed'] ?? false,
          },
          if (quizData['passed'] == true) 'completedVideos': 9999,
        },
      );
      return response.data;
    } catch (e) {
      debugPrint('Error submitting quiz result: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HEALTH COMMUNITY / FORUM METHODS
  // ═══════════════════════════════════════════════════════════════════════

  // Get forum posts
  Future<List<dynamic>> getForumPosts({String? category}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (category != null && category != 'All') {
        queryParams['category'] = category;
      }
      final response = await _apiService.get(
        '/community/posts',
        queryParameters: queryParams,
      );
      return response.data['posts'] ?? [];
    } catch (e) {
      debugPrint('Error getting forum posts: $e');
      return [];
    }
  }

  // Create forum post
  Future<Map<String, dynamic>> createForumPost(
    Map<String, dynamic> postData,
  ) async {
    try {
      final response = await _apiService.post('/community/posts', postData);
      return response.data;
    } catch (e) {
      debugPrint('Error creating forum post: $e');
      rethrow;
    }
  }

  // Like forum post
  Future<void> likeForumPost(String postId) async {
    try {
      await _apiService.post('/community/posts/$postId/like', {});
    } catch (e) {
      debugPrint('Error liking forum post: $e');
    }
  }

  Future<void> reshareForumPost(String postId) async {
    try {
      await _apiService.post('/community/posts/$postId/reshare', {});
    } catch (e) {
      debugPrint('Error resharing forum post: $e');
      rethrow;
    }
  }

  // Comment on forum post
  Future<void> addForumComment(String postId, String comment) async {
    try {
      await _apiService.post('/community/posts/$postId/comment', {
        'content': comment,
      });
    } catch (e) {
      debugPrint('Error adding forum comment: $e');
      rethrow;
    }
  }
}
