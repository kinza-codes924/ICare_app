// Web-only — requests microphone permission via JS interop
// Uses the lmsRequestMicPermission function defined in web/index.html
import 'dart:js_interop';
import 'package:flutter/foundation.dart';

@JS('lmsRequestMicPermission')
external JSPromise<JSBoolean> _lmsRequestMicPermissionJS(
    JSNumber maxRetries, JSNumber retryDelayMs);

Future<bool> lmsRequestMicPermission(int maxRetries, int retryDelayMs) async {
  try {
    final result = await _lmsRequestMicPermissionJS(
      maxRetries.toJS,
      retryDelayMs.toJS,
    ).toDart;
    return result.toDart;
  } catch (e) {
    debugPrint('⚠️ lmsRequestMicPermission JS error: $e');
    return false;
  }
}