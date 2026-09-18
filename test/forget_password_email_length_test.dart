// Guards the Forgot Password email/phone field against being too short for
// an actual email address.
//
// The field takes either an email or a phone number, and was capped at
// maxLength: 15 -- sized for a phone number. A username like
// "wajahatfrontdev" is already 15 characters on its own, so typing an email
// starting with a long local part left no room left to type "@gmail.com"
// after it: the field silently stopped accepting input, which read as the
// screen "not letting me type" rather than a length limit.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('the forgot-password email/phone field is not capped at phone length', () {
    final source = _read('lib/screens/forget_password.dart');
    final matches = RegExp(r'maxLength:\s*(\d+)').allMatches(source);

    expect(matches, isNotEmpty,
        reason: 'lib/screens/forget_password.dart no longer sets maxLength '
            'on its email/phone field in the expected shape.');

    for (final m in matches) {
      final value = int.parse(m.group(1)!);
      expect(
        value >= 100,
        isTrue,
        reason: 'lib/screens/forget_password.dart caps its email/phone '
            'field at $value characters. This field accepts an email '
            'address, not just a phone number -- a limit sized for a phone '
            'number silently truncates a normal email as the user types it.',
      );
    }
  });
}
