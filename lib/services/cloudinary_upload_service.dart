import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:icare/services/api_service.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CLOUDINARY UPLOAD SERVICE
// Handles direct video upload to Cloudinary for LMS session recordings.
// Uses the backend `/upload/sign` endpoint to get a signed upload token,
// then uploads the video blob directly to Cloudinary's API.
//
// Cloud name: dzlcnyxgb (hardcoded for verification)
// Resource type: video
// ─────────────────────────────────────────────────────────────────────────────

class CloudinaryUploadService {
  static const String cloudName = 'dzlcnyxgb';
  static const String backendUrl = 'https://icare.com.co/api';

  final ApiService _api = ApiService();

  /// Upload a video blob to Cloudinary using a signed upload token from backend.
  ///
  /// Returns the secure URL of the uploaded video, or null on failure.
  /// Throws a descriptive error message that can be shown to the user.
  Future<String?> uploadVideo({
    required List<int> videoBytes,
    required String fileName,
    required String sessionId,
  }) async {
    try {
      // ── STEP 1: Get signed upload token from backend ───────────────────
      // The backend signs { timestamp, folder } with the API secret.
      // We explicitly request resource_type=video so the backend includes
      // it in the signature parameters.
      final token = await SharedPref().getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please log in again.');
      }

      debugPrint('☁️ Cloudinary: Getting signed upload token...');
      final signUri = Uri.parse(
        '$backendUrl/upload/sign?folder=icare%2Flms-recordings&resource_type=video',
      );
      final signResponse = await http.get(
        signUri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (signResponse.statusCode != 200) {
        throw Exception(
          'Failed to get upload signature (HTTP ${signResponse.statusCode}): '
          '${signResponse.body}',
        );
      }

      final signData = jsonDecode(signResponse.body);
      if (signData['success'] != true || signData['cloud_name'] == null) {
        throw Exception(
          'Cloudinary signature response is missing required fields: '
          '${signData.toString()}',
        );
      }

      final apiKey = signData['api_key'] as String;
      final signature = signData['signature'] as String;
      final timestamp = signData['timestamp'].toString();
      final folder = signData['folder'] as String;
      final cloudName = signData['cloud_name'] as String;

      debugPrint('☁️ Cloudinary: Signature obtained for cloud=$cloudName');

      // ── STEP 2: Upload directly to Cloudinary ──────────────────────────
      // Use multipart/form-data upload to Cloudinary's REST API.
      // Include all required signed fields: api_key, timestamp, signature, folder.
      // Resource type is embedded in the URL path: /video/upload
      final uploadUri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/video/upload',
      );

      final request = http.MultipartRequest('POST', uploadUri);

      // Add the video file
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        videoBytes,
        filename: fileName,
      );
      request.files.add(multipartFile);

      // Add signed parameters (these are MANDATORY for signed uploads)
      request.fields['api_key'] = apiKey;
      request.fields['timestamp'] = timestamp;
      request.fields['signature'] = signature;
      request.fields['folder'] = folder;
      // DO NOT add upload_preset for signed uploads - it will cause a 401

      debugPrint(
        '☁️ Cloudinary: Uploading video (${videoBytes.length} bytes)...',
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        // Parse Cloudinary error for better diagnostics
        String errorDetail;
        try {
          final errorData = jsonDecode(response.body);
          errorDetail = errorData['error']?['message'] ?? response.body;
        } catch (_) {
          errorDetail = response.body;
        }
        throw Exception(
          'Cloudinary upload failed (HTTP ${response.statusCode}): $errorDetail',
        );
      }

      final uploadData = jsonDecode(response.body);
      final secureUrl = uploadData['secure_url'] as String?;

      if (secureUrl == null || secureUrl.isEmpty) {
        throw Exception(
          'Cloudinary upload succeeded but no secure_url in response: '
          '${uploadData.toString()}',
        );
      }

      debugPrint('☁️ Cloudinary: Upload successful! URL: $secureUrl');

