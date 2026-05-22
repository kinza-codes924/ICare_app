import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/screens/public_home.dart';
import 'package:icare/screens/splash.dart';
import 'package:icare/screens/tabs.dart';
import 'package:icare/utils/shared_pref.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  Widget content = const PublicHome();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      final token = await SharedPref().getToken();

      if (token != null && token.isNotEmpty) {
        await ref.read(authProvider.notifier).setUserToken(token);

        final userRole = await SharedPref().getUserRole();
        if (userRole != null) {
          await ref.read(authProvider.notifier).setUserRole(userRole);
        }

        final userDataMap = await SharedPref().getUserData();
        if (userDataMap != null) {
          await ref.read(authProvider.notifier).setUser(userDataMap);
        }

        if (mounted) {
          setState(() {
            content = const TabsScreen();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Auth check error: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SplashScreen();
    return content;
  }
}
