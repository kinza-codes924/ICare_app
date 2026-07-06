import 'package:flutter/foundation.dart';
import 'api_service.dart';
import '../utils/shared_pref.dart';

class CallService {
  final ApiService _api = ApiService();
  final SharedPref _sharedPref = SharedPref();

  Future<String?> _getToken() async {
    final token = await _sharedPref.getToken();
    if (token == null) debugPrint('❌ CallService: No authentication token found');
    return token;
  }

  Future<Map<String, dynamic>> initiateCall({
    required String receiverId,
    required String channelName,
    required String callerName,
    String callType = 'video',
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {};
      final response = await _api.post(
        '/call/initiate',
        {'receiverId': receiverId, 'channelName': channelName, 'callerName': callerName, 'callType': callType},
        token: token,
      );
      return (response.data as Map<String, dynamic>?) ?? {};
    } catch (e) {
      debugPrint('❌ Failed to initiate call: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>?> checkIncomingCall() async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final response = await _api.get('/call/incoming', token: token);
      final data = response.data as Map<String, dynamic>?;
      if (response.statusCode == 200 &&
          data?['success'] == true &&
          data?['hasIncomingCall'] == true) {
        return data!['signal'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error checking incoming call: $e');
      return null;
    }
  }

  Future<void> respondToCall(String signalId, String action) async {
    try {
      final token = await _getToken();
      if (token == null) return;
      await _api.post('/call/respond', {'signalId': signalId, 'action': action}, token: token);
    } catch (_) {}
  }

  Future<String?> checkOutgoingCallStatus(String signalId) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final response = await _api.get('/call/signal/$signalId', token: token);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map) return data['status']?.toString() ?? data['signal']?['status']?.toString();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> endCall(String channelName) async {
    try {
      final token = await _getToken();
      if (token == null) return;
      await _api.post('/call/end', {'channelName': channelName}, token: token);
    } catch (_) {}
  }
}
