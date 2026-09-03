// Stub for dart:html on non-web platforms.
library html_stub;

class CustomEvent {
  CustomEvent(String type);
}

class _Location {
  final String protocol = '';
  final String hostname = '';
  final String href = '';
}

class _Window {
  final location = _Location();
  void dispatchEvent(dynamic event) {}
}

final window = _Window();
