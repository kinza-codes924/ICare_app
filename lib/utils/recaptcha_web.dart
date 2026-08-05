import 'dart:async';
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
      final detail = ce.detail;
      final gotId = detail is Map ? detail['requestId']?.toString() : null;
      if (gotId != requestId) return;
      final token = detail is Map ? detail['token']?.toString() : null;
      sub?.cancel();
      if (!completer.isCompleted) completer.complete(token);
    } catch (_) {
      sub?.cancel();
      if (!completer.isCompleted) completer.complete(null);
    }
  });

  try {
    html.window.dispatchEvent(html.CustomEvent('icare-recaptcha-request', detail: {
      'requestId': requestId,
      'action': action,
    }));
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
