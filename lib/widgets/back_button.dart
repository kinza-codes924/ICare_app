import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icare/widgets/tap_area.dart';

/// Goes back one screen, or to the dashboard when there is nothing to go back
/// to.
///
/// Navigator.pop and popUntil(isFirst) both do nothing when the current route
/// is the only one on the stack — which is the normal case on the web, where
/// any screen can be opened straight from its URL. Back buttons written with
/// those alone were simply dead there. Call this instead.
void goBackOrHome(BuildContext context) {
  // Use GoRouter's canPop/pop — Navigator.of(context).canPop() is unreliable
  // inside a ShellRoute where the inner Navigator may report canPop=true even
  // when there is only one logical route on the stack.
  final canPop = context.canPop();
  debugPrint('⬅️ BACK TAP fired: canPop=$canPop');
  if (canPop) {
    context.pop();
  } else {
    context.go('/dashboard');
  }
}

class CustomBackButton extends StatelessWidget {
  const CustomBackButton({super.key, this.margin, this.color});
  final EdgeInsets? margin;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return TapArea(
        behavior: HitTestBehavior.opaque,
      onTap: () => goBackOrHome(context),
      child: Container(
        margin: margin ?? EdgeInsets.only(left: 21),
        child: Center(
          child: Icon(
            Icons.arrow_back_ios_new,
            // Plain black read as a faint grey against the app bars' white and
            // was easy to miss; the navy is the same ink the titles use.
            color: color ?? const Color(0xFF0F172A),
            size: 22,
          ),
        ),
      ),
    );
  }
}
