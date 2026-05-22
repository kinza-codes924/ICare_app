import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_config.dart';
import '../utils/shared_pref.dart';

class ChatService {
  final Dio _dio = Dio();
  final SharedPref _sharedPref = SharedPref();

  Future<String?> _getToken() async {
    return await _sharedPref.getToken();
  }

  Future<Map<String, dynamic>> sendMessage({
    required String receiverId,
    required String message,
    List<Map<String, dynamic>>? attachments,
  }) async {
    try {
      debugPrint('📤 Sending message to: $receiverId');
      debugPrint('📝 Message: $message');

      final token = await _getToken();
      debugPrint('🔑 Token: ${token?.substring(0, 20)}...');

      final response = await _dio.post(
        '${ApiConfig.baseUrl}/chat/send',
        data: {
          'receiverId': receiverId,
          'message': message,
          if (attachments != null) 'attachments': attachments,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      debugPrint('✅ Message sent successfully');
      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📡 Response data: ${response.data}');

      return response.data;
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
        if (filePath == null) {
          throw Exception('File path required for mobile upload');
        }
        file = await MultipartFile.fromFile(filePath, filename: fileName);
      }

      final formData = FormData.fromMap({'file': file});

      final response = await _dio.post(
        '${ApiConfig.baseUrl}/chat/upload',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return response.data;
    } catch (e) {
      debugPrint('❌ Failed to upload file: $e');
      throw Exception('Failed to upload file: $e');
    }
  }

  Future<List<dynamic>> getChatHistory(String userId) async {
    try {
      debugPrint('🔍 Fetching chat history with user: $userId');

      if (userId.isEmpty) {
        throw Exception('User ID cannot be empty');
      }

      final token = await _getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }

      debugPrint('🔑 Token: ${token.substring(0, 20)}...');

      final response = await _dio.get(
        '${ApiConfig.baseUrl}/chat/history/$userId',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (status) => status! < 500,
        ),
      );

      debugPrint('✅ Chat history response: ${response.statusCode}');

      if (response.statusCode == 401) {
        throw Exception('Unauthorized. Please login again.');
      }

      if (response.statusCode == 404) {
        debugPrint('ℹ️ No chat history found, returning empty list');
        return [];
      }

      if (response.statusCode != 200) {
        throw Exception(
          'Server error: ${response.statusCode} - ${response.data}',
        );
      }

      debugPrint('📦 Response data: ${response.data}');

      if (response.data != null && response.data['data'] != null) {
        return response.data['data'] ?? [];
      }
      return [];
    } on DioException catch (e) {
      debugPrint('❌ DioException getting chat history: ${e.message}');
      debugPrint('❌ Response: ${e.response?.data}');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      debugPrint('❌ Error getting chat history: $e');
      rethrow;
    }
  }

  Future<void> markAsRead(String senderId) async {
    try {
      final token = await _getToken();
      await _dio.put(
        '${ApiConfig.baseUrl}/chat/read',
        data: {'senderId': senderId},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      debugPrint('✅ Messages marked as read');
    } catch (e) {
      // Non-critical error - just log it and continue
      debugPrint('⚠️ Could not mark messages as read (non-critical): $e');
    }
  }

  Future<void> sendTypingIndicator(String receiverId, bool isTyping) async {
    try {
      final token = await _getToken();
      await _dio.post(
        '${ApiConfig.baseUrl}/chat/typing',
        data: {'receiverId': receiverId, 'isTyping': isTyping},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (e) {
      // Silently fail for typing indicators
    }
  }

  Future<Map<String, dynamic>> getPusherAuth(
    String socketId,
    String channelName,
  ) async {
    try {
      final token = await _getToken();
      final response = await _dio.post(
        '${ApiConfig.baseUrl}/chat/pusher/auth',
        data: {'socket_id': socketId, 'channel_name': channelName},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } catch (e) {
      throw Exception('Failed to authenticate with Pusher: $e');
    }
  }

  Future<List<dynamic>> getConversations() async {
    try {
      final token = await _getToken();
      final response = await _dio.get(
        '${ApiConfig.baseUrl}/chat/conversations',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data['data'] ?? [];
    } catch (e) {
      throw Exception('Failed to get conversations: $e');
    }
  }
}
