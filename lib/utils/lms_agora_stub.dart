// Mobile Agora RTC implementation for LMS live sessions
import 'package:flutter/widgets.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

RtcEngine? _engine;
String _channelId = '';
int _localUid = 0;
void Function(int uid, bool joined)? _onRemoteCb;
void Function()? _onJoinedCb;

// VideoViewController instances (and the native SurfaceView/TextureView each
// one owns on Android) must be reused across rebuilds, not recreated every
// time lmsGetRemoteVideoWidget/lmsGetLocalVideoWidget is called. This screen
// rebuilds on every 2s poll and on every setState (e.g. toggling
// screen-share), and building a fresh AgoraVideoView/VideoViewController
// each time — without disposing the previous one — left orphaned native
// surfaces on Android that kept painting at their last screen position,
// which is what made a participant's own self-preview appear to "clash"
// into a completely different tile the moment the layout changed (e.g. when
// someone started screen-sharing). Caching by uid, and disposing only when
// that uid actually leaves the channel, fixes this.
VideoViewController? _localController;
final Map<int, VideoViewController> _remoteControllers = {};

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
      for (final c in _remoteControllers.values) {
        c.dispose();
      }
      _remoteControllers.clear();
      _localController?.dispose();
      _localController = null;
      await _engine!.leaveChannel();
      await _engine!.release();
      _engine = null;
    }

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: appId));

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          _localUid = connection.localUid ?? 0;
          _onJoinedCb?.call();
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          _onRemoteCb?.call(remoteUid, true);
        },
        onUserOffline: (connection, remoteUid, reason) {
          _remoteControllers.remove(remoteUid)?.dispose();
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
    for (final c in _remoteControllers.values) {
      c.dispose();
    }
    _remoteControllers.clear();
    _localController?.dispose();
    _localController = null;
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
String lmsGetLocalUid() => _localUid > 0 ? _localUid.toString() : '';
String lmsTileAtPoint(double x, double y) => '';
void lmsToggleTileExpand(String uid) {}
void lmsApplyRemoteScreenShare(String sharingUid) {}
void lmsRequestFullscreen() {}
void lmsExitFullscreen() {}
void lmsRefreshVideoLayout() {}
void lmsSetParticipantNames(String localName, String remoteName) {}
void lmsSetVideoFit(String mode) {}
void lmsListenForScreenShareEnded(void Function() callback) {}
void lmsListenForRemoteJoined(void Function(int uid) callback) {}
void lmsListenForRemoteLeft(void Function(int uid) callback) {}
void lmsSetTileName(int uid, String name) {}

String registerLmsVideoView() => '';

Widget lmsGetLocalVideoWidget(String? viewName) {
  if (_engine == null) return const SizedBox.shrink();
  _localController ??= VideoViewController(
    rtcEngine: _engine!,
    canvas: const VideoCanvas(uid: 0),
  );
  return AgoraVideoView(controller: _localController!);
}

Widget lmsGetRemoteVideoWidget(int uid, String channelId) {
  if (_engine == null) return const SizedBox.shrink();
  final controller = _remoteControllers.putIfAbsent(
    uid,
    () => VideoViewController.remote(
      rtcEngine: _engine!,
      canvas: VideoCanvas(uid: uid),
      connection: RtcConnection(channelId: _channelId),
    ),
  );
  return AgoraVideoView(controller: controller);
}
