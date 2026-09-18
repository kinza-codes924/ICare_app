// Guards against a wrong OTP surfacing a raw Dio exception instead of a
// warning.
//
// The backend rejects a wrong or expired code with a non-2xx status (400,
// usually), carrying a clear message ("Incorrect verification code",
// "Invalid code. Make sure your phone clock is correct..."). Dio throws a
// DioException on that response BEFORE a caller's own
// `if (data['success'] != true) throw Exception(data['message'])` check ever
// runs -- that check is dead code for every real rejection.
//
// Two service methods did exactly this: they awaited the request, then
// checked `response.data`, with no `on DioException catch` in between. The
// wrong-code path fell into a bare `catch (e)` further out that used
// `e.toString()` -- the generic "DioException [bad response]: ..." string --
// instead of the backend's actual wording. A patient typing a wrong code saw
// either nothing useful or a confusing technical string, which read as the
// app having silently frozen rather than as "you got that wrong, try again".
//
// This reads the source rather than driving the widgets, because the risk is
// someone adding a new OTP-verify method the same way -- await, then check
// response.data -- without the DioException handling that the failure path
// actually needs.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('a wrong OTP surfaces the backend\'s real message', () {
    test('AuthVerificationService catches DioException on every OTP call', () {
      final source = _read('lib/services/auth_verification_service.dart');

      for (final method in [
        'sendPhoneOtp',
        'confirmPhoneOtp',
        'sendEmailOtp',
        'confirmEmailOtp',
      ]) {
        final body = RegExp(
          'Future<[^>]+> $method\\([^)]*\\) async \\{[\\s\\S]*?\\n  \\}',
        ).firstMatch(source);
        expect(body, isNotNull,
            reason: '$method was not found in auth_verification_service.dart '
                'in the expected shape.');
        expect(
          body!.group(0)!.contains('on DioException catch'),
          isTrue,
          reason: '$method awaits a POST and then reads response.data, but '
              'the backend rejects a wrong/expired code with a non-2xx '
              'status -- Dio throws before that read happens. Without an '
              '`on DioException catch` here, the real message in '
              'e.response.data never reaches the caller.',
        );
      }
    });

    test('SecurityService.enable2FAWithOtp catches DioException', () {
      final source = _read('lib/services/security_service.dart');
      // Match from the method name itself, not its return type -- a return
      // type like Future<Map<String, dynamic>> has a `>` inside it, which
      // breaks a naive `Future<[^>]+>` pattern.
      final body = RegExp(
        r'enable2FAWithOtp\([^)]*\) async \{[\s\S]*?\n  \}',
      ).firstMatch(source);

      expect(body, isNotNull,
          reason: 'enable2FAWithOtp was not found in security_service.dart '
              'in the expected shape.');
      expect(
        body!.group(0)!.contains('on DioException catch'),
        isTrue,
        reason: 'A wrong TOTP code is a 400 from /auth/2fa/enable. Without '
            'an `on DioException catch` extracting e.response.data, the '
            'catch-all below returned e.toString() -- a generic Dio string, '
            'not "Invalid code. Make sure your phone clock is correct...".',
      );
    });

    test('the phone/email verification screen clears a wrong code, not just '
        'shows why', () {
      final source = _read('lib/screens/otp_verification_screen.dart');
      // Both confirm methods' catch blocks should clear their own pin
      // controller, so the six wrong digits do not just sit there waiting
      // for the user to notice and wipe them by hand.
      expect(
        source.contains('_phonePinController.clear();') &&
            source.contains('_emailPinController.clear();'),
        isTrue,
        reason: 'A wrong code should be cleared from the field along with '
            'showing the error, the same way email_otp_screen.dart already '
            'handles it -- otherwise retyping means clearing six digits by '
            'hand first.',
      );
    });
  });
}
