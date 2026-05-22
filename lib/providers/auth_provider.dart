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
    await SharedPref().setUserRole(normalizedRole);
    await SharedPref().setUserData(user);
    state = state.copyWith(user: user, userRole: normalizedRole);
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
