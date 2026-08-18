// Conditional export: on web use the real iframe embed, elsewhere use the stub
export 'clinic_map_stub.dart' if (dart.library.html) 'clinic_map_web.dart';
