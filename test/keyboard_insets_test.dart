// Guards the auth screens against the keyboard covering the form.
//
// On iOS the sign-up sheet was pinned to a flat 72% of the screen height,
// measured from MediaQuery.sizeOf — a figure that does not shrink when the
// keyboard appears. The sheet kept its full height, the keyboard sat on top of
// it, and scrolling ran the fields up under the heading and into the status
// bar.
//
// This reads the source rather than driving the widgets: the danger is not a
// value at runtime but someone reinstating a fixed height, or dropping
// resizeToAvoidBottomInset, while making an unrelated change. A widget test
// would need a real keyboard inset to catch it.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('auth screens make room for the keyboard', () {
    const screens = {
      'sign-up': 'lib/screens/signup.dart',
      'login': 'lib/screens/login.dart',
      'email OTP': 'lib/screens/email_otp_screen.dart',
    };

    screens.forEach((label, path) {
      test('the $label screen resizes around the keyboard', () {
        expect(
          _read(path).contains('resizeToAvoidBottomInset: true'),
          isTrue,
          reason: 'Without this the keyboard is painted over the form instead '
              'of being part of the layout, and the fields end up behind it.',
        );
      });
    });

    test('no form sheet is given a height the keyboard cannot shrink', () {
      // A sheet sized from windowHeight must subtract viewInsets, otherwise it
      // keeps its full height while the keyboard covers the bottom of it.
      for (final path in ['lib/screens/signup.dart', 'lib/screens/login.dart']) {
        final source = _read(path);
        final fixedHeights = RegExp(
          r'height:\s*Utils\.windowHeight\(context\)\s*\*\s*0\.\d+\s*,',
        ).allMatches(source);

        expect(
          fixedHeights,
          isEmpty,
          reason: '$path pins a form sheet to a fraction of the screen with no '
              'allowance for viewInsets. Subtract '
              'MediaQuery.viewInsetsOf(context).bottom, as the others do.',
        );
      }
    });

    test('the OTP field is pinned left-to-right', () {
      // iOS was placing the digits as though the field were RTL.
      expect(
        _read('lib/screens/email_otp_screen.dart')
            .contains('textDirection: ui.TextDirection.ltr'),
        isTrue,
        reason: 'Without an explicit direction the digits can appear in the '
            'wrong order on iOS.',
      );
    });
  });
}
