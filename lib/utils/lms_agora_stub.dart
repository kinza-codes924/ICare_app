// Mobile / non-web stub for LMS live sessions
import 'package:flutter/widgets.dart';

void Function()? _onJoined;

void lmsSetCallbacks({void Function(int, bool)? onRemote, void Function()? onJoined}) {
  _onJoined = onJoined;
}

Future<void> lmsJoinChannel(String roomName, String appId, String token, bool isInstructor) async {
  // Mobile: stub — signal joined so Flutter UI shows
  Future.delayed(const Duration(milliseconds: 600), () => _onJoined?.call());
}

void lmsLeaveChannel() {}
void lmsMuteMic(bool mute) {}
void lmsMuteCamera(bool mute) {}
void lmsSetPanelWidth(bool open) {}
void lmsStartRecording() {}
void lmsStopRecordingAndUpload(String sessionId, String backendUrl, String authToken) {}

String registerLmsVideoView() => '';
Widget lmsGetLocalVideoWidget(String? viewName) => const SizedBox.shrink();
Widget lmsGetRemoteVideoWidget(int uid, String channelId) => const SizedBox.shrink();
