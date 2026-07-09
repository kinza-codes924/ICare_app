# Frontend-Backend Integration Guide
**Date:** May 8, 2026  
**Purpose:** Connect Flutter frontend with Node.js backend

---

## 📋 Overview

This guide shows how to update the Flutter frontend to use the new backend API endpoints.

---

## 🔧 Update API Base URL

### lib/services/api_config.dart (or similar)
```dart
class ApiConfig {
  // Update this to your backend URL
  static const String baseUrl = 'http://localhost:5000/api';
  
  // Or for production
  // static const String baseUrl = 'https://your-backend.vercel.app/api';
  
  // V2 Endpoints
  static const String consultationsV2 = '$baseUrl/consultations-v2';
  static const String prescriptionsV2 = '$baseUrl/prescriptions-v2';
  static const String patientHistory = '$baseUrl/patient-history';
  static const String lifestyleAdvice = '$baseUrl/lifestyle-advice';
}
```

---

## 📝 Update Consultation Service

### lib/services/consultation_service.dart

Update the existing methods to use new endpoints:

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_config.dart';

class ConsultationService {
  // Start consultation
  Future<Map<String, dynamic>> startConsultation({
    required String appointmentId,
    required String patientId,
    required String doctorId,
    String? reason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.consultationsV2}/start-v2'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'appointmentId': appointmentId,
          'patientId': patientId,
          'doctorId': doctorId,
          'reason': reason ?? 'Video consultation',
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to start consultation');
      }
    } catch (e) {
      print('Error starting consultation: $e');
      rethrow;
    }
  }

  // Send message
  Future<Map<String, dynamic>> sendMessage({
    required String consultationId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String message,
    String? attachmentUrl,
    bool isSystemMessage = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.consultationsV2}/$consultationId/messages'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'senderId': senderId,
          'senderName': senderName,
          'senderRole': senderRole,
          'message': message,
          'attachmentUrl': attachmentUrl,
          'isSystemMessage': isSystemMessage,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to send message');
      }
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // Get messages
  Future<List<dynamic>> getMessages({
    required String consultationId,
    int limit = 100,
    int skip = 0,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.consultationsV2}/$consultationId/messages?limit=$limit&skip=$skip'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['messages'] ?? [];
      } else {
        throw Exception('Failed to get messages');
      }
    } catch (e) {
      print('Error getting messages: $e');
      rethrow;
    }
  }

  // End consultation
  Future<Map<String, dynamic>> endConsultation({
    required String consultationId,
    required int duration,
    String? prescriptionId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.consultationsV2}/$consultationId/end'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'duration': duration,
          'prescriptionId': prescriptionId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to end consultation');
      }
    } catch (e) {
      print('Error ending consultation: $e');
      rethrow;
    }
  }

  // Get timer status
  Future<Map<String, dynamic>> getTimerStatus({
    required String consultationId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.consultationsV2}/$consultationId/timer'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get timer status');
      }
    } catch (e) {
      print('Error getting timer status: $e');
      rethrow;
    }
  }

  // Save prescription draft
  Future<Map<String, dynamic>> savePrescriptionDraft({
    required String consultationId,
    required Map<String, dynamic> prescriptionData,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.prescriptionsV2}/consultations/$consultationId/prescription/draft'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(prescriptionData),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to save prescription draft');
      }
    } catch (e) {
      print('Error saving prescription draft: $e');
      rethrow;
    }
  }

  // Get prescription draft
  Future<Map<String, dynamic>?> getPrescriptionDraft({
    required String consultationId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.prescriptionsV2}/consultations/$consultationId/prescription/draft'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['prescription'];
      } else {
        throw Exception('Failed to get prescription draft');
      }
    } catch (e) {
      print('Error getting prescription draft: $e');
      rethrow;
    }
  }

  // Complete prescription
  Future<Map<String, dynamic>> completePrescription({
    required String consultationId,
    required Map<String, dynamic> prescriptionData,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.prescriptionsV2}/consultations/$consultationId/prescription/complete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(prescriptionData),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to complete prescription');
      }
    } catch (e) {
      print('Error completing prescription: $e');
      rethrow;
    }
  }

  // Save patient history
  Future<Map<String, dynamic>> savePatientHistory({
    required Map<String, dynamic> historyData,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.patientHistory}/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(historyData),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to save patient history');
      }
    } catch (e) {
      print('Error saving patient history: $e');
      rethrow;
    }
  }

  // Get patient history
  Future<Map<String, dynamic>?> getPatientHistory({
    required String patientId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.patientHistory}/patient/$patientId/latest'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['history'];
      } else {
        throw Exception('Failed to get patient history');
      }
    } catch (e) {
      print('Error getting patient history: $e');
      rethrow;
    }
  }

  // Save lifestyle advice
  Future<Map<String, dynamic>> saveLifestyleAdvice({
    required String consultationId,
    required String prescriptionId,
    required Map<String, dynamic> lifestyleData,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.lifestyleAdvice}/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'consultationId': consultationId,
          'prescriptionId': prescriptionId,
          ...lifestyleData,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to save lifestyle advice');
      }
    } catch (e) {
      print('Error saving lifestyle advice: $e');
      rethrow;
    }
  }

  // Get lifestyle advice templates
  Future<Map<String, dynamic>> getLifestyleAdviceTemplates() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.lifestyleAdvice}/templates'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get lifestyle advice templates');
      }
    } catch (e) {
      print('Error getting lifestyle advice templates: $e');
      rethrow;
    }
  }
}
```

---

## 🧪 Testing the Integration

### 1. Start Backend Server
```bash
cd icare-backend
npm install
npm start
```

Backend should be running on `http://localhost:5000`

