// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:convert';

final _controller = StreamController<Map<String, String>>.broadcast();
bool _initialized = false;

Stream<Map<String, String>> get reminderEventStream {
  if (!_initialized) {
    _initialized = true;
    html.window.on['icare-reminder'].listen((event) {
      try {
        final ce = event as html.CustomEvent;
        final detail = ce.detail;
        Map<String, dynamic> map = {};
        if (detail is String) {
          map = jsonDecode(detail) as Map<String, dynamic>;
        } else if (detail != null) {
          // JS object — try property access via toString workaround
          final str = detail.toString();
          if (str.startsWith('{')) map = jsonDecode(str) as Map<String, dynamic>;
        }
        _controller.add({
          'type': map['type']?.toString() ?? '',
          'title': map['title']?.toString() ?? '',
          'body': map['body']?.toString() ?? '',
        });
      } catch (_) {}
    });
  }
  return _controller.stream;
}
