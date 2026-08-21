// JS bridge for the real-DOM in-call toggle button(s) used during a walk-in
// call (reception_prescription_screen.dart's _ReceptionCallScreen,
// doctor_call_with_prescription_screen.dart) and a normal appointment-based
// consultation call (doctor_consultation_call_screen.dart). A Flutter FAB
// stacked on top of VideoCall's HtmlElementView(Jitsi iframe) via Positioned
// turned out to be unclickable in practice — Jitsi's live iframe wins
// pointer routing over Flutter's platform-view compositing in this build,
// the same class of problem already solved for the LMS chat toast by
// building the element directly in the parent page's DOM
// (web/index.html's showCallTabButtons/hideCallTabButtons) instead of
// relying on Flutter to draw over it.
// Uses dart:html + window CustomEvents — same interop style already proven
// for the reCAPTCHA/reminder bridges (recaptcha_web.dart), not the
// js_interop/@JS style video_call_web.dart uses for jitsiJoin. The event's
// `detail` is a JSON STRING (not a raw JS object) — dart:html's interop for
// plain JS object details is unreliable across dart2js/dartdevc, so this
// mirrors the same string+jsonDecode pattern already used for
// icare-recaptcha-result etc.
import 'dart:async';
import 'dart:convert';
import 'dart:js' as js;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show VoidCallback;

String? _decodeToggleId(html.Event event) {
  try {
    final ce = event as html.CustomEvent;
    final raw = ce.detail;
    if (raw is! String) return null;
    final map = jsonDecode(raw) as Map;
    return map['id']?.toString();
  } catch (_) {
    return null;
  }
}

class PrescriptionToggleBridge {
  StreamSubscription? _sub;

  /// side: 'left' or 'right'. onToggle fires every time the real HTML
  /// button is clicked (Dart owns the open/closed state, JS just reports taps).
  void show({required String side, required VoidCallback onToggle}) {
    try {
      js.context.callMethod('showPrescriptionToggle', [side]);
    } catch (_) {}
    _sub?.cancel();
    _sub = html.window.on['icareCallTabToggle'].listen((event) {
      if (_decodeToggleId(event) == 'prescription') onToggle();
    });
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

/// Multiple named toggle buttons stacked on one side (e.g. "Prescription"
/// and "Patient History" for a normal in-call consultation) — see
/// showCallTabButtons() in web/index.html. Each button reports its own id
/// back through onToggle so the caller can drive an exclusive tab-selection
/// state (only one panel open at a time) the same way a real tab bar would.
class CallTabButtonsBridge {
  StreamSubscription? _sub;

  /// buttons: list of {id, label, side ('left'|'right'), top (optional px
  /// offset for vertical stacking)}. onToggle(id) fires when any button in
  /// the set is clicked.
  void show({
    required List<Map<String, dynamic>> buttons,
    required void Function(String id) onToggle,
  }) {
    try {
      js.context.callMethod('showCallTabButtons', [
        js.JsArray.from(buttons.map((b) => js.JsObject.jsify(b))),
      ]);
    } catch (_) {}
    _sub?.cancel();
    _sub = html.window.on['icareCallTabToggle'].listen((event) {
      final id = _decodeToggleId(event);
      if (id != null) onToggle(id);
    });
  }

  void hide() {
    try {
      js.context.callMethod('hideCallTabButtons');
    } catch (_) {}
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    hide();
  }
}
