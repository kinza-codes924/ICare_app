// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void activateLanguage(String lang) {
  try {
    if (lang == 'Urdu') {
      html.document.cookie = 'googtrans=/en/ur; path=/';
      html.document.cookie =
          'googtrans=/en/ur; path=/; domain=.${html.window.location.hostname}';
    } else {
      html.document.cookie =
          'googtrans=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/';
      html.document.cookie =
          'googtrans=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/; domain=.${html.window.location.hostname}';
    }
    html.window.location.reload();
  } catch (_) {}
}
