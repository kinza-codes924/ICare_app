import 'dart:developer';

import 'package:flutter_riverpod/legacy.dart';
import 'package:icare/models/auth.dart';
import 'package:icare/models/user.dart';
import 'package:icare/utils/shared_pref.dart';

class AuthNotifier extends StateNotifier<Auth> {
  AuthNotifier()
    : super(
        Auth(
          token: null,
          fcmToken: null,
          userWalkthrough: false,
          isLoggedIn: false,
          userRole: '',
          user: null,
        ),
      );

  Future<void> setUserToken(String token) async {
    state = state.copyWith(token: token, isLoggedIn: true);
    await SharedPref().setToken(token.trim());
  }

  void setUserWalkthrough(bool value) {
    state = state.copyWith(userWalkthrough: value);
  }

  Future<void> setUserRole(String role) async {
    log(role);
    await SharedPref().setUserRole(role);
    state = state.copyWith(userRole: role);
  }

  void setFcmToken(String token) {
    state = state.copyWith(fcmToken: token);
  }

  Future<void> setUser(User user) async {
    final normalizedRole = _normalizeRole(user.role);
    // Update in-memory state FIRST — UI rebuilds immediately regardless of storage outcome
    state = state.copyWith(user: user, userRole: normalizedRole);
    // Persist to storage — wrapped in try/catch because large base64 images can exceed
    // web localStorage quota and must not block the state update above
    try {
      await SharedPref().setUserRole(normalizedRole);
      await SharedPref().setUserData(user);
    } catch (_) {}
  }

  String _normalizeRole(String role) {
    if (role.isEmpty) return role;
    switch (role.trim().toLowerCase()) {
      case 'lab':
      case 'laboratory': return 'Laboratory';
      case 'pharmacy':   return 'Pharmacy';
      case 'doctor':     return 'Doctor';
      case 'patient':    return 'Patient';
      case 'instructor': return 'Instructor';
      case 'student':    return 'Student';
      case 'admin':      return 'Admin';
      default:
        return role[0].toUpperCase() + role.substring(1).toLowerCase();
    }
  }

  // Immediately patches just the profile picture in-memory (no SharedPref — base64 too large).
  // Call this right after a successful profile save so the dashboard avatar updates instantly.
  void patchPicture(String url) {
    final u = state.user;
    if (u == null) return;
    state = state.copyWith(
      user: User(
        id: u.id, name: u.name, email: u.email,
        phoneNumber: u.phoneNumber, role: u.role,
        profilePicture: url,
        createdAt: u.createdAt, gender: u.gender, age: u.age,
        mrNumber: u.mrNumber, cnic: u.cnic,
        specialization: u.specialization,
        conditionsTreated: u.conditionsTreated,
        isPhoneVerified: u.isPhoneVerified,
        isEmailVerified: u.isEmailVerified,
      ),
    );
  }

  Future<void> setUserLogout() async {
    await SharedPref().remove("userRole");
    await SharedPref().remove("token");
    await SharedPref().remove("userData");
    // biometricToken, biometricEnabled, biometricEmail, biometricUserData
    // are intentionally kept so biometric login works after logout
    state = Auth();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, Auth>((ref) {
  return AuthNotifier();
});
