import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icare/widgets/tap_area.dart';

/// Back button for screens that can be reached via a direct URL (e.g.
/// /privacypolicy, /terms, /refund-policy). Unlike [CustomBackButton], it
/// falls back to the home route when there's nothing left to pop, so it
/// can't no-op or crash on a hard refresh / direct link where the
/// navigation stack only contains this one page.
class LegalPageBackButton extends StatelessWidget {
  const LegalPageBackButton({super.key, this.margin, this.color});
  final EdgeInsets? margin;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return TapArea(
        behavior: HitTestBehavior.opaque,
      onTap: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      },
      child: Container(
        margin: margin ?? EdgeInsets.only(left: 21),
        child: Center(
          child: Icon(
            Icons.arrow_back_ios_new,
            color: color ?? Colors.black,
            size: 20,
          ),
        ),
      ),
    );
  }
}
