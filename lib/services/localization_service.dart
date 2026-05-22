import 'package:icare/services/api_service.dart';

class LocalizationService {
  final ApiService _apiService = ApiService();

  // Localization (English & Urdu)
  Future<Map<String, String>> getTranslations(String lang) async {
    try {
      final response = await _apiService.get(
        '/localization/translations/$lang',
      );
      return Map<String, String>.from(response.data['translations'] ?? {});
    } catch (e) {
      return {};
    }
  }

  // Voice Commands (Placeholder)
  Future<String> processVoiceCommand(String audioData) async {
    final response = await _apiService.post('/communication/voice-to-text', {
      'audio': audioData,
    });
    return response.data['text'] ?? '';
  }

  // Multi-language Preferences
  Future<void> updateLanguagePreference(String lang) async {
    await _apiService.put('/user/language', {'lang': lang});
  }
}
