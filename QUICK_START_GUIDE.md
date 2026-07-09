# iCare Video Consultation - Quick Start Guide

## 🚀 How to Use the New Consultation Flow

### For Developers

#### 1. Starting a Consultation (Chat-First)

**Old Way:**
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => VideoCall(...),  // Direct video call
  ),
);
```

**New Way:**
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => ConsultationChatScreenV2(
      appointment: appointment,
      isDoctor: true,  // or false for patient
      currentUserId: userId,
      currentUserName: userName,
    ),
  ),
);
```

#### 2. Opening Prescription Form

From within the chat screen, the prescription button automatically opens:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => InConsultationPrescriptionForm(
      appointment: appointment,
      consultationId: consultationId,
      onPrescriptionComplete: (isComplete) {
        // Update state
      },
    ),
  ),
);
```

#### 3. Accessing Patient History

From prescription form, history button opens:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => PatientHistoryFormScreen(
      appointment: appointment,
      consultationId: consultationId,
      onHistoryComplete: (historyId) {
        // Save history ID
      },
    ),
  ),
);
```

### For Backend Developers

#### Required API Endpoints

**1. Start Consultation**
```
POST /consultations/start-v2
Body: {
  "appointmentId": "string",
  "patientId": "string",
  "doctorId": "string"
}
Response: {
  "success": true,
  "consultationId": "string"
}
```

**2. Send Message**
```
POST /consultations/:consultationId/messages
Body: {
  "message": "string",
  "attachmentUrl": "string (optional)",
  "isSystemMessage": boolean
}
Response: {
  "success": true,
  "messageId": "string"
}
```

**3. Get Messages**
```
GET /consultations/:consultationId/messages
Response: {
  "success": true,
  "messages": [
    {
      "id": "string",
      "senderId": "string",
      "message": "string",
      "timestamp": "ISO8601",
      "isSystemMessage": boolean,
      "attachmentUrl": "string (optional)"
    }
  ]
}
```

**4. Save Prescription Draft**
```
POST /consultations/:consultationId/prescription/draft
Body: {
  // EnhancedPrescription JSON
}
Response: {
  "success": true,
  "prescriptionId": "string"
}
```

**5. Complete Prescription**
```
POST /consultations/:consultationId/prescription/complete
Body: {
  // EnhancedPrescription JSON with isComplete: true
}
Response: {
  "success": true,
  "prescriptionId": "string"
}
```

**6. End Consultation**
```
POST /consultations/:consultationId/end
Response: {
  "success": true,
  "duration": number (seconds),
  "prescriptionId": "string"
}
```

**7. Save Patient History**
```
POST /patient-history/create
Body: {
  // PatientHistoryForm JSON
}
Response: {
  "success": true,
  "historyId": "string"
}
```

**8. Save Lifestyle Advice**
```
POST /lifestyle-advice/create
Body: {
  "consultationId": "string",
  // LifestyleAdvice JSON
}
Response: {
  "success": true,
  "adviceId": "string"
}
```

## 📱 User Flow

### Doctor's Perspective

1. **Start Consultation**
   - Click "Start Consultation" on appointment
   - Chat screen opens
   - Consent message auto-sends
   - Timer starts

2. **During Consultation**
   - Chat with patient
   - Click voice/video call if needed
   - Click "Prescription" button
   - Fill prescription form (9 tabs)
   - Save draft anytime
   - Complete prescription

3. **End Consultation**
   - Click "End Consultation"
   - System checks:
     - ✅ Minimum 10 minutes passed?
     - ✅ Prescription completed?
   - Confirm end
   - Consultation ends

### Patient's Perspective

1. **Join Consultation**
   - Receive notification
   - Click "Join Consultation"
   - Chat screen opens
   - See doctor's consent message

2. **During Consultation**
   - Chat with doctor
   - Accept voice/video call if doctor initiates
   - Wait for prescription

