// Conditional export: on web use the real iframe player, elsewhere use the stub
export 'video_player_stub.dart'
    if (dart.library.html) 'video_player_web.dart';