### 2. Test Endpoints with Postman

**Test 1: Start Consultation**
```
POST http://localhost:5000/api/consultations-v2/start-v2
Body: {
  "patientId": "your_patient_id",
  "doctorId": "your_doctor_id"
}
```

**Test 2: Send Message**
```
POST http://localhost:5000/api/consultations-v2/{consultationId}/messages
Body: {
  "senderId": "your_user_id",
  "senderName": "Dr. Ahmed",
  "senderRole": "doctor",
  "message": "Hello"
}
```

**Test 3: Get Lifestyle Templates**
```
GET http://localhost:5000/api/lifestyle-advice/templates
```

### 3. Test from Flutter App

Update your Flutter app's API base URL and test the consultation flow:

```dart
// In your consultation screen
final service = ConsultationService();

// Start consultation
final result = await service.startConsultation(
  appointmentId: appointment.id,
  patientId: patient.id,
  doctorId: doctor.id,
);

print('Consultation ID: ${result['consultationId']}');
```

---

## 🔍 Debugging Tips

### Check Backend Logs
```bash
# Backend will log all requests
# Look for errors in the console
```

### Check Network Requests in Flutter
```dart
// Add logging to see requests
print('Request URL: $url');
print('Request Body: $body');
print('Response: ${response.body}');
```

### Common Issues

**1. CORS Error**
- Backend already has CORS enabled
- If still getting errors, check the CORS configuration in `index.js`

**2. Connection Refused**
- Make sure backend is running
- Check the base URL is correct
- For Android emulator, use `http://10.0.2.2:5000` instead of `localhost`

**3. 404 Not Found**
- Check the endpoint URL is correct
- Make sure routes are registered in `index.js`

**4. 400 Bad Request**
- Check request body format
- Make sure all required fields are included
- Check field names match exactly

**5. 500 Internal Server Error**
- Check backend console for error details
- Check MongoDB is running
- Check database connection string

---

## 📱 Android Emulator Configuration

For Android emulator, use special IP address:

```dart
class ApiConfig {
  // For Android Emulator
  static const String baseUrl = 'http://10.0.2.2:5000/api';
  
  // For iOS Simulator
  // static const String baseUrl = 'http://localhost:5000/api';
  
  // For Real Device (use your computer's IP)
  // static const String baseUrl = 'http://192.168.1.100:5000/api';
}
```

---

## 🌐 Production Deployment

### Backend (Vercel)
1. Push code to GitHub
2. Connect to Vercel
3. Deploy automatically
4. Get production URL: `https://your-app.vercel.app`

### Frontend
Update API base URL to production:
```dart
static const String baseUrl = 'https://your-app.vercel.app/api';
```

---

## ✅ Integration Checklist

### Backend
- [ ] MongoDB running
- [ ] Backend server running
- [ ] All routes registered
- [ ] CORS enabled
- [ ] Environment variables set

### Frontend
- [ ] API base URL updated
- [ ] ConsultationService updated
- [ ] All methods implemented
- [ ] Error handling added
- [ ] Loading states added

### Testing
- [ ] Start consultation works
- [ ] Send message works
- [ ] Get messages works
- [ ] End consultation works
- [ ] Save prescription works
- [ ] Complete prescription works
- [ ] Save history works
- [ ] Save lifestyle advice works

---

## 🎉 Ready to Test!

Backend is complete and ready for integration. Follow this guide to connect your Flutter frontend with the backend API.

**Next Steps:**
1. Start backend server
2. Update Flutter API configuration
3. Test each endpoint
4. Handle errors appropriately
5. Add loading states
6. Test complete flow

---

**Prepared By:** AI Development Team  
**Date:** May 8, 2026  
**Status:** Ready for Integration Testing

