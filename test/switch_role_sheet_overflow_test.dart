// Guards the Switch Role sheet against two reported layout bugs:
//
// 1. Desktop/web: the sheet was a plain, unconstrained Column, so on a
//    shorter viewport (or an account with several roles) the bottom rows
//    were simply cut off, with no scrollbar to reveal them existed.
// 2. Mobile: tapping Switch Role in the drawer closed the drawer and opened
//    the bottom sheet in the same frame. Scaffold.closeDrawer() only starts
//    the drawer's slide-out animation -- it doesn't remove it instantly --
//    so the sheet's slide-up animation visibly collided with the still-
//    closing drawer.
//
// This reads the source rather than driving the widgets: the risk is
// someone reverting the sheet back to a plain, unscrollable Column, or
// dropping the drawer-close delay, while making an unrelated change.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('Switch Role sheet is scrollable and height-capped', () {
    const screens = {
      'the drawer': 'lib/navigators/drawer.dart',
      'the web sidebar': 'lib/screens/tabs.dart',
    };

    screens.forEach((label, path) {
      test('$label caps the sheet height and scrolls with a visible bar', () {
        final source = _read(path);
        expect(
          source.contains('isScrollControlled: true'),
          isTrue,
          reason: '$path must open the Switch Role sheet with '
              'isScrollControlled: true, or Flutter caps it at its default '
              'half-screen height and clips whatever role rows do not fit.',
        );
        expect(
          source.contains('DragScroll('),
          isTrue,
          reason: '$path must wrap the role list in DragScroll so an '
              'overflowing list gets an always-visible, draggable scrollbar '
              'instead of silently clipping content with no way to reach it.',
        );
      });
    });
  });

  group('Switch Role sheet does not race the drawer\'s close animation', () {
    test('drawer.dart waits for the drawer to finish closing before opening the sheet', () {
      final source = _read('lib/navigators/drawer.dart');
      final showMethod = RegExp(
        r'void _showSwitchRoleSheet\(BuildContext context\) \{[\s\S]*?\n  \}',
      ).firstMatch(source);

      expect(showMethod, isNotNull,
          reason: '_showSwitchRoleSheet(BuildContext context) was not found '
              'in lib/navigators/drawer.dart in the expected shape.');

      final body = showMethod!.group(0)!;
      expect(
        body.contains('Future.delayed('),
        isTrue,
        reason: 'Scaffold.closeDrawer() only starts the drawer\'s slide-out '
            'animation; opening the bottom sheet synchronously in the same '
            'call visibly collides the sheet\'s slide-up animation with the '
            'still-closing drawer. _showSwitchRoleSheet must wait via '
            'Future.delayed before calling _openSwitchRoleSheet.',
      );
      expect(
        body.contains('_openSwitchRoleSheet('),
        isTrue,
        reason: '_showSwitchRoleSheet must hand off to _openSwitchRoleSheet '
            'once the delay has elapsed.',
      );
    });
  });
}
