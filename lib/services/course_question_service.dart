import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import '../utils/shared_pref.dart';

final _sharedPref = SharedPref();

class CourseQuestionService {
  static Future<List<dynamic>> getCourseQuestions(String courseId) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/course-questions/course/$courseId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['questions'] ?? [];
      } else {
        throw Exception('Failed to load questions');
      }
    } catch (e) {
      throw Exception('Error loading questions: $e');
    }
  }

  static Future<Map<String, dynamic>> askQuestion({
    required String courseId,
    required String question,
  }) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/course-questions/ask'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'courseId': courseId, 'question': question}),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to post question');
      }
    } catch (e) {
      throw Exception('Error posting question: $e');
    }
  }

  static Future<Map<String, dynamic>> answerQuestion({
    required String questionId,
    required String answer,
  }) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/course-questions/$questionId/answer'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'answer': answer}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to post answer');
      }
    } catch (e) {
      throw Exception('Error posting answer: $e');
    }
  }

  static Future<List<dynamic>> getUnansweredQuestions() async {
    try {
      final token = await _sharedPref.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/course-questions/unanswered'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['questions'] ?? [];
      } else {
        throw Exception('Failed to load unanswered questions');
      }
    } catch (e) {
      throw Exception('Error loading unanswered questions: $e');
    }
  }

  static Future<void> deleteQuestion(String questionId) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/course-questions/$questionId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete question');
      }
    } catch (e) {
      throw Exception('Error deleting question: $e');
    }
  }
}
