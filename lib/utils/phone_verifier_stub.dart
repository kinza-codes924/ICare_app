// Mobile / non-web implementation — uses firebase_auth verifyPhoneNumber with Completer
// to give a unified async API that matches the web RecaptchaVerifier flow.

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

class PhoneVerifierImpl {
  /// Sends a 6-digit SMS OTP via Firebase Phone Auth to [phoneNumber] (E.164 format).
  ///
  /// Resolves with the [verificationId] string that must be passed back to
  /// [confirmOtp] together with the user-entered code.
  ///
  /// Throws a [FirebaseAuthException] (or generic [Exception]) on failure.
  Future<String> sendOtp(String phoneNumber) async {
    final completer = Completer<String>();

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) {
        // Auto-retrieval or instant verification — we don't use this path
        // because we always want the user to enter the code manually.
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!completer.isCompleted) {
          completer.complete(verificationId);
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // Called when the 60-second auto-retrieval window closes.
        // Only complete if we haven't already (shouldn't happen normally).
        if (!completer.isCompleted) {
          completer.complete(verificationId);
        }
      },
    );

    return completer.future;
  }

  /// Verifies the [smsCode] entered by the user against [verificationId].
  ///
  /// Signs the user into Firebase temporarily to confirm OTP validity,
  /// then immediately signs them out (Firebase is used only as OTP carrier,
  /// not as our auth system).
  ///
  /// Throws [FirebaseAuthException] with `code == 'invalid-verification-code'`
  /// on a wrong code.
  Future<void> confirmOtp(String verificationId, String smsCode) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await FirebaseAuth.instance.signInWithCredential(credential);
    // Sign out immediately — Firebase is used only as OTP delivery/validation.
    await FirebaseAuth.instance.signOut().catchError((_) async {});
  }
}
