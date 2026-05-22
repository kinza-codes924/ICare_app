import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:icare/models/user.dart';
import 'package:icare/utils/shared_pref.dart';

/// Handles all device-level biometric authentication.
///
/// Flow:
///   1. After first successful password login → call [promptEnableBiometrics]
///      to ask the user if they want to enable biometric sign-in.
///   2. On subsequent app opens → call [authenticateWithBiometrics] to sign
///      in without a password.
///   3. User can toggle biometrics off in Settings → call [disableBiometrics].
class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _auth = LocalAuthentication();
  final SharedPref _prefs = SharedPref();

  // ── Device capability checks ─────────────────────────────────────────────

  /// Returns true if the device supports biometrics AND has enrolled biometrics.
  Future<bool> isAvailable() async {
    // Biometrics not supported on web
    if (kIsWeb) return false;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      if (!canCheck || !isSupported) return false;
      final biometrics = await _auth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } on PlatformException catch (e) {
      debugPrint('BiometricService.isAvailable error: $e');
      return false;
    }
  }

  /// Returns a human-readable label for the available biometric type.
  Future<String> getBiometricLabel() async {
    try {
      final biometrics = await _auth.getAvailableBiometrics();
      if (biometrics.contains(BiometricType.face)) return 'Face Unlock';
      if (biometrics.contains(BiometricType.fingerprint)) return 'Fingerprint';
      if (biometrics.contains(BiometricType.iris)) return 'Iris Scan';
      return 'Biometrics';
    } catch (_) {
      return 'Biometrics';
    }
  }

  // ── Preference helpers ───────────────────────────────────────────────────

  Future<bool> isBiometricEnabled() => _prefs.getBiometricEnabled();

  Future<void> enableBiometrics(String email, {String? token, User? user}) async {
    await _prefs.setBiometricEnabled(true);
    await _prefs.setBiometricEmail(email);
    if (token != null) await _prefs.setBiometricToken(token);
    if (user != null) await _prefs.setBiometricUserData(user);
    debugPrint('✅ Biometric sign-in enabled for $email');
  }

  Future<void> disableBiometrics() async {
    await _prefs.clearBiometricSession();
    debugPrint('🔒 Biometric sign-in disabled');
  }

  Future<String?> getBiometricEmail() => _prefs.getBiometricEmail();

  // ── Authentication ───────────────────────────────────────────────────────

  /// Triggers the device biometric prompt.
  ///
  /// Returns [BiometricResult.success] on success,
  /// [BiometricResult.notAvailable] if device has no biometrics,
  /// [BiometricResult.cancelled] if user dismissed,
  /// [BiometricResult.failed] on error.
  Future<BiometricResult> authenticate({
    String reason = 'Sign in to iCare',
  }) async {
    if (kIsWeb) return BiometricResult.notAvailable;

    final available = await isAvailable();
    if (!available) return BiometricResult.notAvailable;

    try {
      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // allow PIN/pattern as fallback
          stickyAuth: true,     // keep prompt alive if app goes background
          sensitiveTransaction: false,
        ),
      );
      return authenticated ? BiometricResult.success : BiometricResult.cancelled;
    } on PlatformException catch (e) {
      debugPrint('BiometricService.authenticate error: ${e.code} — ${e.message}');
      if (e.code == 'NotAvailable' || e.code == 'NotEnrolled') {
        return BiometricResult.notAvailable;
      }
      if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
        return BiometricResult.lockedOut;
      }
      return BiometricResult.failed;
    }
  }
}

enum BiometricResult {
  success,
  cancelled,
  failed,
  notAvailable,
  lockedOut,
}
