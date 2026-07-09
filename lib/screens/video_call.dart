// Conditional export:
//   Web  → video_call_web.dart   (Agora RTC — Flutter Web)
//   Mobile/Desktop → video_call_mobile.dart (Agora RTC — Android/iOS/Desktop)
export 'video_call_web.dart' if (dart.library.io) 'video_call_mobile.dart';
