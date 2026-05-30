// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../utils/js_stub.dart'
    if (dart.library.html) 'dart:js' as js;

Future<String> requestWaterNotifPermission() async {
  if (!html.Notification.supported) return 'unsupported';
  return html.Notification.requestPermission();
}

void scheduleWaterReminderInterval(int minutes) {
  try {
    js.context.callMethod('scheduleWaterReminderInterval', [minutes]);
  } catch (_) {}
}
