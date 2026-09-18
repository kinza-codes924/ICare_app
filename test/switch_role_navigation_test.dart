// Guards Switch Role against landing on the same screen after a successful
// switch.
//
// Both _switchRole implementations used to navigate with
// context.go('/dashboard') after updating the role in authProvider, relying
// on '/dashboard's own redirect to re-read the role and bounce to the right
// screen. Going to a fixed string after a role switch is exactly the case
// where GoRouter's redirect can be skipped, which read as "the screen
// doesn't change" even though the switch itself succeeded on the backend.
//
// The fix: navigate straight to the new role's real route via
// dashboardRouteFor(), so there is no redirect indirection to depend on.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('Switch Role navigates straight to the new role\'s dashboard', () {
    const screens = {
      'the drawer': 'lib/navigators/drawer.dart',
      'the web sidebar': 'lib/screens/tabs.dart',
    };

    screens.forEach((label, path) {
      test('$label uses dashboardRouteFor instead of a bare /dashboard go()', () {
        final source = _read(path);
        final method = RegExp(
          r'Future<void> _switchRole\(String role,[\s\S]*?\n  \}',
        ).firstMatch(source);

        expect(method, isNotNull,
            reason: '_switchRole(String role, BuildContext dialogContext) '
                'was not found in $path in the expected shape.');

        final body = method!.group(0)!;
        expect(
          body.contains('dashboardRouteFor('),
          isTrue,
          reason: "$path must navigate via dashboardRouteFor(user.role) "
              "after a successful switch, not context.go('/dashboard'). "
              "Going through '/dashboard' depends on that route's own "
              "redirect re-reading authProvider, which is the indirection "
              "that let a role switch silently leave the user on the same "
              "screen.",
        );
        expect(
          RegExp(r"context\.go\(\s*'/dashboard'\s*\)").hasMatch(body),
          isFalse,
          reason: "$path still calls context.go('/dashboard') directly "
              "after a role switch.",
        );
      });
    });
  });

  test('dashboardRouteFor exists and covers every switchable role', () {
    final source = _read('lib/navigators/dashboard_route.dart');
    for (final role in [
      'Doctor',
      'Patient',
      'Student',
      'Instructor',
      'Laboratory',
      'Pharmacy',
      'Receptionist',
      'Admin',
    ]) {
      expect(
        source.contains("'$role' =>"),
        isTrue,
        reason: 'dashboardRouteFor is missing a case for role "$role".',
      );
    }
  });
}
