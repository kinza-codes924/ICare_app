// Stub for dart:js on non-web platforms

class _JsObject {
  dynamic operator [](String key) => _JsObject();
  dynamic callMethod(String method, [List? args]) => null;
}

final _JsObject context = _JsObject();

dynamic allowInterop(Function f) => f;
