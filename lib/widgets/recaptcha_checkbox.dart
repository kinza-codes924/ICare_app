import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:icare/utils/recaptcha.dart';

/// Visible "I'm not a robot" v2 checkbox. No-op (renders nothing) on
/// non-web platforms, matching recaptcha_stub.dart's null-token behavior.
class RecaptchaCheckbox extends StatefulWidget {
  const RecaptchaCheckbox({super.key});

  @override
  State<RecaptchaCheckbox> createState() => _RecaptchaCheckboxState();
}

class _RecaptchaCheckboxState extends State<RecaptchaCheckbox> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb) registerRecaptchaView();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    return SizedBox(
      width: 304,
      height: 78,
      child: HtmlElementView(viewType: recaptchaViewType),
    );
  }
}
