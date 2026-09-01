import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CustomBackButton extends StatelessWidget {
  const CustomBackButton({super.key, this.margin, this.color});
  final EdgeInsets? margin;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Screens reached via pushReplacement (e.g. entering a consultation
        // straight from the Safepay payment-success redirect) can be the
        // ONLY entry in the stack — popping then has nothing left to show
        // and renders a blank/white screen. Fall back to the dashboard.
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/dashboard');
        }
      },
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
