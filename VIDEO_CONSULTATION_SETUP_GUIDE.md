# Video Consultation Feature - Setup & Usage Guide
**Date:** May 8, 2026  
**Status:** Ready to Use

---

## 🚀 Quick Start

### Backend Already Deployed
Backend is already deployed on Vercel:
```
https://icare-backend-inky.vercel.app/api
```

### Frontend Already Configured
API base URL is already set in `lib/utils/api_constants.dart`:
```dart
static const String baseUrl = 'https://icare-backend-inky.vercel.app/api';
```

---

## 📱 How to Use in Your App

### 1. Start Consultation from Appointment

Replace your existing video call start code with:

```dart
import 'package:icare/services/consultation_service.dart';
import 'package:icare/screens/consultation_chat_screen_v2.dart';

// In your appointment screen
final consultationService = ConsultationService();

// Start consultation
final result = await consultationService.startConsultationV2(
  appointmentId: appointment.id!,
  patientId: appointment.patientId!,
  doctorId: appointment.doctorId!,
  reason: 'Video consultation',
);

if (result['success'] == true) {
  final consultationId = result['consultationId'];
  
  // Navigate to chat screen
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ConsultationChatScreenV2(
        consultationId: consultationId,
        appointment: appointment,
        isDoctor: true, // or false for patient
        currentUserId: currentUser.id!,
        currentUserName: currentUser.name!,
      ),
    ),
  );
} else {
  // Show error
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(result['message'] ?? 'Failed to start consultation')),
  );
}
```

### 2. Chat Screen Features

The chat screen (`ConsultationChatScreenV2`) includes:
- ✅ Auto-send consent message
- ✅ Timer (10 min minimum, 30 min maximum)
- ✅ Send/receive messages
- ✅ Attachment support
- ✅ Voice call button
- ✅ Video call button
- ✅ Prescription button (doctor only)
- ✅ End consultation button

### 3. Prescription Form

Doctor can open prescription form from chat screen:
- ✅ 9 tabs (History, SOAP, Doctor Notes, Diagnosis, Medications, Lab Tests, Lifestyle Advice, Referral, Courses)
- ✅ Save draft functionality
- ✅ Complete prescription
- ✅ Cannot end consultation without completing

### 4. Patient History Form

Doctor can fill patient history from prescription form:
- ✅ 10 comprehensive sections
- ✅ Page-by-page navigation
- ✅ Progress tracking
- ✅ Auto-save

---

## 🔧 Integration Points

### Where to Replace Old Code

#### 1. In Appointment Details Screen
**File:** `lib/screens/appointment_details_screen.dart` (or similar)

**OLD CODE (Remove this):**
```dart
// Old direct video call
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => VideoCallScreen(...),
  ),
);
```

**NEW CODE (Use this):**
```dart
// New chat-first consultation
final result = await ConsultationService().startConsultationV2(
  appointmentId: appointment.id!,
  patientId: appointment.patientId!,
  doctorId: appointment.doctorId!,
);

if (result['success'] == true) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ConsultationChatScreenV2(
        consultationId: result['consultationId'],
        appointment: appointment,
        isDoctor: isDoctor,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
      ),
    ),
  );
}
```

#### 2. In Doctor Dashboard
**File:** `lib/screens/doctor_dashboard.dart` (or similar)

Add button to start consultation:
```dart
ElevatedButton(
  onPressed: () async {
    // Start consultation
    final result = await ConsultationService().startConsultationV2(
      appointmentId: appointment.id!,
      patientId: appointment.patientId!,
      doctorId: currentUser.id!,
    );
    
    if (result['success'] == true) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConsultationChatScreenV2(
            consultationId: result['consultationId'],
            appointment: appointment,
            isDoctor: true,
            currentUserId: currentUser.id!,
            currentUserName: currentUser.name!,
          ),
        ),
      );
    }
  },
  child: Text('Start Consultation'),
)
```

#### 3. In Patient Dashboard
**File:** `lib/screens/patient_dashboard.dart` (or similar)

