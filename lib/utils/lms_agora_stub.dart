// Mobile stub — Jitsi-compatible function signatures for LMS live sessions.
// On mobile, opens Jitsi Meet in browser; no server-side recording on mobile.
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

void Function()? _onJoined;

void lmsSetCallbacks({void Function(int, bool)? onRemote, void Function()? onJoined}) {
  _onJoined = onJoined;
}

Future<void> lmsJoinChannel(String roomName, String displayName, bool isInstructor, {String jwt = '', String subject = ''}) async {
  try {
    final url = Uri.parse('https://167-99-65-120.nip.io/$roomName');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (_) {}
  await Future.delayed(const Duration(milliseconds: 600));
  _onJoined?.call();
}

void lmsLeaveChannel() {}
void lmsStopRecording() {}
void lmsMuteMic(bool mute) {}
void lmsMuteCamera(bool mute) {}
void lmsSetPanelWidth(bool open) {}
Future<void> lmsEnableMediaAndPublish() async {}
bool lmsIsSessionClosed() => false;
void lmsHardRedirect(String path) {}

String registerLmsVideoView() => '';
Widget lmsGetLocalVideoWidget(String? viewName) => const SizedBox.shrink();
Widget lmsGetRemoteVideoWidget(int uid, String channelId) => const SizedBox.shrink();

void lmsListenForScreenShareEnded(void Function() callback) {}
void lmsListenForRemoteJoined(void Function(int uid) callback) {}
void lmsListenForRemoteLeft(void Function(int uid) callback) {}