3. **After Consultation**
   - Receive prescription
   - View prescription (30-day active window)
   - Order medicines/lab tests

## 🎯 Key Features

### Timer Management
```dart
// Timer automatically:
- Starts when consultation begins
- Shows warning at 28 minutes
- Auto-ends at 30 minutes
- Prevents ending before 10 minutes
```

### Prescription Validation
```dart
// Cannot end consultation if:
- Prescription not completed (doctor only)
- Less than 10 minutes elapsed
- Prescription validation fails
```

### Message Types
```dart
// System messages (blue background):
- Consent message
- Consultation started/ended
- Prescription completed

// User messages (white/purple):
- Regular chat messages
- Attachments
```

## 🔧 Configuration

### Timer Settings
```dart
// In ConsultationTimer class
static const Duration minDuration = Duration(minutes: 10);
static const Duration maxDuration = Duration(minutes: 30);
static const Duration warningBeforeEnd = Duration(minutes: 2);
```

### Prescription Active Window
```dart
// In EnhancedPrescription class
bool get isWithinActiveWindow {
  final daysSincePrescribed = now.difference(prescribedAt).inDays;
  return daysSincePrescribed <= 30;  // 30-day window
}
```

## 🎨 Customization

### Colors
```dart
// Timer colors
- Orange: Below minimum
- Green: Normal range
- Red: Near/at maximum

// Button colors
- Primary: AppColors.primaryColor (purple)
- Success: Colors.green
- Danger: Colors.red
```

### Icons
```dart
// Available icons
Icons.phone_rounded        // Voice call
Icons.videocam_rounded     // Video call
Icons.description_rounded  // Prescription
Icons.call_end_rounded     // End consultation
Icons.attach_file_rounded  // Attachment
Icons.send_rounded         // Send message
```

## 📊 Data Models

### Key Models
```dart
// 1. PatientHistoryForm
- 10 comprehensive sections
- All medical history data

// 2. EnhancedPrescription
- SOAP notes
- Diagnoses (ICD-10)
- Medications
- Lab tests
- Lifestyle advice
- Referral & follow-up

// 3. LifestyleAdvice
- Diet, exercise, sleep
- Stress, smoking, alcohol
- Weight management

// 4. ConsultationTimer
- Duration tracking
- Validation
- Status management
```

## 🐛 Troubleshooting

### Common Issues

**1. Timer not starting**
```dart
// Check if timer is initialized in initState
_timer = ConsultationTimer(...);
_timer.start();
```

**2. Prescription not saving**
```dart
// Check validation
final validationError = prescription.validateCompletion();
if (validationError != null) {
  // Show error
}
```

**3. Cannot end consultation**
```dart
// Check conditions:
- Timer >= 10 minutes?
- Prescription complete? (doctor only)
- Confirmation dialog shown?
```

**4. Messages not loading**
```dart
// Check consultationId is set
if (_consultationId == null) {
  // Initialize consultation first
}
```

## 📞 Support

### For Questions
- Check `VIDEO_CONSULTATION_IMPLEMENTATION_PLAN.md` for detailed specs
- Check `IMPLEMENTATION_SUMMARY.md` for what's implemented
- Review code comments in each file

### For Backend Integration
- All API endpoints documented above
- JSON structures in model files
- Error handling in service layer

## ✅ Checklist for Integration

### Frontend
- [x] Models created
- [x] Screens implemented
- [x] Services updated
- [x] Timer logic complete
- [x] Validation added
- [ ] UI polish (forms need completion)
- [ ] Testing

### Backend
- [ ] API endpoints created
- [ ] Database schema
- [ ] Authentication
- [ ] File upload
- [ ] Real-time messaging
- [ ] Testing

### Testing
- [ ] Unit tests
- [ ] Integration tests
- [ ] E2E tests
- [ ] Performance tests
- [ ] Security tests

---

**Last Updated:** May 7, 2026  
**Version:** 1.0  
**Status:** Ready for Integration
