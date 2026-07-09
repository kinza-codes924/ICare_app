# iCare Video Consultation Feature - Complete Guide

## Overview
Your iCare app has a fully integrated video consultation system using **Agora RTC Engine** for real-time video/audio communication. Here's where you can access and test the video consultation feature.

---

## 🎥 Video Consultation Architecture

### Core Components

#### 1. **Video Call Screen** (`lib/screens/video_call.dart`)
- **Purpose**: Main video call interface
- **Features**:
  - Real-time video/audio streaming via Agora
  - Picture-in-picture local video preview
  - Call duration tracking
  - Network quality indicator (5-level signal strength)
  - Mute/Unmute microphone
  - Camera on/off toggle
  - Speaker control
  - Camera switching (front/back)
  - Screen sharing capability
  - Audio-only mode support
  - End call functionality

#### 2. **Agora Service** (`lib/services/agora_service.dart`)
- **Purpose**: Backend integration for Agora tokens
- **Endpoint**: `/agora/token`
- **Functionality**:
  - Fetches secure Agora tokens from backend
  - Retrieves App ID and User ID
  - Handles channel-based communication

#### 3. **Connect Now Service** (`lib/services/connect_now_service.dart`)
- **Purpose**: Instant consultation request management
- **Key Methods**:
  - `initiateConnect()` - Patient initiates instant consultation
  - `getStatus(requestId)` - Poll consultation request status
  - `getDoctorPendingRequests()` - Doctor views pending requests
  - `acceptRequest(requestId)` - Doctor accepts consultation
  - `rejectRequest(requestId)` - Doctor rejects consultation

#### 4. **Consultation Workflow** (`lib/screens/consultation_workflow.dart`)
- **Purpose**: Structured clinical workflow during consultation
- **Workflow Steps**:
  1. **History** - Chief complaint, HPI, medical history
  2. **Examination** - Vital signs, physical exam
  3. **Diagnosis** - Primary & differential diagnosis
  4. **Plan** - Prescriptions, lab tests, health programs, referrals
- **Video Integration**: Video call button in top-right corner

#### 5. **Doctor Consultation Screen** (`lib/screens/doctor_consultation_screen.dart`)
- **Purpose**: Doctor-side consultation interface
- **Features**:
  - Structured clinical workflow (4-step process)
  - Vital signs recording
  - Diagnosis entry with ICD codes
  - Prescription management
  - Lab test ordering
  - Health program assignment
  - Referral creation
  - Auto-routing to pharmacy/lab

---

## 📍 Where to Access Video Consultation

### For Patients:
1. **Book Appointment** → `lib/screens/book_appointment.dart`
2. **My Appointments** → `lib/screens/my_appointments_list.dart`
3. **Upcoming Appointments** → `lib/screens/upcoming_appointments.dart`
4. **Connect Now (Instant)** → `lib/screens/connect_now_waiting_screen.dart`

### For Doctors:
1. **Doctor Dashboard** → `lib/screens/doctor_dashboard.dart`
2. **Doctor Appointments** → `lib/screens/doctor_appointments.dart`
3. **Doctor Connect Now** → `lib/screens/doctor_connect_now_screen.dart`
4. **Consultation Workflow** → `lib/screens/consultation_workflow.dart`

---

## 🔧 How to Test Video Consultation

### Prerequisites:
1. **Backend API Running** on port 5000 (or update `lib/utils/api_constants.dart`)
2. **Agora Account** with:
   - App ID configured
   - Token generation endpoint at `/agora/token`
3. **Permissions** (handled automatically):
   - Camera access
   - Microphone access

### Testing Steps:

#### Step 1: Login
```
1. Open app in Chrome
2. Login with valid credentials
3. Token should be stored in SharedPreferences
```

#### Step 2: Initiate Video Consultation
**Option A - Scheduled Appointment:**
```
1. Navigate to "My Appointments"
2. Select an upcoming appointment
3. Click video call icon
4. Channel name: appointment_id
5. Remote user: doctor name
```

**Option B - Connect Now (Instant):**
```
1. Navigate to "Connect Now"
2. Click "Find a Doctor"
3. Wait for doctor to accept
4. Video call starts automatically
```

