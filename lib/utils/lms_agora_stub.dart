// Mobile / Desktop — real Agora RTC implementation for LMS live sessions
import 'package:flutter/widgets.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

RtcEngine? _lmsEngine;

void Function(int uid, bool joining)? _lmsOnRemoteUser;
void Function()? _lmsOnJoined;

void lmsSetCallbacks({void Function(int, bool)? onRemote, void Function()? onJoined}) {
  _lmsOnRemoteUser = onRemote;
  _lmsOnJoined = onJoined;
}

Future<void> lmsJoinChannel(String appId, String channelId, String? token, int uid) async {
  try {
    await [Permission.camera, Permission.microphone].request();
    _lmsEngine = createAgoraRtcEngine();
    await _lmsEngine!.initialize(RtcEngineContext(appId: appId));
    await _lmsEngine!.enableVideo();
    await _lmsEngine!.startPreview();
    await _lmsEngine!.setChannelProfile(ChannelProfileType.channelProfileLiveBroadcasting);
    await _lmsEngine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    _lmsEngine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) => _lmsOnJoined?.call(),
      onUserJoined: (connection, remoteUid, elapsed) => _lmsOnRemoteUser?.call(remoteUid, true),
      onUserOffline: (connection, remoteUid, reason) => _lmsOnRemoteUser?.call(remoteUid, false),
    ));
    await _lmsEngine!.joinChannel(
      token: token ?? '',
      channelId: channelId,
      uid: uid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );
  } catch (e) {
    debugPrint('LMS Agora error: $e');
    // Trigger joined anyway so UI doesn't block
    _lmsOnJoined?.call();
  }
}

void lmsLeaveChannel() {
  _lmsEngine?.leaveChannel();
  _lmsEngine?.release();
  _lmsEngine = null;
}

void lmsMuteMic(bool mute) => _lmsEngine?.muteLocalAudioStream(mute);
void lmsMuteCamera(bool mute) => _lmsEngine?.muteLocalVideoStream(mute);
void lmsSetPanelWidth(bool open) {} // Web-only, no-op

// Not used on mobile (HtmlElementView is web-only)
String registerLmsVideoView() => '';

Widget lmsGetLocalVideoWidget(String? viewName) {
  if (_lmsEngine == null) return const SizedBox.shrink();
  return AgoraVideoView(
    controller: VideoViewController(
      rtcEngine: _lmsEngine!,
      canvas: const VideoCanvas(uid: 0),
    ),
  );
}

Widget lmsGetRemoteVideoWidget(int uid, String channelId) {
  if (_lmsEngine == null) return const SizedBox.shrink();
  return AgoraVideoView(
    controller: VideoViewController.remote(
      rtcEngine: _lmsEngine!,
      canvas: VideoCanvas(uid: uid),
      connection: RtcConnection(channelId: channelId),
    ),
  );
}
