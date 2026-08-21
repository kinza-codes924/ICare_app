// Conditional export:
//   Web            → prescription_toggle_bridge_web.dart  (real DOM button)
//   Mobile/Desktop → prescription_toggle_bridge_stub.dart (no-op)
export 'prescription_toggle_bridge_web.dart' if (dart.library.io) 'prescription_toggle_bridge_stub.dart';
