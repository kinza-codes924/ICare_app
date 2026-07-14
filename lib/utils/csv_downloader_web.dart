// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Downloads [csvContent] as a file named [filename] in the browser.
bool downloadCsv(String csvContent, String filename) {
  final bytes = html.Blob([csvContent], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(bytes);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  return true;
}