#### Step 3: During Call
- **Mute/Unmute**: Click microphone icon
- **Camera On/Off**: Click camera icon
- **Switch Camera**: Click flip camera icon
- **Share Screen**: Click share icon
- **End Call**: Click red end button

---

## 🌐 Backend API Endpoints Required

### Agora Token Generation
```
GET /agora/token
Query Parameters:
  - channelName: string (appointment_id or consultation_id)
  - uid: number (user_id)

Response:
{
  "success": true,
  "data": {
    "token": "agora_token_string",
    "appId": "your_agora_app_id",
    "uid": 12345
  }
}
```

### Connect Now Endpoints
```
POST /connect-now/initiate
Response: { requestId, status, waitingTime }

GET /connect-now/status/:requestId
Response: { status, doctorId, channelName }

GET /connect-now/doctor/pending
Response: { requests: [...] }

POST /connect-now/:requestId/accept
Response: { channelName, token }

POST /connect-now/:requestId/reject
Response: { success: true }
```

---

## 📊 Current Configuration

### API Base URL
- **File**: `lib/utils/api_constants.dart`
- **Current**: `http://localhost:5000/api`
- **Update if needed**: Change port/domain here

### Agora Configuration
- **File**: `lib/screens/video_call.dart`
- **Token Endpoint**: `/agora/token`
- **Supports**: Video + Audio, Audio-only mode

### SharedPreferences Integration
- **File**: `lib/utils/shared_pref.dart` (FIXED ✅)
- **Stores**: Auth token, user data, user role
- **Cache Keys**: auth, userData, token, userRole, walkthrough, biometric_enabled

---

## 🐛 Known Issues & Fixes

### ✅ Fixed: SharedPref Compilation Errors
- **Issue**: Type mismatch between `SharedPreferences` and `SharedPreferencesWithCache`
- **Solution**: Updated all method variables to use `SharedPreferencesWithCache`
- **Status**: RESOLVED

### ⚠️ Current: Network Connection
- **Issue**: Backend not running on port 5000
- **Solution**: Start your backend API server
- **Check**: Verify endpoint in `lib/utils/api_constants.dart`

---

## 🎯 Testing Checklist

- [ ] Backend API running on correct port
- [ ] Agora App ID configured
- [ ] Token generation endpoint working
- [ ] User can login successfully
- [ ] Token stored in SharedPreferences
- [ ] Can navigate to appointments
- [ ] Video call screen loads
- [ ] Camera/microphone permissions granted
- [ ] Can see local video preview
- [ ] Can see remote video when other user joins
- [ ] Mute/unmute works
- [ ] Camera toggle works
- [ ] Call duration displays correctly
- [ ] Network quality indicator shows
- [ ] Can end call successfully

---

## 📱 Supported Platforms

- ✅ **Android**: Full support
- ✅ **iOS**: Full support
- ❌ **Web**: Not supported (shows error message)
- ✅ **Windows**: Full support

---

## 🔐 Security Features

1. **Token-based Authentication**: Agora tokens generated server-side
2. **Secure Channel**: Each consultation has unique channel ID
3. **Permission Handling**: Runtime permissions for camera/microphone
4. **Error Handling**: Graceful error messages for failed connections

---

## 📞 Quick Reference

| Feature | File | Status |
|---------|------|--------|
| Video Call UI | `video_call.dart` | ✅ Ready |
| Agora Integration | `agora_service.dart` | ✅ Ready |
| Connect Now | `connect_now_service.dart` | ✅ Ready |
| Consultation Workflow | `consultation_workflow.dart` | ✅ Ready |
| Doctor Consultation | `doctor_consultation_screen.dart` | ✅ Ready |
| SharedPref Storage | `shared_pref.dart` | ✅ Fixed |
| API Configuration | `api_constants.dart` | ⚠️ Check Port |

---

## 🚀 Next Steps

1. **Start Backend Server**: Ensure API is running on port 5000
2. **Configure Agora**: Set up your Agora App ID
3. **Test Login**: Verify token storage works
4. **Test Video Call**: Try a test consultation
5. **Monitor Logs**: Check browser console for errors

---

## 📝 Notes

- Video consultations are **NOT supported on web** (Chrome/Edge)
- Use **mobile app** or **Windows desktop** for full video support
- Audio-only mode available for low-bandwidth scenarios
- Network quality indicator helps diagnose connection issues
- All calls are encrypted and secure

