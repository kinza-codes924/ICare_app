import 'api_service.dart';

class AgoraService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> getToken({
    required String channelName,
    int uid = 0,
  }) async {
    try {
      final response = await _apiService.get(
        '/agora/token',
        queryParameters: {'channelName': channelName, 'uid': uid},
      );
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
