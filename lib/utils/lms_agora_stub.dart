// Mobile Agora RTC implementation for LMS live sessions
import 'package:flutter/widgets.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

RtcEngine? _engine;
String _channelId = '';
void Function(int uid, bool joined)? _onRemoteCb;
void Function()? _onJoinedCb;

void lmsSetCallbacks({
  void Function(int, bool)? onRemote,
  void Function()? onJoined,
}) {
  _onRemoteCb = onRemote;
  _onJoinedCb = onJoined;
}

Future<void> lmsJoinChannel(
  String roomName,
  String appId,
  String token,
  bool isInstructor,
) async {
  try {
    _channelId = roomName;

    // Request camera + mic permissions on Android/iOS before touching Agora
    await [Permission.camera, Permission.microphone].request();

    if (_engine != null) {
      await _engine!.leaveChannel();
      await _engine!.release();
      _engine = null;
    }

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: appId));

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          _onJoinedCb?.call();
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          _onRemoteCb?.call(remoteUid, true);
        },
        onUserOffline: (connection, remoteUid, reason) {
          _onRemoteCb?.call(remoteUid, false);
        },
      ),
    );

    await _engine!.setChannelProfile(
      ChannelProfileType.channelProfileCommunication,
    );

    await _engine!.enableVideo();
    await _engine!.enableAudio();

    // Start local preview so self-view shows before join completes
    await _engine!.startPreview();

    await _engine!.joinChannel(
      token: token,
      channelId: roomName,
      uid: 0,
      options: const ChannelMediaOptions(
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  } catch (e) {
    // Fire onJoined so UI doesn't stay stuck on loading
    _onJoinedCb?.call();
  }
}

void lmsLeaveChannel() {
  try {
    _engine?.stopPreview();
    _engine?.leaveChannel();
    _engine?.release();
    _engine = null;
  } catch (_) {}
}

void lmsMuteMic(bool mute) {
  _engine?.muteLocalAudioStream(mute);
}

void lmsMuteCamera(bool mute) {
  _engine?.enableLocalVideo(!mute);
  _engine?.muteLocalVideoStream(mute);
}

void lmsSetPanelWidth(bool open) {}

void lmsStartRecording() {}

void lmsStopRecordingAndUpload(
  String sessionId,
  String backendUrl,
  String authToken,
) {}

Future<void> lmsEnableMediaAndPublish() async {}

Future<void> lmsStudentEnableAudio() async {}

Future<String> lmsToggleScreenShare() async => 'unsupported';
void lmsRequestFullscreen() {}
void lmsExitFullscreen() {}
void lmsRefreshVideoLayout() {}
void lmsSetParticipantNames(String localName, String remoteName) {}
void lmsSetVideoFit(String mode) {}
void lmsListenForScreenShareEnded(void Function() callback) {}

String registerLmsVideoView() => '';

Widget lmsGetLocalVideoWidget(String? viewName) {
  if (_engine == null) return const SizedBox.shrink();
  return AgoraVideoView(
    controller: VideoViewController(
      rtcEngine: _engine!,
      canvas: const VideoCanvas(uid: 0),
    ),
  );
}

Widget lmsGetRemoteVideoWidget(int uid, String channelId) {
  if (_engine == null) return const SizedBox.shrink();
  return AgoraVideoView(
    controller: VideoViewController.remote(
      rtcEngine: _engine!,
      canvas: VideoCanvas(uid: uid),
      connection: RtcConnection(channelId: _channelId),
    ),
  );
}
