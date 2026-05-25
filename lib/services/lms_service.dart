import 'package:flutter/foundation.dart';
import 'package:icare/services/api_service.dart';

class LmsService {
  final ApiService _api = ApiService();

  // ═══════════════════════════════════════════════════════════════════════
  // VERIFICATION
  // ═══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getMyVerificationStatus() async {
    final response = await _api.get('/verification/my-status');
    return response.data;
  }

  Future<Map<String, dynamic>> uploadVerificationDocuments({
    required List<String> filePaths,
    required List<String> documentTypes,
  }) async {
    // TODO: Implement file upload
    // For now, return mock response
    return {
      'success': true,
      'verification': {
        'status': 'pending',
        'verificationLevel': 'limited'
      }
    };
  }

  // ═══════════════════════════════════════════════════════════════════════
  // LIVE SESSIONS
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<dynamic>> getCourseSessions(String courseId) async {
    try {
      final response = await _api.get('/live-sessions/course/$courseId');
      return response.data['sessions'] ?? [];
    } catch (_) { return []; }
  }

  Future<List<dynamic>> getUpcomingSessions() async {
    try {
      final response = await _api.get('/live-sessions/upcoming');
      return response.data['sessions'] ?? [];
    } catch (_) { return []; }
  }

  Future<Map<String, dynamic>> joinSession(String sessionId) async {
    try {
      final response = await _api.post('/live-sessions/$sessionId/join', {});
      return response.data ?? {};
    } catch (e) { return {'success': false, 'message': e.toString()}; }
  }

  Future<Map<String, dynamic>> createSession(Map<String, dynamic> sessionData) async {
    try {
      final response = await _api.post('/live-sessions', sessionData);
      return response.data ?? {};
    } catch (e) { return {'success': false, 'message': e.toString()}; }
  }

  Future<Map<String, dynamic>> updateSession(String sessionId, Map<String, dynamic> data) async {
    try {
      final response = await _api.put('/live-sessions/$sessionId', data);
      return response.data ?? {};
    } catch (e) { return {'success': false}; }
  }

  Future<void> cancelSession(String sessionId) async {
    try { await _api.post('/live-sessions/$sessionId/cancel', {}); } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════════
  // QUIZZES
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<dynamic>> getCourseQuizzes(String courseId) async {
    try {
      final response = await _api.get('/quizzes/course/$courseId');
      return response.data['quizzes'] ?? [];
    } catch (_) { return []; }
  }

  Future<Map<String, dynamic>> getQuiz(String quizId) async {
    try {
      final response = await _api.get('/quizzes/$quizId');
      return response.data ?? {};
    } catch (_) { return {}; }
  }

  Future<Map<String, dynamic>> submitQuiz({
    required String quizId,
    required List<Map<String, dynamic>> answers,
    required int timeSpent,
  }) async {
    try {
      final response = await _api.post('/quizzes/$quizId/submit', {
        'answers': answers,
        'timeSpent': timeSpent,
      });
      return response.data ?? {};
    } catch (e) { return {'success': false, 'message': e.toString()}; }
  }

  Future<List<dynamic>> getMyQuizAttempts(String quizId) async {
    try {
      final response = await _api.get('/quizzes/$quizId/my-attempts');
      return response.data['attempts'] ?? [];
    } catch (_) { return []; }
  }

  Future<Map<String, dynamic>> createQuiz(Map<String, dynamic> quizData) async {
    try {
      final response = await _api.post('/quizzes', quizData);
      return response.data ?? {};
    } catch (e) { return {'success': false, 'message': e.toString()}; }
  }

  Future<Map<String, dynamic>> updateQuiz(String quizId, Map<String, dynamic> data) async {
    try {
      final response = await _api.put('/quizzes/$quizId', data);
      return response.data ?? {};
    } catch (_) { return {}; }
  }

  Future<void> deleteQuiz(String quizId) async {
    await _api.delete('/quizzes/$quizId');
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ANNOUNCEMENTS (Stream)
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<dynamic>> getCourseAnnouncements(String courseId) async {
    try {
      final response = await _api.get('/lms/announcements/course/$courseId');
      final data = response.data;
      if (data is Map) {
        // Backend returns { success: true, posts: [...] }
        return (data['posts'] ?? data['announcements'] ?? data['data'] ?? []) as List;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getAnnouncements(String courseId) async {
    return getCourseAnnouncements(courseId);
  }

  Future<void> updateAnnouncement(String postId, String content) async {
    try { await _api.put('/lms/announcements/$postId', {'content': content}); } catch (_) {}
  }

  Future<Map<String, dynamic>> createAnnouncement(Map<String, dynamic> data) async {
    try {
      final response = await _api.post('/lms/announcements', data);
      return response.data ?? {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> postAnnouncement(String courseId, String content) async {
    return createAnnouncement({
      'courseId': courseId,
      'content': content,
    });
  }

  Future<void> deleteAnnouncement(String announcementId) async {
    await _api.delete('/lms/announcements/$announcementId');
  }

  Future<void> addComment(String announcementId, String comment) async {
    await _api.post('/lms/announcements/$announcementId/comment', {
      'comment': comment,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ASSIGNMENTS (from existing routes)
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<dynamic>> getCourseAssignments(String courseId) async {
    final response = await _api.get('/lms/assignments/course/$courseId');
    return response.data['assignments'] ?? [];
  }

  Future<Map<String, dynamic>> getMySubmission(String assignmentId) async {
    final response = await _api.get('/lms/assignments/$assignmentId/my-submission');
    return response.data;
  }

  Future<Map<String, dynamic>> submitAssignment({
    required String assignmentId,
    String? content,
    String? fileUrl,
  }) async {
    final response = await _api.post('/lms/assignments/$assignmentId/submit', {
      'content': content,
      'fileUrl': fileUrl,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> createAssignment(Map<String, dynamic> data) async {
    final response = await _api.post('/lms/assignments', data);
    return response.data;
  }

  Future<List<dynamic>> getSubmissions(String assignmentId) async {
    final response = await _api.get('/lms/assignments/$assignmentId/submissions');
    return response.data['submissions'] ?? [];
  }

  Future<Map<String, dynamic>> gradeSubmission(
    String submissionId,
    num marksObtained, {
    String? feedback,
    String? rubricGrade,
    int? stars,
    String? comments,
  }) async {
    final response = await _api.put('/lms/assignments/submissions/$submissionId/grade', {
      'marksObtained': marksObtained,
      if (feedback != null) 'feedback': feedback,
      if (rubricGrade != null) 'rubricGrade': rubricGrade,
      if (stars != null) 'stars': stars,
      if (comments != null) 'comments': comments,
    });
    return response.data;
  }

  Future<List<dynamic>> getMyGrades(String courseId) async {
    final response = await _api.get('/lms/assignments/course/$courseId/my-grades');
    return response.data['grades'] ?? [];
  }

  Future<List<dynamic>> getCourseGrades(String courseId) async {
    return getMyGrades(courseId);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ATTENDANCE
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<dynamic>> getCourseAttendance(String courseId) async {
    try {
      final response = await _api.get('/lms/attendance/course/$courseId');
      return response.data['sessions'] ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getMyAttendance(String courseId) async {
    try {
      final response = await _api.get('/lms/attendance/course/$courseId/my');
      return {
        'attendance': response.data['attendance'] ?? [],
        'total': response.data['total'] ?? 0,
        'present': response.data['present'] ?? 0,
        'percentage': response.data['percentage'] ?? 0,
      };
    } catch (e) {
      return {'attendance': [], 'total': 0, 'present': 0, 'percentage': 0};
    }
  }

  Future<Map<String, dynamic>> createAttendanceSession({
    required String courseId,
    required String sessionTitle,
    required String sessionDate,
    List<Map<String, dynamic>>? records,
  }) async {
    try {
      final response = await _api.post('/lms/attendance', {
        'courseId': courseId,
        'sessionTitle': sessionTitle,
        'sessionDate': sessionDate,
        if (records != null) 'records': records,
      });
      return response.data;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> markAttendance({
    required String sessionId,
    required String courseId,
    required String status,
  }) async {
    final response = await _api.post('/lms/attendance', {
      'sessionId': sessionId,
      'courseId': courseId,
      'status': status,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> updateSessionAttendance({
    required String sessionId,
    required List<Map<String, dynamic>> records,
  }) async {
    try {
      final response = await _api.put('/lms/attendance/$sessionId', {'records': records});
      return response.data;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PEOPLE (Course Members)
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<dynamic>> getCourseStudents(String courseId) async {
    try {
      // Backend returns { success: true, students: [{ _id, name, email, progress }] }
      final response = await _api.get('/courses/enrolled-students/$courseId');
      final data = response.data;
      if (data is Map && data['success'] == true) {
        return (data['students'] ?? []) as List;
      }
      if (data is List) return data;
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getEnrolledStudents(String courseId) async {
    return getCourseStudents(courseId);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // MODULE COMPLETION
  // ═══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> markModuleComplete({
    required String enrollmentId,
    required String moduleId,
  }) async {
    try {
      final response = await _api.post(
        '/courses/enrollments/$enrollmentId/complete-module',
        {'moduleId': moduleId},
      );
      return response.data ?? {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // LESSON NOTES
  // ═══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getLessonNote(String lessonId) async {
    try {
      final response = await _api.get('/lesson-notes/$lessonId');
      return response.data ?? {};
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, dynamic>> saveLessonNote({
    required String courseId,
    required String moduleId,
    required String lessonId,
    required String content,
  }) async {
    try {
      final response = await _api.post('/lesson-notes', {
        'courseId': courseId,
        'moduleId': moduleId,
        'lessonId': lessonId,
        'content': content,
      });
      return response.data ?? {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<dynamic>> getCourseNotes(String courseId) async {
    try {
      final response = await _api.get('/lesson-notes/course/$courseId');
      return response.data['notes'] ?? [];
    } catch (e) {
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CERTIFICATES
  // ═══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> generateCertificate({
    required String courseId,
    required String studentId,
  }) async {
    try {
      final response = await _api.post('/certificates', {
        'courseId': courseId,
        'studentId': studentId,
      });
      return response.data ?? {};
    } catch (e) {
      throw Exception('Failed to generate certificate: $e');
    }
  }

  Future<Map<String, dynamic>> verifyCertificate(String code) async {
    try {
      final response = await _api.get('/certificates/verify/$code');
      return response.data ?? {};
    } catch (e) {
      return {'valid': false, 'message': 'Certificate not found'};
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // LIVE SESSION FEATURES
  // ═══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> sendLiveSessionChat({
    required String sessionId,
    required String message,
  }) async {
    try {
      final response = await _api.post('/live-sessions/$sessionId/chat', {
        'message': message,
      });
      return response.data ?? {'success': true};
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  Future<Map<String, dynamic>> raiseHand({
    required String sessionId,
  }) async {
    try {
      final response = await _api.post('/live-sessions/$sessionId/raise-hand', {});
      return response.data ?? {'success': true};
    } catch (e) {
      throw Exception('Failed to raise hand: $e');
    }
  }

  Future<Map<String, dynamic>> admitStudent({
    required String sessionId,
    required String studentId,
  }) async {
    try {
      final response = await _api.post('/live-sessions/$sessionId/admit/$studentId', {});
      return response.data ?? {'success': true};
    } catch (e) {
      throw Exception('Failed to admit student: $e');
    }
  }

  Future<List<dynamic>> getLiveSessionPolls(String sessionId) async {
    try {
      final response = await _api.get('/live-session-polls/session/$sessionId');
      return response.data['polls'] ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createLiveSessionPoll({
    required String sessionId,
    required String question,
    required List<String> options,
  }) async {
    try {
      final response = await _api.post('/live-session-polls', {
        'sessionId': sessionId,
        'question': question,
        'options': options,
        'isActive': true,
      });
      return response.data ?? {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> respondToPoll({
    required String pollId,
    required int optionIndex,
  }) async {
    try {
      final response = await _api.post('/live-session-polls/$pollId/respond', {
        'optionIndex': optionIndex,
      });
      return response.data ?? {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // INVITE TEACHER
  // ═══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> checkActiveLiveSession(String courseId) async {
    try {
      final response = await _api.get('/live-sessions/course/$courseId/active');
      return response.data ?? {'isLive': false};
    } catch (_) {
      return {'isLive': false};
    }
  }

  Future<Map<String, dynamic>> joinLiveSession(String sessionId) async {
    try {
      final response = await _api.post('/live-sessions/$sessionId/join', {});
      return response.data ?? {};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getSessionState(String sessionId) async {
    try {
      final response = await _api.get('/live-sessions/$sessionId');
      return response.data ?? {};
    } catch (_) {
      return {};
    }
  }

  Future<List<dynamic>> getSessionChatMessages(String sessionId) async {
    try {
      final response = await _api.get('/live-sessions/$sessionId/chat');
      return response.data['messages'] ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<void> sendSessionChatMessage(String sessionId, String message) async {
    try {
      await _api.post('/live-sessions/$sessionId/chat', {'message': message});
    } catch (_) {}
  }

  Future<void> raiseSessionHand(String sessionId) async {
    try {
      await _api.post('/live-sessions/$sessionId/raise-hand', {});
    } catch (_) {}
  }

  Future<void> lowerSessionHand(String sessionId) async {
    try {
      await _api.post('/live-sessions/$sessionId/lower-hand', {});
    } catch (_) {}
  }

  Future<void> setSessionLive({required String courseId, required bool isLive, String? title}) async {
    try {
      await _api.post('/live-sessions/course/$courseId/set-live', {'isLive': isLive, if (title != null) 'title': title});
    } catch (_) {}
  }

  Future<Map<String, dynamic>> startRecording(String sessionId) async {
    try {
      final response = await _api.post('/live-sessions/$sessionId/recording/start', {});
      return response.data ?? {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> stopRecording(String sessionId) async {
    try {
      final response = await _api.post('/live-sessions/$sessionId/recording/stop', {});
      return response.data ?? {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> endAndSaveSession({
    required String sessionId,
    String? lessonId,
    String? moduleId,
  }) async {
    try {
      final response = await _api.post('/live-sessions/$sessionId/end-and-save', {
        if (lessonId != null) 'lessonId': lessonId,
        if (moduleId != null) 'moduleId': moduleId,
      });
      return response.data ?? {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getSessionTranscript(String sessionId) async {
    try {
      final response = await _api.get('/live-sessions/$sessionId/transcript');
      return response.data ?? {};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<void> startLiveSessionNotify({
    required String courseId,
    required String sessionId,
    required String instructorName,
    required String sessionTitle,
  }) async {
    try {
      await _api.post('/live-sessions/notify-start', {
        'courseId': courseId,
        'sessionId': sessionId,
        'instructorName': instructorName,
        'sessionTitle': sessionTitle,
      });
    } catch (e) {
      debugPrint('Session notify error: $e');
    }
  }

  Future<Map<String, dynamic>> createVoucher({
    required String code,
    required int discountPercent,
  }) async {
    try {
      final response = await _api.post('/vouchers', {
        'code': code,
        'discountPercent': discountPercent,
        'isOneTime': true,
        'isActive': true,
      });
      return response.data ?? {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> inviteTeacher({
    required String courseId,
    required String email,
  }) async {
    try {
      final response = await _api.post('/courses/$courseId/invite-teacher', {
        'email': email,
      });
      return response.data ?? {'success': true};
    } catch (e) {
      throw Exception('Failed to invite teacher: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // INSTRUCTOR - COURSES
  // ═══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getInstructorCourses() async {
    final response = await _api.get('/courses');
    return {
      'success': true,
      'courses': response.data['courses'] ?? [],
    };
  }

  Future<Map<String, dynamic>> createCourse(Map<String, dynamic> courseData) async {
    final response = await _api.post('/courses', courseData);
    return response.data;
  }

  Future<Map<String, dynamic>> updateCourse(String courseId, Map<String, dynamic> data) async {
    final response = await _api.put('/courses/$courseId', data);
    return response.data;
  }

  Future<void> deleteCourse(String courseId) async {
    await _api.delete('/courses/$courseId');
  }

  Future<Map<String, dynamic>> getCourseDetails(String courseId) async {
    final response = await _api.get('/courses/$courseId');
    return response.data;
  }

  Future<Map<String, dynamic>> publishCourse(String courseId) async {
    final response = await _api.put('/courses/$courseId', {'isPublished': true});
    return response.data;
  }

  Future<Map<String, dynamic>> unpublishCourse(String courseId) async {
    final response = await _api.put('/courses/$courseId', {'isPublished': false});
    return response.data;
  }
}
