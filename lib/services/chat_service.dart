import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import '../utils/shared_pref.dart';

class ChatService {
  final ApiService _api = ApiService();
  final SharedPref _sharedPref = SharedPref();

  Future<String?> _getToken() async => await _sharedPref.getToken();

  Future<Map<String, dynamic>> sendMessage({
    required String receiverId,
    required String message,
    List<Map<String, dynamic>>? attachments,
  }) async {
    try {
      final token = await _getToken();
      final response = await _api.post(
        '/chat/send',
        {
          'receiverId': receiverId,
          'message': message,
          if (attachments != null) 'attachments': attachments,
        },
        token: token,
      );
      return (response.data as Map<String, dynamic>?) ?? {};
    } catch (e) {
      debugPrint('❌ Failed to send message: $e');
      throw Exception('Failed to send message: $e');
    }
  }

  Future<Map<String, dynamic>> uploadFile({
    String? filePath,
    List<int>? bytes,
    required String fileName,
  }) async {
    try {
      final token = await _getToken();
      MultipartFile file;
      if (kIsWeb) {
        if (bytes == null) throw Exception('Bytes required for web upload');
        file = MultipartFile.fromBytes(bytes, filename: fileName);
      } else {
        if (filePath == null) throw Exception('File path required for mobile upload');
        file = await MultipartFile.fromFile(filePath, filename: fileName);
      }
      final response = await _api.postMultipart('/chat/upload', FormData.fromMap({'file': file}), token: token);
      return (response.data as Map<String, dynamic>?) ?? {};
    } catch (e) {
      debugPrint('❌ Failed to upload file: $e');
      throw Exception('Failed to upload file: $e');
    }
  }

  Future<List<dynamic>> getChatHistory(String userId) async {
    try {
      if (userId.isEmpty) throw Exception('User ID cannot be empty');
      final token = await _getToken();
      if (token == null || token.isEmpty) throw Exception('Not authenticated');
      final response = await _api.get('/chat/history/$userId', token: token);
      if (response.statusCode == 404) return [];
      final data = response.data as Map<String, dynamic>?;
      return data?['data'] as List? ?? [];
    } on DioException catch (e) {
      debugPrint('❌ DioException getting chat history: ${e.message}');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      debugPrint('❌ Error getting chat history: $e');
      rethrow;
    }
  }

  Future<void> markAsRead(String senderId) async {
    try {
      final token = await _getToken();
      await _api.put('/chat/read', {'senderId': senderId}, token: token);
    } catch (e) {
      debugPrint('⚠️ Could not mark messages as read: $e');
    }
  }

  Future<void> sendTypingIndicator(String receiverId, bool isTyping) async {
    try {
      final token = await _getToken();
      await _api.post('/chat/typing', {'receiverId': receiverId, 'isTyping': isTyping}, token: token);
    } catch (_) {}
  }

  Future<Map<String, dynamic>> getPusherAuth(String socketId, String channelName) async {
    try {
      final token = await _getToken();
      final response = await _api.post(
        '/chat/pusher/auth',
        {'socket_id': socketId, 'channel_name': channelName},
        token: token,
      );
      return (response.data as Map<String, dynamic>?) ?? {};
    } catch (e) {
      throw Exception('Failed to authenticate with Pusher: $e');
    }
  }

  Future<List<dynamic>> getConversations() async {
    try {
      final token = await _getToken();
      final response = await _api.get('/chat/conversations', token: token);
      final data = response.data as Map<String, dynamic>?;
      return data?['data'] as List? ?? [];
    } catch (e) {
      throw Exception('Failed to get conversations: $e');
    }
  }
}
