import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

void triggerWebDownload(String content, String filename) {
  final bytes = utf8.encode(content);
  final array = bytes.toJS;
  final blob = web.Blob([array].toJS, web.BlobPropertyBag(type: 'text/csv'));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.setAttribute('download', filename);
  anchor.click();
  web.URL.revokeObjectURL(url);
}
