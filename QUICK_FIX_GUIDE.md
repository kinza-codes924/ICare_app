# Quick Fix Guide - Video Consultation Integration
**Date:** May 8, 2026

---

## 🎯 Problem

Purana code directly `VideoCall` screen open kar raha tha. Ab hume **chat-first approach** chahiye jahan:
1. Pehle chat screen khule
2. Consent message auto-send ho
3. Timer start ho (10 min minimum, 30 min maximum)
4. Doctor prescription fill kare DURING consultation
5. Prescription complete hone ke baad hi consultation end ho

---

## ✅ Solution (3 Simple Steps)

### Step 1: Find & Replace in Key Files

#### File 1: `lib/widgets/boooking_card.dart`

**Line ~106 - OLD CODE:**
```dart
onPressed: () {
  final channelName = appointment.channelName?.isNotEmpty == true
      ? appointment.channelName!
      : appointment.id;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => VideoCall(
        channelName: channelName,
        remoteUserName: selectedRole == 'Doctor'
            ? appointment.patientName
            : appointment.doctorName,
        appointmentId: appointment.id,
      ),
    ),
  );
},
```

**NEW CODE (Copy-paste this):**
```dart
onPressed: () async {
  // Show loading
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final consultationService = ConsultationService();
    final sharedPref = SharedPref();
    
    final currentUserId = await sharedPref.getUserId();
    final currentUserName = await sharedPref.getUserName();
    final isDoctor = selectedRole == 'Doctor';

    // Start consultation
    final result = await consultationService.startConsultationV2(
      appointmentId: appointment.id ?? '',
      patientId: appointment.patientId ?? '',
      doctorId: appointment.doctorId ?? '',
    );

    Navigator.pop(context); // Close loading

    if (result['success'] == true) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConsultationChatScreenV2(
            consultationId: result['consultationId'],
            appointment: appointment,
            isDoctor: isDoctor,
            currentUserId: currentUserId ?? '',
            currentUserName: currentUserName ?? 'User',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to start consultation'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
    );
  }
},
```

**Add these imports at top of file:**
```dart
import 'package:icare/services/consultation_service.dart';
import 'package:icare/screens/consultation_chat_screen_v2.dart';
import 'package:icare/utils/shared_pref.dart';
```

---

#### File 2: `lib/screens/bookings.dart`

**Line ~1073 - OLD CODE:**
```dart
onPressed: () {
  final channelName = appt.channelName?.isNotEmpty == true
      ? appt.channelName!
      : appt.id;
  Navigator.of(ctx).push(
    MaterialPageRoute(
      builder: (_) => VideoCall(
        channelName: channelName,
        remoteUserName: appt.doctorName,
        appointmentId: appt.id,
      ),
    ),
  );
},
```

**NEW CODE:**
```dart
onPressed: () async {
  showDialog(
    context: ctx,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final consultationService = ConsultationService();
    final sharedPref = SharedPref();
    
    final currentUserId = await sharedPref.getUserId();
    final currentUserName = await sharedPref.getUserName();

    final result = await consultationService.startConsultationV2(
      appointmentId: appt.id ?? '',
      patientId: appt.patientId ?? '',
      doctorId: appt.doctorId ?? '',
    );

    Navigator.pop(ctx);

    if (result['success'] == true) {
      Navigator.push(
        ctx,
        MaterialPageRoute(
          builder: (_) => ConsultationChatScreenV2(
            consultationId: result['consultationId'],
            appointment: appt,
            isDoctor: false, // Patient side
            currentUserId: currentUserId ?? '',
            currentUserName: currentUserName ?? 'User',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to start consultation'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    Navigator.pop(ctx);
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
    );
  }
},
```

**Add these imports:**
```dart
import 'package:icare/services/consultation_service.dart';
import 'package:icare/screens/consultation_chat_screen_v2.dart';
import 'package:icare/utils/shared_pref.dart';
```

---

### Step 2: Fix consultation_chat_screen_v2.dart

**File:** `lib/screens/consultation_chat_screen_v2.dart`

**Line ~87 - CHANGE THIS:**
```dart
final result = await _consultationService.startConsultation(
```

**TO THIS:**
```dart
final result = await _consultationService.startConsultationV2(
```

---

### Step 3: Test

Run the app and test:

1. **Go to appointments**
2. **Click "Start Consultation" or "Join Consultation"**
3. **Chat screen should open** (NOT video directly)
4. **Consent message should auto-appear**
5. **Timer should start**
6. **Doctor can click "Prescription" button**
7. **Fill prescription form**
8. **Try to end consultation** - should check if prescription is complete

---

## 🧪 Quick Test Code

Add this button anywhere to test API:

```dart
ElevatedButton(
  onPressed: () async {
    final service = ConsultationService();
    final result = await service.startConsultationV2(
      appointmentId: 'test123',
      patientId: 'patient123',
      doctorId: 'doctor123',
    );
    print('API Result: $result');
    // Should print: {success: true, consultationId: '...'}
    
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('API Working! Consultation ID: ${result['consultationId']}'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('API Error: ${result['message']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  },
  child: Text('Test API Connection'),
)
```

---

## 📝 Summary

**What to do:**
1. Replace code in `boooking_card.dart` (line ~106)
2. Replace code in `bookings.dart` (line ~1073)
3. Fix method name in `consultation_chat_screen_v2.dart` (line ~87)
4. Add imports in both files
5. Test the flow

**What you get:**
- ✅ Chat-first consultation
- ✅ Auto-send consent message
- ✅ Timer (10-30 minutes)
- ✅ In-consultation prescription
- ✅ Cannot end without prescription
- ✅ Patient history form
- ✅ Lifestyle advice
- ✅ All backend features working

---

## 🚨 Common Issues

### Issue 1: "startConsultationV2 not found"
**Solution:** Make sure you pulled latest code: `git pull origin wajahat`

### Issue 2: "Failed to start consultation"
**Solution:** Check if appointment has valid patient and doctor IDs

### Issue 3: "Network error"
**Solution:** Backend is already deployed, check internet connection

### Issue 4: Import errors
**Solution:** Make sure these imports are added:
```dart
import 'package:icare/services/consultation_service.dart';
import 'package:icare/screens/consultation_chat_screen_v2.dart';
import 'package:icare/utils/shared_pref.dart';
```

---

## ✅ Checklist

- [ ] Updated `boooking_card.dart`
- [ ] Updated `bookings.dart`
- [ ] Fixed `consultation_chat_screen_v2.dart`
- [ ] Added all imports
- [ ] Tested API connection
- [ ] Tested complete flow
- [ ] Verified prescription form works
- [ ] Verified timer works
- [ ] Verified cannot end without prescription

---

**Status:** Ready to implement  
**Time Required:** 10-15 minutes  
**Difficulty:** Easy (just copy-paste)

---

**Need Help?** Check `INTEGRATION_EXAMPLE.dart` for more examples!
