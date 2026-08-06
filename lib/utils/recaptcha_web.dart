import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

/// v2 checkbox widget — bridges to the icare-recaptcha-* CustomEvents set up
/// in web/index.html (same mechanism as the icare-reminder events already
/// used elsewhere) — avoids Promise/js_util interop, which isn't stable
/// across the Dart SDK version this project is pinned to.
const String recaptchaContainerId = 'icare-recaptcha-container';
const String _recaptchaViewType = 'icare-recaptcha-view';
bool _viewFactoryRegistered = false;

/// Registers the platform view that hosts the checkbox <div>, and asks the
/// JS side to render the widget into it once the container exists in the
/// DOM and grecaptcha has loaded. Safe to call multiple times — the view
/// *factory* is only registered once (Flutter throws if you register the
/// same viewType twice), but the mount request is re-dispatched on every
/// call, since this is a SPA where a fresh screen instance (and a fresh
/// container element) can appear later in the same page load without
/// index.html's onload callback ever firing again.
void registerRecaptchaView() {
  if (!_viewFactoryRegistered) {
    _viewFactoryRegistered = true;
    ui_web.platformViewRegistry.registerViewFactory(_recaptchaViewType, (int viewId) {
      final container = html.DivElement()
        ..id = recaptchaContainerId
        ..style.width = '304px'
        ..style.height = '78px';
      return container;
    });
  }

  void mount() {
    html.window.dispatchEvent(html.CustomEvent(
      'icare-recaptcha-mount',
      detail: jsonEncode({'containerId': recaptchaContainerId}),
    ));
  }

  // grecaptcha may already be loaded (fast reload) or may still be loading.
  html.window.on['icare-recaptcha-ready'].listen((_) => mount());
  Timer(const Duration(milliseconds: 300), mount);
}

String get recaptchaViewType => _recaptchaViewType;

/// Reads whatever the user has currently checked (or null if not checked /
/// widget not ready / expired). Does not force a re-render.
Future<String?> getRecaptchaResponse() async {
  final completer = Completer<String?>();
  StreamSubscription? sub;

  sub = html.window.on['icare-recaptcha-result'].listen((event) {
    try {
      final ce = event as html.CustomEvent;
      final raw = ce.detail;
      if (raw is! String) return;
      final map = jsonDecode(raw) as Map;
      final token = map['token']?.toString();
      sub?.cancel();
      if (!completer.isCompleted) completer.complete(token);
    } catch (_) {
      sub?.cancel();
      if (!completer.isCompleted) completer.complete(null);
    }
  });

  try {
    html.window.dispatchEvent(html.CustomEvent('icare-recaptcha-request'));
  } catch (_) {
    sub.cancel();
    return null;
  }

  return completer.future.timeout(
    const Duration(seconds: 5),
    onTimeout: () {
      sub?.cancel();
      return null;
    },
  );
}

void resetRecaptcha() {
  try {
    html.window.dispatchEvent(html.CustomEvent('icare-recaptcha-reset'));
  } catch (_) {}
}
