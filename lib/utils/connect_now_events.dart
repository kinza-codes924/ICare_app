import 'dart:async';

/// Global event bus for Connect Now FCM → DoctorConnectNowListener communication.
/// FCM fires trigger() → listener calls _checkPending() immediately.
class ConnectNowEvents {
  ConnectNowEvents._();
  static final _controller = StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get onRequest => _controller.stream;

  /// Call this when an FCM connect_now_request message arrives.
  static void trigger([Map<String, dynamic>? data]) {
    if (!_controller.isClosed) _controller.add(data ?? {});
  }
}
