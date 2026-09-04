import 'package:flutter/material.dart';

/// Drop-in replacement for `GestureDetector(onTap: ..., child: ...)` on
/// navigation/back controls.
///
/// A bare GestureDetector was confirmed, live, to silently drop taps in at
/// least one screen on web (the Bookings History back button — its onTap
/// never fired, with no error, while the exact same tap position worked fine
/// once wrapped as InkWell here). GestureDetector and InkWell use separate
/// gesture-arena machinery, and InkWell's has proven reliable everywhere else
/// in this app (every _categoryTile, every ListTile), so route every
/// back/nav control through this instead of guessing case by case which raw
/// GestureDetector is the next one to go dead.
///
/// `behavior` is accepted for source compatibility with existing
/// GestureDetector call sites but has no effect — Material+InkWell always
/// hit-tests its full bounds.
class TapArea extends StatelessWidget {
  const TapArea({
    super.key,
    required this.onTap,
    required this.child,
    this.behavior,
    this.borderRadius,
  });

  final VoidCallback? onTap;
  final Widget child;
  final HitTestBehavior? behavior;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: child,
      ),
    );
  }
}