      // ── STEP 3: Save URL to backend session record ─────────────────────
      await _saveRecordingUrl(sessionId, secureUrl, token);

      return secureUrl;
    } catch (e) {
      debugPrint('❌ Cloudinary upload error: $e');
      rethrow;
    }
  }

  /// Upload a video blob using an unsigned upload preset.
  /// Use this if the signed upload fails.
  /// Requires an upload preset to be configured in your Cloudinary dashboard.
  Future<String?> uploadVideoUnsigned({
    required List<int> videoBytes,
    required String fileName,
    required String sessionId,
    String uploadPreset = 'icare_lms_recordings',
  }) async {
    try {
      debugPrint('☁️ Cloudinary (unsigned): Uploading video...');

      final uploadUri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/video/upload',
      );

      final request = http.MultipartRequest('POST', uploadUri);

      // Add the video file
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        videoBytes,
        filename: fileName,
      );
      request.files.add(multipartFile);

      // Unsigned upload requires upload_preset
      request.fields['upload_preset'] = uploadPreset;

      debugPrint(
        '☁️ Cloudinary (unsigned): Uploading video (${videoBytes.length} bytes)...',
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        String errorDetail;
        try {
          final errorData = jsonDecode(response.body);
          errorDetail = errorData['error']?['message'] ?? response.body;
        } catch (_) {
          errorDetail = response.body;
        }
        throw Exception(
          'Cloudinary unsigned upload failed (HTTP ${response.statusCode}): '
          '$errorDetail',
        );
      }

      final uploadData = jsonDecode(response.body);
      final secureUrl = uploadData['secure_url'] as String?;

      if (secureUrl == null || secureUrl.isEmpty) {
        throw Exception(
          'Cloudinary unsigned upload succeeded but no secure_url in response: '
          '${uploadData.toString()}',
        );
      }

      debugPrint('☁️ Cloudinary (unsigned): Upload successful! URL: $secureUrl');

      // Save URL to backend session record
      final token = await SharedPref().getToken();
      if (token != null && token.isNotEmpty) {
        await _saveRecordingUrl(sessionId, secureUrl, token);
      }

      return secureUrl;
    } catch (e) {
      debugPrint('❌ Cloudinary unsigned upload error: $e');
      rethrow;
    }
  }

  /// Save the recording URL to the live session document in MongoDB.
  Future<void> _saveRecordingUrl(
    String sessionId,
    String recordingUrl,
    String authToken,
  ) async {
    try {
      final saveUri = Uri.parse(
        '$backendUrl/live-sessions/$sessionId/set-recording-url',
      );
      final saveResponse = await http.patch(
        saveUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'recordingUrl': recordingUrl}),
      );
      if (saveResponse.statusCode == 200) {
        debugPrint('☁️ Cloudinary: Recording URL saved to session $sessionId');
      } else {
        debugPrint(
          '⚠️ Cloudinary: Failed to save recording URL (HTTP ${saveResponse.statusCode})',
        );
      }
    } catch (e) {
      debugPrint('⚠️ Cloudinary: Error saving recording URL: $e');
      // Non-fatal - the recording is already on Cloudinary
    }
  }

  /// Verify the Cloudinary configuration by testing the sign endpoint.
  /// Returns a map with { cloud_name, api_key } if successful.
  /// Throws if the configuration is invalid.
  Future<Map<String, dynamic>> verifyConfiguration() async {
    final token = await SharedPref().getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    final signUri = Uri.parse(
      '$backendUrl/upload/sign?folder=icare%2Fverify&resource_type=video',
    );
    final response = await http.get(
      signUri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Cloudinary configuration verification failed (HTTP ${response.statusCode}): '
        '${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    if (data['success'] != true) {
      throw Exception(
        'Cloudinary configuration verification failed: ${data.toString()}',
      );
    }

    return {
      'cloud_name': data['cloud_name'],
      'api_key': data['api_key'],
      'folder': data['folder'],
    };
  }
}