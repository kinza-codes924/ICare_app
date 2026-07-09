import 'package:flutter/foundation.dart';
import 'package:icare/services/api_service.dart';

class CommunityService {
  final ApiService _apiService = ApiService();

  static const List<String> defaultCategories = [
    'All', 'General', 'Diabetes', 'Heart Health',
    'Mental Wellness', 'Nutrition', 'Pregnancy', 'COVID-19',
  ];

  Future<List<String>> getCategories() async {
    try {
      final response = await _apiService.get('/community/categories');
      final raw = response.data['categories'] as List? ?? [];
      final custom = raw.map((e) => e.toString()).where((n) => !defaultCategories.contains(n)).toList();
      return [...defaultCategories, ...custom];
    } catch (e) {
      return defaultCategories;
    }
  }

  Future<bool> addCategory(String name) async {
    try {
      final response = await _apiService.post('/community/categories', {'name': name});
      return response.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> getPosts(String category) async {
    try {
      final param = category == 'All' ? '' : '?category=${Uri.encodeComponent(category)}';
      final response = await _apiService.get('/community/posts$param');
      return response.data['posts'] as List? ?? [];
    } catch (e) {
      debugPrint('getPosts error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createPost({
    required String content,
    required String category,
    String? imageUrl,
  }) async {
    try {
      final response = await _apiService.post('/community/posts', {
        'content': content,
        'category': category,
        if (imageUrl != null) 'imageUrl': imageUrl,
      });
      return response.data as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<void> likePost(String postId) async {
    try {
      await _apiService.post('/community/posts/$postId/like', {});
    } catch (e) {
      debugPrint('likePost error: $e');
    }
  }

  Future<Map<String, dynamic>> addComment(String postId, String content) async {
    try {
      final response = await _apiService.post('/community/posts/$postId/comment', {'content': content});
      return response.data as Map<String, dynamic>;
    } catch (e) {
      return {'success': false};
    }
  }

  Future<bool> deletePost(String postId) async {
    try {
      await _apiService.delete('/community/posts/$postId');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteComment(String postId, String commentId) async {
    try {
      await _apiService.delete('/community/posts/$postId/comments/$commentId');
      return true;
    } catch (e) {
      return false;
    }
  }
}
