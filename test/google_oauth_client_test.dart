// Guards the Google sign-in client id.
//
// Web sign-in broke with "Access blocked: Authorisation error — Error 401:
// disabled_client". The cause was not the sign-in code: web/index.html named
// an OAuth client from a different Google project (1076307742101) than the one
// the app actually uses (564788374793, the Firebase project). That client was
// later disabled, and every web sign-in died.
//
// The trap is that the google_sign_in web plugin reads this meta tag and it
// OVERRIDES the clientId passed from Dart — so the Dart code can look
// perfectly correct while a stale tag decides every sign-in. These tests keep
// the two in step.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// The Firebase project the app belongs to. Every Google client id used for
/// sign-in must come from it.
const _projectNumber = '564788374793';

void main() {
  group('Google sign-in uses one OAuth client, from our own project', () {
    test('the web meta tag names a client from our project', () {
      final html = File('web/index.html').readAsStringSync();
      final tag = RegExp(
        r'<meta\s+name="google-signin-client_id"\s+content="([^"]+)"',
      ).firstMatch(html);

      expect(tag, isNotNull,
          reason: 'web/index.html no longer declares a Google client id. The '
              'web plugin needs it.');

      final clientId = tag!.group(1)!;
      expect(
        clientId.startsWith('$_projectNumber-'),
        isTrue,
        reason: 'web/index.html names OAuth client "$clientId", which is not '
            'from project $_projectNumber. This tag overrides the clientId '
            'passed from Dart, so a client from another project takes over '
            'every web sign-in — and breaks it the moment that client is '
            'disabled, exactly as happened before.',
      );
    });

    test('the Dart client id matches the meta tag', () {
      final html = File('web/index.html').readAsStringSync();
      final auth = File('lib/services/auth_service.dart').readAsStringSync();

      final fromHtml = RegExp(
        r'<meta\s+name="google-signin-client_id"\s+content="([^"]+)"',
      ).firstMatch(html)!.group(1)!;

      final inDart = RegExp("'($_projectNumber" r"-[^']+\.apps\.googleusercontent\.com)'")
          .allMatches(auth)
          .map((m) => m.group(1))
          .toSet();

      expect(
        inDart.contains(fromHtml),
        isTrue,
        reason: 'web/index.html uses "$fromHtml" but auth_service.dart signs '
            'in with $inDart. They must be the same client, or web and mobile '
            'authenticate as different applications.',
      );
    });

    test('the backend accepts whatever the web page sends', () {
      final html = File('web/index.html').readAsStringSync();
      final controller =
          File('icare-backend/controllers/authController.js').readAsStringSync();

      final fromHtml = RegExp(
        r'<meta\s+name="google-signin-client_id"\s+content="([^"]+)"',
      ).firstMatch(html)!.group(1)!;

      expect(
        controller.contains(fromHtml),
        isTrue,
        reason: 'GOOGLE_CLIENT_IDS in authController.js does not list '
            '"$fromHtml", so the token the web page obtains would be rejected '
            'server-side as a wrong audience.',
      );
    });
  });
}
