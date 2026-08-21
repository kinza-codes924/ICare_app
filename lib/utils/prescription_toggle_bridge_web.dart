// JS bridge for the real-DOM "Prescription" toggle button used during a
// walk-in call (reception_prescription_screen.dart's _ReceptionCallScreen,
// doctor_call_with_prescription_screen.dart). A Flutter FAB stacked on top
// of VideoCall's HtmlElementView(Jitsi iframe) via Positioned turned out to
// be unclickable in practice — Jitsi's live iframe wins pointer routing over
// Flutter's platform-view compositing in this build, the same class of
// problem already solved for the LMS chat toast by building the element
// directly in the parent page's DOM (web/index.html's showPrescriptionToggle/
// hidePrescriptionToggle) instead of relying on Flutter to draw over it.
// Uses dart:html + window CustomEvents — same interop style already proven
// for the reCAPTCHA/reminder bridges (recaptcha_web.dart), not the
// js_interop/@JS style video_call_web.dart uses for jitsiJoin.
import 'dart:async';
import 'dart:js' as js;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show VoidCallback;

class PrescriptionToggleBridge {
  StreamSubscription? _sub;

  /// side: 'left' or 'right'. onToggle fires every time the real HTML
  /// button is clicked (Dart owns the open/closed state, JS just reports taps).
  void show({required String side, required VoidCallback onToggle}) {
    try {
      js.context.callMethod('showPrescriptionToggle', [side]);
    } catch (_) {}
    _sub?.cancel();
    _sub = html.window.on['icarePrescriptionToggle'].listen((_) => onToggle());
  }

  void hide() {
    try {
      js.context.callMethod('hidePrescriptionToggle');
    } catch (_) {}
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    hide();
  }
}
