# iCare App — App Store & Play Store Pending Checklist

**Date:** 6 July 2026  
**Project:** iCare Virtual Hospital  
**App ID:** com.cartzlink.icare

---

## Section 1: BLOCKERS — Bina iske Submit Nahi Hoga

Ye items complete hone zaroori hain before any store submission.

---

### 1.1 iOS Firebase Config File Missing

**File:** `ios/Runner/GoogleService-Info.plist`  
**Status:** MISSING  
**Responsible:** Sarfaraz

**Steps:**
1. Firebase Console kholein → Project Settings
2. iOS app (`com.cartzlink.icare`) select karein
3. `GoogleService-Info.plist` download karein
4. File ko `ios/Runner/` folder mein rakhein
5. Git mein push karein

**Impact:** Bina is file ke iOS pe Firebase login aur push notifications kaam nahi karenge. App Store submission reject ho jayegi.

---

### 1.2 Android Release Keystore

**File:** `android/key.properties`  
**Status:** Template (`key.properties.example`) exist karta hai, actual file nahi bani  
**Responsible:** Sarfaraz (Mac pe banana hoga)

**Steps:**
1. `android/key.properties.example` ko copy karke `android/key.properties` banao
2. Real keystore passwords fill karo:
   ```
   storePassword=ACTUAL_KEYSTORE_PASSWORD
   keyPassword=ACTUAL_KEY_PASSWORD
   keyAlias=icare
   storeFile=/path/to/icare-release.jks
   ```
3. Ye file `.gitignore` mein hai — Git mein push mat karna
4. Secure channel (WhatsApp/email) se Wajahat ko share karna hoga

**Impact:** Play Store release AAB/APK debug key se sign nahi accept karta. Bina proper keystore ke Play Store submission fail hogi.

---

### 1.3 iOS Apple Developer Team Set Karna

**Location:** Xcode → Runner → Signing & Capabilities → Team  
**Status:** NOT SET  
**Responsible:** Sarfaraz ya Wajahat (Mac + Xcode required)

**Steps:**
1. Mac pe `ios/Runner.xcworkspace` Xcode mein kholein
2. Left panel mein `Runner` select karein
3. `Signing & Capabilities` tab kholein
4. `Team` dropdown mein Apple Developer account select karein
5. Automatically provisioning profile generate ho jayega

**Impact:** Bina Team set kiye iOS app archive aur App Store Connect pe upload nahi ho sakti.

---

### 1.4 Public Privacy Policy URL

**Status:** In-app privacy policy screen exist karti hai, lekin public web URL nahi hai  
**Responsible:** Wajahat / Sarfaraz

**Steps:**
1. Ek simple privacy policy web page publish karo (GitHub Pages ya koi bhi hosting)
2. URL App Store Connect listing mein daalo
3. URL Google Play Console listing mein daalo

**Impact:** Health app ke liye Privacy Policy URL mandatory hai — dono stores reject karenge bina iske.

---

## Section 2: WARNINGS — Review Rejection Possible

Ye blocker nahi hain lekin store review mein rejection ka risk hai.

---

### 2.1 OTP Console mein Log Ho Raha Hai (Security Risk)

**File:** `lib/screens/verify_code.dart` — Line 67  
**Issue:** Real OTP device logs mein print ho raha hai — PII leak

```dart
// YE LINE HATAO:
debugPrint('New OTP for testing: ${result['otp']}');
```

---

### 2.2 FCM Token Log Ho Raha Hai (Security Risk)

**File:** `lib/services/fcm_service.dart` — Line 59  
**Issue:** Full device push token logs mein print ho raha hai

```dart
// YE LINE HATAO:
debugPrint('🔑 FCM Token: $token');
```

---

### 2.3 Dead "Delete Account" Button

**File:** `lib/screens/notification_settings.dart` — Line 216  
**Issue:** Ek extra "Delete Account" button hai jo kuch nahi karta  
**Note:** Working delete account flow already `settings.dart` mein exist karta hai

**Action:** Notification settings se ye dead button remove karo.

---

### 2.4 pubspec.yaml Description Update

**File:** `pubspec.yaml`  
**Current Value:** `"A new Flutter project."`  
**Change To:** `"iCare Virtual Hospital — Your complete healthcare platform."`

---

### 2.5 Splash Screen Replace Karo

**Platforms:** Android + iOS  
**Status:** Default Flutter splash screen lagi hui hai — unbranded  
**Action:** iCare branded splash screen lagao (logo + background color)

---

### 2.6 Crash Reporting Add Karo

**Current Status:** Koi crash reporting nahi hai  
**Recommended:** Firebase Crashlytics (already Firebase use ho raha hai)  
**Impact:** Production mein crashes aayenge aur team ko pata nahi chalega

---

### 2.7 iOS Minimum Deployment Target

**File:** `ios/Podfile`  
**Issue:** Minimum iOS version explicitly set nahi hai  
**Action:** Agora aur Zego SDKs ke requirements check karke Podfile mein set karo (recommended: iOS 13.0 minimum)

---

## Section 3: Already Completed

Ye kaam ho chuka hai — verify bhi ho gaya.

| # | Item | Done By |
|---|------|---------|
| 1 | Android App ID — `com.cartzlink.icare` | Sarfaraz |
| 2 | iOS Bundle ID — `com.cartzlink.icare` | Sarfaraz |
| 3 | `google-services.json` updated for new App ID | Sarfaraz |
| 4 | Android release signing config — `build.gradle.kts` | Sarfaraz |
| 5 | iOS `NSPhotoLibraryUsageDescription` added | Sarfaraz |
| 6 | iOS `NSSpeechRecognitionUsageDescription` added | Sarfaraz |
| 7 | iOS `UIBackgroundModes` (audio, voip, remote-notification) | Sarfaraz |
| 8 | Android build issues fixed (gradle.properties) | Sarfaraz |
| 9 | macOS build fixed | Sarfaraz |
| 10 | `POST_NOTIFICATIONS` permission — Android 13+ | Wajahat |
| 11 | Custom app icons — Android + iOS | Done |
| 12 | `targetSdk` / `compileSdk` current for Play Store | Done |
| 13 | Production API URL clean — no localhost/staging leaks | Done |
| 14 | No hardcoded secrets in app code | Done |
| 15 | Google Sign-In + Apple Sign-In both wired | Done |
| 16 | Account deletion flow working in Settings | Done |

---

## Summary

| Category | Total | Done | Remaining |
|----------|-------|------|-----------|
| Blockers | 4 | 0 | **4** |
| Warnings | 7 | 0 | **7** |
| Completed | 16 | 16 | 0 |

**Next Step:** Sarfaraz se Blockers 1.1, 1.2, 1.3 complete karwao. Warnings Wajahat fix kar sakta hai directly code mein.

---

*Document prepared: 6 July 2026*