Add button to join consultation:
```dart
ElevatedButton(
  onPressed: () {
    // Join existing consultation
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConsultationChatScreenV2(
          consultationId: appointment.consultationId!,
          appointment: appointment,
          isDoctor: false,
          currentUserId: currentUser.id!,
          currentUserName: currentUser.name!,
        ),
      ),
    );
  },
  child: Text('Join Consultation'),
)
```

---

## 📊 API Endpoints Being Used

All these endpoints are already deployed and working:

### Consultation Endpoints
```
POST   /consultations-v2/start-v2
POST   /consultations-v2/:id/messages
GET    /consultations-v2/:id/messages
POST   /consultations-v2/:id/end
GET    /consultations-v2/:id
GET    /consultations-v2/:id/timer
```

### Prescription Endpoints
```
POST   /prescriptions-v2/consultations/:id/prescription/draft
GET    /prescriptions-v2/consultations/:id/prescription/draft
POST   /prescriptions-v2/consultations/:id/prescription/complete
GET    /prescriptions-v2/prescriptions/:id
GET    /prescriptions-v2/patients/:id/prescriptions
```

### Patient History Endpoints
```
POST   /patient-history/create
GET    /patient-history/patient/:id
GET    /patient-history/consultation/:id
GET    /patient-history/patient/:id/latest
```

### Lifestyle Advice Endpoints
```
GET    /lifestyle-advice/templates
POST   /lifestyle-advice/create
GET    /lifestyle-advice/consultation/:id
```

---

## ✅ What's Already Done

### Backend ✅
- All models created
- All controllers implemented
- All routes registered
- Deployed on Vercel
- Database connected

### Frontend ✅
- All models created
- All screens created
- Service methods updated
- API endpoints configured

### What You Need to Do
1. Replace old video call navigation with new chat screen
2. Test the flow
3. Fix any UI issues

---

## 🧪 Testing Steps

### 1. Test Consultation Start
```dart
// In your appointment screen
final result = await ConsultationService().startConsultationV2(
  appointmentId: 'test_appointment_id',
  patientId: 'test_patient_id',
  doctorId: 'test_doctor_id',
);

print('Result: $result');
// Should print: {success: true, consultationId: '...'}
```

### 2. Test Message Send
```dart
final result = await ConsultationService().sendMessageV2(
  consultationId: 'consultation_id',
  senderId: 'user_id',
  senderName: 'Dr. Ahmed',
  senderRole: 'doctor',
  message: 'Hello',
);

print('Result: $result');
// Should print: {success: true, messageId: '...'}
```

### 3. Test Prescription Save
```dart
final result = await ConsultationService().savePrescriptionDraft(
  consultationId: 'consultation_id',
  prescriptionData: {
    'doctorNotes': 'Test notes',
    'diagnoses': [],
    'medicines': [],
  },
);

print('Result: $result');
// Should print: {success: true, prescriptionId: '...'}
```

---

## 🐛 Troubleshooting

### Issue 1: "Failed to start consultation"
**Solution:** Check if appointment, patient, and doctor IDs are valid

### Issue 2: "Network error"
**Solution:** Check internet connection and backend URL

### Issue 3: "Unauthorized"
**Solution:** Check if user token is valid in SharedPreferences

### Issue 4: "Consultation not found"
**Solution:** Make sure consultation was created successfully before sending messages

---

## 📞 Support

If you face any issues:
1. Check backend logs on Vercel
2. Check Flutter console for errors
3. Verify API endpoints are correct
4. Test with Postman first

---

## 🎯 Next Steps

1. **Replace old video call code** with new chat screen
2. **Test complete flow** from appointment to prescription
3. **Fix any UI issues** in the screens
4. **Add error handling** where needed
5. **Test with real users**

---

**Status:** ✅ Ready to Use  
**Backend:** ✅ Deployed  
**Frontend:** ✅ Configured  
**Integration:** ⏳ Needs your action  

---

**Prepared By:** AI Development Team  
**Date:** May 8, 2026
