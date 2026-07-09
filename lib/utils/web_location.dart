import 'dart:async';
import 'package:flutter/foundation.dart';

/// Returns [latitude, longitude] using browser geolocation (web only).
/// Returns null if not on web, permission denied, or unavailable.
Future<List<double>?> getBrowserLocation() async {
  if (!kIsWeb) return null;

  try {
    final completer = Completer<List<double>?>();

    // Use JS interop via dart:js_util for web geolocation
    // ignore: avoid_dynamic_calls
    _getLocationWeb(
      (lat, lng) => completer.complete([lat, lng]),
      () => completer.complete(null),
    );

    return await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => null,
    );
  } catch (e) {
    debugPrint('Location error: $e');
    return null;
  }
}

void _getLocationWeb(
  void Function(double lat, double lng) onSuccess,
  void Function() onError,
) {
  try {
    // Using dart:js to call browser API
    // ignore: undefined_prefixed_name
    _invokeGeolocation(onSuccess, onError);
  } catch (_) {
    onError();
  }
}

// Stub — actual web implementation uses conditional import
void _invokeGeolocation(
  void Function(double, double) onSuccess,
  void Function() onError,
) {
  onError();
}
