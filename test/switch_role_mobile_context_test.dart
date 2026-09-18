// Guards Switch Role against being unresponsive on mobile.
//
// Flutter only keeps a Drawer's subtree mounted while the drawer is open --
// closing it disposes CustomDrawer's whole State. On mobile, tapping
// "Switch Role" closes the drawer (to avoid the animation race guarded by
// switch_role_sheet_overflow_test.dart) and then used the just-disposed
// CustomDrawer's own `context`/`mounted` to open the role sheet, open the
// spinner dialog, and later navigate or show an error. All of that silently
// no-opped: the sheet either never opened, or opened but its actions had
// nothing live to act through, which read as "the sheet doesn't respond,
// only the X closes it". This only showed up on mobile because the
// desktop sidebar is a permanent widget that is never torn down.
//
// The fix: route every context-dependent action in drawer.dart through
// appNavigatorKey's context, which belongs to the app's root Navigator and
// outlives the drawer.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('drawer.dart routes Switch Role through appNavigatorKey, not the drawer\'s own context', () {
    final source = _read('lib/navigators/drawer.dart');

    expect(
      source.contains("import 'package:icare/utils/app_keys.dart';"),
      isTrue,
      reason: 'lib/navigators/drawer.dart no longer imports app_keys.dart, '
          'so it has no way to reach a context that outlives the drawer.',
    );

    expect(
      source.contains('appNavigatorKey.currentContext'),
      isTrue,
      reason: 'lib/navigators/drawer.dart must open the Switch Role sheet '
          'and the spinner dialog via appNavigatorKey.currentContext. The '
          'drawer\'s own context is disposed as soon as the drawer closes, '
          'which happens before the sheet even opens.',
    );

    final showMethod = RegExp(
      r'void _showSwitchRoleSheet\(BuildContext context\) \{[\s\S]*?\n  \}',
    ).firstMatch(source);
    expect(showMethod, isNotNull);
    expect(
      RegExp(r'if \(!context\.mounted\) return;').hasMatch(showMethod!.group(0)!),
      isFalse,
      reason: '_showSwitchRoleSheet must not gate on the drawer-owned '
          '`context.mounted` -- that context belongs to CustomDrawer, which '
          'is already disposed by the time the post-close delay fires.',
    );

    final switchMethod = RegExp(
      r'Future<void> _switchRole\(String role,[\s\S]*?\n  \}',
    ).firstMatch(source);
    expect(switchMethod, isNotNull);
    final body = switchMethod!.group(0)!;
    expect(
      RegExp(r'if \(mounted\)').hasMatch(body),
      isFalse,
      reason: '_switchRole must not gate its navigation or error message on '
          "_CustomDrawerState's own `mounted` flag -- that State is already "
          'disposed on mobile by the time this runs, which silently '
          'swallowed both successful switches (no navigation happened) and '
          'failures (no error shown).',
    );
    expect(
      RegExp(r'\bref\.read\(authProvider').hasMatch(body),
      isFalse,
      reason: '_switchRole must not call ref.read(authProvider...) directly '
          '-- that ref belongs to _CustomDrawerState too, and Riverpod '
          'throws "Bad state: ... unsafe to use when the widget is '
          'deactivated" the moment the drawer finishes disposing, which can '
          'land before this network call returns. Read providers through '
          "ProviderScope.containerOf(navContext) instead, using the same "
          'appNavigatorKey context.',
    );
    expect(
      body.contains('ProviderScope.containerOf('),
      isTrue,
      reason: '_switchRole must read/write authProvider through '
          'ProviderScope.containerOf(navContext), not the widget\'s own ref.',
    );
  });
}
