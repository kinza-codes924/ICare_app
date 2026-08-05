import 'dart:async';
import 'dart:convert';
import 'dart:math';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Bridges to the icare-recaptcha-request/-result CustomEvent pair set up
/// in web/index.html (same mechanism as the icare-reminder events already
/// used elsewhere) — avoids Promise/js_util interop, which isn't stable
/// across the Dart SDK version this project is pinned to.
Future<String?> executeRecaptcha(String action) async {
  final requestId = '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
  final completer = Completer<String?>();
  StreamSubscription? sub;

  sub = html.window.on['icare-recaptcha-result'].listen((event) {
    try {
      final ce = event as html.CustomEvent;
      final raw = ce.detail;
      // Both sides pass `detail` as a JSON string, not a raw object/Map —
      // passing a Dart Map directly into CustomEvent's `detail` on dispatch
      // throws at the JS-interop conversion layer (this crashed the whole
      // Dart isolate the first time, taking the login flow down with it),
      // and reading a raw JS object back out of `.detail` on the Dart side
      // has the same problem in reverse.
      if (raw is! String) return;
      final map = jsonDecode(raw) as Map;
      final gotId = map['requestId']?.toString();
      if (gotId != requestId) return;
      final token = map['token']?.toString();
      sub?.cancel();
      if (!completer.isCompleted) completer.complete(token);
    } catch (_) {
      sub?.cancel();
      if (!completer.isCompleted) completer.complete(null);
    }
  });

  try {
    html.window.dispatchEvent(html.CustomEvent(
      'icare-recaptcha-request',
      detail: jsonEncode({'requestId': requestId, 'action': action}),
    ));
  } catch (_) {
    sub.cancel();
    return null;
  }

  return completer.future.timeout(
    const Duration(seconds: 8),
    onTimeout: () {
      sub?.cancel();
      return null;
    },
  );
}
