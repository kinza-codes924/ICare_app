// Guards the Switch Role spinner against hanging forever.
//
// Tapping a role in the Switch Role sheet showed a blocking spinner that
// never went away. The sheet closed on tap, and the code that dismissed the
// spinner used `if (!mounted) return;` against the calling State, then popped
// the dialog with `this.context`. Closing the bottom sheet the drawer/sidebar
// itself sits in can unmount that State in the same frame, so the early
// return skipped the dialog dismissal entirely -- nothing else in the app
// closes it, so the spinner span forever.
//
// The fix: the dialog is opened with its own dedicated `dialogContext`
// (from the dialog's own builder), and `_switchRole` closes the dialog via
// that context specifically, in a try/catch, unconditional on whether the
// calling State is still mounted. This reads the source rather than driving
// the widgets, because the risk is someone reinstating `Navigator.of(context,
// rootNavigator: true).pop()` guarded by `if (!mounted) return;` -- exactly
// what caused the hang -- while making an unrelated change.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('Switch Role never leaves its spinner stuck', () {
    const screens = {
      'the drawer': 'lib/navigators/drawer.dart',
      'the web sidebar': 'lib/screens/tabs.dart',
    };

    screens.forEach((label, path) {
      test('$label wraps the role switch in a try/catch', () {
        final source = _read(path);
        final method = RegExp(
          r'Future<void> _switchRole\(String role,[\s\S]*?\n  \}',
        ).firstMatch(source);

        expect(method, isNotNull,
            reason: '_switchRole(String role, BuildContext dialogContext) '
                'was not found in $path in the expected shape.');

        final body = method!.group(0)!;
        expect(
          body.contains('try {') && body.contains('} catch ('),
          isTrue,
          reason: 'A network error or a bad response shape in $path must '
              'still close the spinner. Without a catch here, an exception '
              'skips every line after it -- including the dialog dismissal '
              '-- and the spinner is left on screen with nothing able to '
              'close it.',
        );
      });

      test('$label dismisses the spinner via its own dialog context', () {
        final source = _read(path);
        expect(
          source.contains('dialogContext.mounted') &&
              source.contains('Navigator.of(dialogContext).pop()'),
          isTrue,
          reason: '$path does not close the spinner through a context taken '
              'from the dialog\'s own builder. Popping via the calling '
              'State\'s context after `if (!mounted) return;` was the actual '
              'bug: closing the bottom sheet can unmount that State in the '
              'same frame, so the early return skipped the pop and the '
              'spinner spun forever.',
        );
      });

      test('$label does not gate the dialog pop on the caller\'s mounted flag',
          () {
        final source = _read(path);
        // The old, broken shape: an unconditional `if (!mounted) return;`
        // sitting before the line that pops the spinner dialog.
        final bug = RegExp(
          r'if \(!mounted\) return;\s*\n\s*(?://[^\n]*\n\s*)*Navigator\.of\(context,\s*rootNavigator:\s*true\)\.pop\(\)',
        );
        expect(
          bug.hasMatch(source),
          isFalse,
          reason: '$path pops the spinner dialog only after an '
              '`if (!mounted) return;` guard on the calling State. If that '
              'State is unmounted by the time the network call returns -- '
              'which closing the bottom sheet can cause -- the dialog is '
              'never dismissed.',
        );
      });
    });
  });
}
