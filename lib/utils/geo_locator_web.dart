import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Requests GPS coordinates from the browser.
/// Returns [lat, lng] on success, null on failure.
/// [onError] is called with the error code before returning null:
///   1 = PERMISSION_DENIED, 2 = POSITION_UNAVAILABLE, 3 = TIMEOUT, 0 = other
Future<List<double>?> getGpsCoords(void Function(int code) onError) async {
  final c = Completer<List<double>?>();
  bool done = false;

  void succeed(List<double> coords) {
    if (!done) {
      done = true;
      c.complete(coords);
    }
  }

  void fail(int code) {
    if (!done) {
      done = true;
      onError(code);
      c.complete(null);
    }
  }

  void onSuccess(web.GeolocationPosition p) {
    succeed([p.coords.latitude, p.coords.longitude]);
  }

  void onFailure(web.GeolocationPositionError e) {
    fail(e.code);
  }

  try {
    web.window.navigator.geolocation.getCurrentPosition(
      onSuccess.toJS,
      onFailure.toJS,
      web.PositionOptions(
        enableHighAccuracy: false,
        timeout: 30000,
        maximumAge: 0,
      ),
    );
  } catch (e) {
    fail(0);
    return null;
  }

  return c.future.timeout(
    const Duration(seconds: 35),
    onTimeout: () {
      fail(3);
      return null;
    },
  );
}
