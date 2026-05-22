import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:icare/utils/api_constants.dart';
import 'package:icare/utils/shared_pref.dart';

class ConsultationService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));
  final SharedPref _sharedPref = SharedPref();

  // ==================== V2 CONSULTATION ENDPOINTS ====================
  
  // Start consultation with appointment (V2)
  Future<Map<String, dynamic>> startConsultationV2({
    required String appointmentId,
    required String patientId,
    required String doctorId,
    String? reason,
    String? channelName,
  }) async {
    try {
      final token = await _sharedPref.getToken();
      // Only send appointmentId if it's a valid 24-char MongoDB ObjectId
      final bool validApptId = appointmentId.length == 24 &&
          RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(appointmentId);
      final response = await _dio.post(
        '/consultations-v2/start-v2',
        data: {
          if (validApptId) 'appointmentId': appointmentId,
          'patientId': patientId,
          'doctorId': doctorId,
          if (reason != null) 'reason': reason,
          if (channelName != null) 'channelName': channelName,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {'success': false, 'message': 'Unexpected response format'};
    } on DioException catch (e) {
      final data = e.response?.data;
      String msg = e.message ?? 'Network error';
      if (data is Map<String, dynamic>) {
        msg = data['message']?.toString() ?? msg;
      } else if (data is String && data.isNotEmpty) {
        msg = data.length > 100 ? msg : data;
      }
      print('Error starting consultation: $msg');
      return {'success': false, 'message': msg};
    } catch (e) {
      print('Unexpected error starting consultation: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Send message (V2)
  Future<Map<String, dynamic>> sendMessageV2({
    required String consultationId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String message,
    String? attachmentUrl,
    bool isSystemMessage = false,
  }) async {
    try {
      print('📤 SENDING MESSAGE:');
      print('  consultationId: $consultationId');
      print('  senderId: $senderId');
      print('  senderName: $senderName');
      print('  senderRole: $senderRole');
      print('  message: $message');

      final token = await _sharedPref.getToken();
      final response = await _dio.post(
        '/consultations-v2/$consultationId/messages',
        data: {
          'senderId': senderId,
          'senderName': senderName,
          'senderRole': senderRole,
          'message': message,
          if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
          'isSystemMessage': isSystemMessage,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      print('✅ MESSAGE SENT SUCCESSFULLY: ${response.data}');
      return response.data;
    } on DioException catch (e) {
      print('❌ ERROR SENDING MESSAGE: ${e.message}');
      print('❌ Response: ${e.response?.data}');
      return {'success': false, 'message': e.response?.data['message'] ?? e.message};
    }
  }

  // Get messages (V2)
  Future<List<dynamic>> getMessagesV2({
    required String consultationId,
    int limit = 100,
    int skip = 0,
  }) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.get(
        '/consultations-v2/$consultationId/messages?limit=$limit&skip=$skip',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      print('📥 GET MESSAGES RESPONSE:');
      print('  consultationId: $consultationId');
      print('  success: ${response.data['success']}');
      print('  message count: ${response.data['messages']?.length ?? 0}');
      if (response.data['success'] == true) {
        return response.data['messages'] ?? [];
      }
      return [];
    } on DioException catch (e) {
      print('❌ ERROR GETTING MESSAGES: ${e.message}');
      print('❌ Response: ${e.response?.data}');
      return [];
    }
  }

  // End consultation (V2)
  Future<Map<String, dynamic>> endConsultationV2({
    required String consultationId,
    required int duration,
    String? prescriptionId,
  }) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.post(
        '/consultations-v2/$consultationId/end',
        data: {
          'duration': duration,
          if (prescriptionId != null) 'prescriptionId': prescriptionId,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      print('Error ending consultation: ${e.message}');
      return {'success': false, 'message': e.response?.data['message'] ?? e.message};
    }
  }

  // Get consultation details (V2)
  Future<Map<String, dynamic>> getConsultationV2(String consultationId) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.get(
        '/consultations-v2/$consultationId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      print('Error getting consultation: ${e.message}');
      return {'success': false, 'message': e.response?.data['message'] ?? e.message};
    }
  }

  // Get consultation by appointment ID (direct lookup)
  Future<Map<String, dynamic>> getConsultationByAppointmentId(String appointmentId) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.get(
        '/consultations-v2/by-appointment/$appointmentId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      print('Error getting consultation by appointment: ${e.message}');
      return {'success': false, 'message': e.response?.data['message'] ?? e.message};
    }
  }

  // Get consultation by appointment ID
  // Directly calls startConsultationV2 — backend returns existing session if already started
  Future<Map<String, dynamic>> getConsultationByAppointment(
    String appointmentId, {
    String patientId = '',
    String doctorId = '',
  }) async {
    if (patientId.isEmpty || doctorId.isEmpty) {
      return {'success': false, 'message': 'Missing patient or doctor ID'};
    }
    return startConsultationV2(
      appointmentId: appointmentId,
      patientId: patientId,
      doctorId: doctorId,
    );
  }

  // Get timer status (V2)
  Future<Map<String, dynamic>> getTimerStatus(String consultationId) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.get(
        '/consultations-v2/$consultationId/timer',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      print('Error getting timer status: ${e.message}');
      return {'success': false, 'message': e.response?.data['message'] ?? e.message};
    }
  }

  // ==================== PRESCRIPTION V2 ENDPOINTS ====================

  // Save prescription draft
  Future<Map<String, dynamic>> savePrescriptionDraft({
    required String consultationId,
    required Map<String, dynamic> prescriptionData,
  }) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.post(
        '/prescriptions-v2/consultations/$consultationId/prescription/draft',
        data: prescriptionData,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (s) => s != null && s < 600,
        ),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      return {'success': response.statusCode != null && response.statusCode! < 300};
    } on DioException catch (e) {
      return {'success': false, 'message': e.message ?? 'Draft save failed'};
    }
  }

  // Get prescription draft
  Future<Map<String, dynamic>?> getPrescriptionDraft(String consultationId) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.get(
        '/prescriptions-v2/consultations/$consultationId/prescription/draft',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.data['success'] == true) {
        return response.data['prescription'];
      }
      return null;
    } on DioException catch (e) {
      print('Error getting prescription draft: ${e.message}');
      return null;
    }
  }

  // Complete prescription — uses http package directly (bypasses Dio JSON parsing issues)
  Future<Map<String, dynamic>> completePrescription({
    required String consultationId,
    required Map<String, dynamic> prescriptionData,
  }) async {
    try {
      final token = await _sharedPref.getToken();
      final url = Uri.parse('${ApiConstants.baseUrl}/prescriptions-v2/consultations/$consultationId/prescription/complete');
      final body = jsonEncode(prescriptionData);

      print('📋 PRESCRIPTION COMPLETE → $url');
      print('📋 Body: $body');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: body,
      ).timeout(const Duration(seconds: 30));

      print('📋 STATUS: ${response.statusCode}');
      print('📋 BODY: ${response.body}');

      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) return data;
        final msg = data['message']?.toString() ?? data['error']?.toString() ?? 'Server error ${response.statusCode}';
        return {'success': false, 'message': msg};
      } catch (_) {
        if (response.statusCode < 300) return {'success': true};
        return {'success': false, 'message': 'Server error ${response.statusCode}: ${response.body.substring(0, response.body.length.clamp(0, 200))}'};
      }
    } catch (e) {
      print('❌ PRESCRIPTION COMPLETE ERROR: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Get prescription by ID
  Future<Map<String, dynamic>?> getPrescription(String prescriptionId) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.get(
        '/prescriptions-v2/prescriptions/$prescriptionId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.data['success'] == true) {
        return response.data['prescription'];
      }
      return null;
    } on DioException catch (e) {
      print('Error getting prescription: ${e.message}');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getPrescriptionByConsultation(String consultationId) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.get(
        '/prescriptions-v2/consultations/$consultationId/prescription/completed',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.data['success'] == true) {
        return response.data['prescription'];
      }
      return null;
    } on DioException catch (e) {
      print('Error getting prescription by consultation: ${e.message}');
      return null;
    }
  }

  // Get patient prescriptions
  Future<List<dynamic>> getPatientPrescriptions({
    required String patientId,
    String? status,
    int limit = 20,
    int skip = 0,
  }) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.get(
        '/prescriptions-v2/patients/$patientId/prescriptions?limit=$limit&skip=$skip${status != null ? '&status=$status' : ''}',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.data['success'] == true) {
        return response.data['prescriptions'] ?? [];
      }
      return [];
    } on DioException catch (e) {
      print('Error getting patient prescriptions: ${e.message}');
      return [];
    }
  }

  // ==================== PATIENT HISTORY ENDPOINTS ====================

  // Save patient history
  Future<Map<String, dynamic>> savePatientHistory({
    required Map<String, dynamic> historyData,
  }) async {
    try {
      print('📋 SAVING PATIENT HISTORY:');
      print('  patientId: ${historyData['patientId']}');
      print('  consultationId: ${historyData['consultationId']}');
      print('  doctorId: ${historyData['doctorId']}');
      print('  Data keys: ${historyData.keys.toList()}');

      final token = await _sharedPref.getToken();
      print('  Token: ${token?.substring(0, 20)}...');

      // Clean null values before sending — avoids backend 500
      final cleanData = _removeNulls(historyData);

      final response = await _dio.post(
        '/patient-history/create',
        data: cleanData,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (s) => s != null && s < 600,
        ),
      );

      print('✅ PATIENT HISTORY SAVE RESPONSE: ${response.statusCode}');
      print('  Data: ${response.data}');

      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data['success'] == true) return data;
        final msg = data['message']?.toString() ?? data['error']?.toString() ?? 'Save failed (${response.statusCode})';
        return {'success': false, 'message': msg};
      }
      if (response.statusCode != null && response.statusCode! < 300) return {'success': true};
      return {'success': false, 'message': 'Server error ${response.statusCode}'};
    } on DioException catch (e) {
      print('❌ ERROR SAVING PATIENT HISTORY: ${e.message}');
      String message = e.message ?? 'Network error';
      try {
        final data = e.response?.data;
        if (data is Map) {
          message = data['message']?.toString() ?? data['error']?.toString() ?? message;
        } else if (data is String && data.isNotEmpty && data.length < 300) {
          message = data;
        }
      } catch (_) {}
      return {'success': false, 'message': message};
    } catch (e) {
      print('❌ UNEXPECTED ERROR SAVING PATIENT HISTORY: $e');
      return {'success': false, 'message': 'Unexpected error: $e'};
    }
  }

  // Get patient history
  Future<List<dynamic>> getPatientHistory({
    required String patientId,
    int limit = 10,
    int skip = 0,
  }) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.get(
        '/patient-history/patient/$patientId?limit=$limit&skip=$skip',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.data['success'] == true) {
        return response.data['histories'] ?? [];
      }
      return [];
    } on DioException catch (e) {
      print('Error getting patient history: ${e.message}');
      return [];
    }
  }

  // Get history by consultation
  Future<Map<String, dynamic>?> getHistoryByConsultation(String consultationId) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.get(
        '/patient-history/consultation/$consultationId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.data['success'] == true) {
        return response.data['history'];
      }
      return null;
    } on DioException catch (e) {
      print('Error getting history by consultation: ${e.message}');
      return null;
    }
  }

  // Get latest history
  Future<Map<String, dynamic>?> getLatestHistory(String patientId) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.get(
        '/patient-history/patient/$patientId/latest',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.data['success'] == true) {
        return response.data['history'];
      }
      return null;
    } on DioException catch (e) {
      print('Error getting latest history: ${e.message}');
      return null;
    }
  }

  // ==================== LIFESTYLE ADVICE ENDPOINTS ====================

  // Get lifestyle advice templates
  Future<Map<String, dynamic>> getLifestyleAdviceTemplates() async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.get(
        '/lifestyle-advice/templates',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      print('Error getting lifestyle advice templates: ${e.message}');
      return {'success': false, 'message': e.response?.data['message'] ?? e.message};
    }
  }

  // Save lifestyle advice
  Future<Map<String, dynamic>> saveLifestyleAdvice({
    required String consultationId,
    required String prescriptionId,
    required Map<String, dynamic> lifestyleData,
  }) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.post(
        '/lifestyle-advice/create',
        data: {
          'consultationId': consultationId,
          'prescriptionId': prescriptionId,
          ...lifestyleData,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      print('Error saving lifestyle advice: ${e.message}');
      return {'success': false, 'message': e.response?.data['message'] ?? e.message};
    }
  }

  // Get lifestyle advice by consultation
  Future<Map<String, dynamic>?> getLifestyleAdviceByConsultation(String consultationId) async {
    try {
      final token = await _sharedPref.getToken();
      final response = await _dio.get(
        '/lifestyle-advice/consultation/$consultationId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.data['success'] == true) {
        return response.data['advice'];
      }
      return null;
    } on DioException catch (e) {
      print('Error getting lifestyle advice: ${e.message}');
      return null;
    }
  }

  // ==================== FILE UPLOAD ====================

  // Upload attachment — mobile/desktop (file path)
  Future<Map<String, dynamic>> uploadAttachment(String filePath) async {
    try {
      final token = await _sharedPref.getToken();
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post(
        '/upload',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      // Backend may return {url: '...'} directly without success flag
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return {'success': false, 'message': 'Unexpected response'};
    } on DioException catch (e) {
      final serverMsg = (e.response?.data is Map) ? (e.response!.data as Map)['message'] : null;
      return {'success': false, 'message': serverMsg?.toString() ?? e.message ?? 'Upload failed'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Upload attachment — web (bytes, no file path)
  Future<Map<String, dynamic>> uploadAttachmentBytes({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final token = await _sharedPref.getToken();
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: fileName),
      });
      final response = await _dio.post(
        '/upload',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return {'success': false, 'message': 'Unexpected response'};
    } on DioException catch (e) {
      final serverMsg = (e.response?.data is Map) ? (e.response!.data as Map)['message'] : null;
      return {'success': false, 'message': serverMsg?.toString() ?? e.message ?? 'Upload failed'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== COMPATIBILITY WRAPPERS ====================
  // Used by older screens that haven't been updated to V2 signatures yet.

  Future<Map<String, dynamic>> sendMessage({
    required String consultationId,
    required String message,
    String? attachmentUrl,
  }) async {
    final user = await _sharedPref.getUserData();
    return sendMessageV2(
      consultationId: consultationId,
      senderId: user?.id ?? '',
      senderName: user?.name ?? 'User',
      senderRole: user?.role ?? 'unknown',
      message: message,
      attachmentUrl: attachmentUrl,
    );
  }

  Future<Map<String, dynamic>> getMessages(String consultationId) async {
    final messages = await getMessagesV2(consultationId: consultationId);
    return {'success': true, 'messages': messages};
  }

  Future<Map<String, dynamic>> endConsultation(String consultationId) async {
    return endConsultationV2(consultationId: consultationId, duration: 0);
  }

  /// Recursively remove null values to prevent backend 500 errors
  Map<String, dynamic> _removeNulls(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    map.forEach((key, value) {
      if (value == null) return;
      if (value is Map<String, dynamic>) {
        final clean = _removeNulls(value);
        if (clean.isNotEmpty) result[key] = clean;
      } else if (value is List) {
        result[key] = value.map((item) => item is Map<String, dynamic> ? _removeNulls(item) : item).toList();
      } else {
        result[key] = value;
      }
    });
    return result;
  }
}
