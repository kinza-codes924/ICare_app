# Task Progress

## Issues Fixed

### ✅ Issue 1: Camera Not Working in APK (Video Call) - FIXED
- [x] Added `permission_handler` import in `video_call_mobile.dart`
- [x] Added runtime camera (Permission.camera) and microphone (Permission.microphone) permission request before Agora engine initialization
- [x] Added graceful error handling with user-friendly messages when permissions denied/permanently denied
- [x] Added `kIsWeb` import to skip permission requests on web platform

### ✅ Issue 2: Prescription Form "Complete" Button Error - FIXED
- [x] Fixed `_buildPrescriptionObject()` to use fallback to `consultationId` when patient/doctor IDs are empty strings
- [x] Added null-safety checks before accessing `widget.appointment.patient?.id` and `widget.appointment.doctor?.id`
- [x] Prevents backend errors from empty/null patientId/doctorId being sent

### ✅ Issue 3: Biometric/Face ID Login Not Working - FIXED
- [x] Changed biometric button visibility from `_biometricAvailable && _biometricEnabled` to just `_biometricAvailable` so button always shows when device supports biometrics
- [x] This enables biometric flow even on first visit (user can tap to authenticate, then gets prompted to enable for next time)
- [x] Applied fix to both mobile and desktop login layouts