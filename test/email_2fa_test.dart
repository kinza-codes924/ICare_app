// Guards the email-based 2FA option (alongside the existing Google
// Authenticator 2FA) added under Settings > Security.
//
// Source-reading tests: the actual OTP verification, email delivery, and
// speakeasy/TOTP logic live in the backend, which these tests don't run.
// What they guard is the frontend wiring -- the method-choice step, the
// service calls it must make, and the login dialog adapting its copy and
// offering a resend for the email path -- since a regression there silently
// strands a user mid-setup or mid-login with no way forward.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('Settings offers a 2FA method choice', () {
    test('_toggle2FA asks which method before starting setup', () {
      final source = _read('lib/screens/settings.dart');
      expect(
        source.contains('_show2FAMethodChoiceDialog'),
        isTrue,
        reason: 'Enabling 2FA must ask Authenticator App vs Email before '
            'calling either setup endpoint -- otherwise there is no way to '
            'choose email 2FA at all.',
      );
      expect(
        source.contains('setup2FAEmail()'),
        isTrue,
        reason: 'settings.dart must call SecurityService.setup2FAEmail() '
            'when the email method is chosen.',
      );
      expect(
        source.contains('enable2FAEmailWithOtp('),
        isTrue,
        reason: 'settings.dart must confirm the emailed code via '
            'SecurityService.enable2FAEmailWithOtp before turning the '
            '2FA switch on.',
      );
    });
  });

  group('SecurityService exposes the email 2FA calls', () {
    test('setup2FAEmail and enable2FAEmailWithOtp exist and hit the right routes', () {
      final source = _read('lib/services/security_service.dart');
      expect(source.contains('Future<Map<String, dynamic>> setup2FAEmail()'), isTrue);
      expect(source.contains("'/auth/2fa/setup-email'"), isTrue);
      expect(source.contains('Future<Map<String, dynamic>> enable2FAEmailWithOtp('), isTrue);
      expect(source.contains("'/auth/2fa/enable-email'"), isTrue);
    });
  });

  group('Login\'s 2FA dialog adapts to the account\'s 2FA method', () {
    test('_show2FADialog takes a method and offers resend for email', () {
      final source = _read('lib/screens/login.dart');
      expect(
        source.contains("_show2FADialog({required String tempToken, String method = 'totp'})"),
        isTrue,
        reason: '_show2FADialog must accept which 2FA method the account '
            'uses -- without it, an email-2FA account is shown '
            '"Open Google Authenticator", which has no code to enter.',
      );
      expect(
        source.contains("result['twoFactorMethod']"),
        isTrue,
        reason: "login.dart must read twoFactorMethod from the login "
            "response and pass it to _show2FADialog.",
      );
      expect(
        source.contains('resend2FAEmail('),
        isTrue,
        reason: 'The email-2FA path needs a resend option in the dialog -- '
            'unlike TOTP, an emailed code can be lost or expire with no '
            'device-side way to generate a new one.',
      );
    });

    test('AuthService exposes resend2FAEmail against the right route', () {
      final source = _read('lib/services/auth_service.dart');
      expect(source.contains('Future<Map<String, dynamic>> resend2FAEmail('), isTrue);
      expect(source.contains("'/auth/2fa/resend-email'"), isTrue);
    });
  });

  group('Backend wires the email 2FA routes and fields', () {
    test('security.js has setup-email, enable-email, resend-email, and branches verify on method', () {
      final source = _read('icare-backend/routes/security.js');
      expect(source.contains("router.post('/2fa/setup-email'"), isTrue);
      expect(source.contains("router.post('/2fa/enable-email'"), isTrue);
      expect(source.contains("router.post('/2fa/resend-email'"), isTrue);
      expect(
        source.contains("user.twoFactorMethod === 'email'"),
        isTrue,
        reason: '/2fa/verify must branch on twoFactorMethod, or an '
            'email-2FA account gets checked against a TOTP secret it never '
            'had, which always fails.',
      );
    });

    test('auth.js proxies the three new 2FA routes to security.js', () {
      final source = _read('icare-backend/routes/auth.js');
      for (final path in ['/2fa/setup-email', '/2fa/enable-email', '/2fa/resend-email']) {
        expect(
          source.contains("'$path'"),
          isTrue,
          reason: "auth.js must proxy $path to security.js the same way "
              "the existing /2fa/* routes are proxied -- security.js's own "
              "router is never mounted directly, only reached through "
              "these per-route handlers in auth.js.",
        );
      }
    });

    test('login issues a 2FA email code and reports the method used', () {
      final source = _read('icare-backend/controllers/authController.js');
      expect(
        source.contains("user.twoFactorMethod === 'email'"),
        isTrue,
        reason: 'Login must send a fresh email OTP at the moment 2FA is '
            'required for an email-2FA account, not wait for the client '
            'to ask for one that does not exist yet.',
      );
      expect(
        source.contains("twoFactorMethod: user.twoFactorMethod"),
        isTrue,
        reason: "The login response must tell the client which 2FA method "
            "applies, so the dialog knows whether to say \"check your "
            "email\" or \"open Authenticator\".",
      );
    });

    test('User schema declares the email-2FA fields', () {
      final source = _read('icare-backend/models/User.js');
      for (final field in [
        'twoFactorMethod',
        'twoFactorEmailOtpHash',
        'twoFactorEmailOtpExpiresAt',
        'twoFactorEmailOtpAttempts',
      ]) {
        expect(source.contains(field), isTrue, reason: 'User.js is missing $field.');
      }
    });

    test('2FA emails do not claim to be creating an account', () {
      final source = _read('icare-backend/utils/emailOtp.js');
      expect(
        source.contains("purpose = 'signup'"),
        isTrue,
        reason: 'sendOtpEmail/otpEmailHtml must default to a signup purpose '
            'but accept an override -- without a purpose parameter, every '
            'caller shares signup\'s "finish creating your iCare account" '
            'wording, which is wrong and confusing on a login 2FA code.',
      );
      expect(
        source.contains("login2fa"),
        isTrue,
        reason: 'emailOtp.js must define login2fa wording distinct from '
            'the signup wording.',
      );

      for (final path in [
        'icare-backend/routes/security.js',
        'icare-backend/controllers/authController.js',
      ]) {
        final fileSource = _read(path);
        // Every sendOtpEmail call that is part of the 2FA flow (identified
        // by sitting near twoFactorEmail* fields or a 2FA comment) must
        // pass purpose: 'login2fa' -- otherwise it silently falls back to
        // signup's wording again.
        final twoFaCallSites = RegExp(r"sendOtpEmail\(\{[^)]*\}\)").allMatches(fileSource).where((m) {
          final start = (m.start - 400).clamp(0, fileSource.length);
          final context = fileSource.substring(start, m.end);
          return context.contains('twoFactorEmailOtp') || context.contains('2FA');
        });
        for (final m in twoFaCallSites) {
          expect(
            m.group(0)!.contains("purpose: 'login2fa'"),
            isTrue,
            reason: '$path has a 2FA-context sendOtpEmail call missing '
                "purpose: 'login2fa': ${m.group(0)}",
          );
        }
      }
    });
  });
}
