// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void playNotifyTone() {
  try {
    html.window.dispatchEvent(html.CustomEvent('icare-notify-tone'));
  } catch (_) {}
}
