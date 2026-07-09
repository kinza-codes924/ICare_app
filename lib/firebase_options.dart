// Firebase configuration for iCare — web + Android.
// Web config sourced from Firebase Console (project: icare-5c82d, web app: icare).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError('iOS is not configured for Firebase.');
      default:
        throw UnsupportedError(
            'DefaultFirebaseOptions not configured for this platform.');
    }
  }

  // ── Web ───────────────────────────────────────────────────────────────────
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC_IvgEuWUYhdZgX-a6e2tHrX8bfpuxE3Y',
    appId: '1:564788374793:web:15efeaaefb68b4bf0877d8',
    messagingSenderId: '564788374793',
    projectId: 'icare-5c82d',
    authDomain: 'icare-5c82d.firebaseapp.com',
    storageBucket: 'icare-5c82d.firebasestorage.app',
    measurementId: 'G-65Y23KM3VE',
  );

  // ── Android ───────────────────────────────────────────────────────────────
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCyGcCmJffRByCAzyiBQBzQeMUhLuMoNTw',
    appId: '1:564788374793:android:4e30c04020dce01a0877d8',
    messagingSenderId: '564788374793',
    projectId: 'icare-5c82d',
    storageBucket: 'icare-5c82d.firebasestorage.app',
  );
}
