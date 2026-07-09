import '../utils/js_stub.dart'
    if (dart.library.html) 'dart:js' as js;

void scheduleDailyReminder(String type, String title, String body, int hour, int minute) {
  try {
    js.context.callMethod('scheduleDailyReminder', [type, title, body, hour, minute]);
  } catch (_) {}
}

void cancelDailyReminder(String type) {
  try {
    js.context.callMethod('cancelDailyReminder', [type]);
  } catch (_) {}
}
