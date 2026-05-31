import 'package:flutter/foundation.dart';
import 'api_service.dart';

class ReviewService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> submitReview({
    required String appointmentId,
    required String doctorId,
    required int starRating,
    required bool satisfied,
    String? reviewText,
  }) async {
    try {
      final response = await _apiService.post('/reviews/submit', {
        'appointmentId': appointmentId,
        'doctorId': doctorId,
        'rating': starRating,
        'satisfied': satisfied,
        if (reviewText != null && reviewText.isNotEmpty) 'review': reviewText,
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true};
      }
      return {'success': false, 'message': response.data?['message'] ?? 'Failed to submit review'};
    } catch (e) {
      debugPrint('ReviewService error: $e');
      return {'success': false, 'message': 'Something went wrong'};
    }
  }

  Future<Map<String, dynamic>> getDoctorReviews(String doctorId) async {
    try {
      final response = await _apiService.get('/reviews/doctor/$doctorId');
      if (response.statusCode == 200) {
        return {'success': true, 'reviews': response.data['reviews'] ?? []};
      }
      return {'success': false, 'reviews': []};
    } catch (e) {
      debugPrint('ReviewService getDoctorReviews error: $e');
      return {'success': false, 'reviews': []};
    }
  }
}
