// Web-only — Agora RTC + MediaRecorder for LMS live sessions
import 'dart:js_interop';
import 'dart:ui_web' as ui;
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

@JS('lmsAgoraJoin')
external JSPromise<JSString> _lmsAgoraJoinJS(
    JSString appId, JSString channel, JSString token, JSNumber uid, JSBoolean isInstructor);

@JS('lmsAgoraLeave')
external JSPromise<JSAny?> _lmsAgoraLeaveJS();

@JS('lmsAgoraMuteMic')
external void _lmsAgoraMuteMicJS(JSBoolean mute);

@JS('lmsAgoraMuteCamera')
external void _lmsAgoraMuteCameraJS(JSBoolean mute);

@JS('lmsStartRecording')
external void _lmsStartRecordingJS();

@JS('lmsStopRecordingAndUpload')
external void _lmsStopRecordingAndUploadJS(JSString sessionId, JSString backendUrl, JSString authToken);

@JS('lmsEnableMediaAndPublish')
external JSPromise<JSAny?> _lmsEnableMediaAndPublishJS();

@JS('lmsStudentEnableAudio')
external JSPromise<JSString> _lmsStudentEnableAudioJS();

@JS('lmsToggleScreenShare')
external JSPromise<JSString> _lmsToggleScreenShareJS();

@JS('lmsRequestFullscreen')
external void _lmsRequestFullscreenJS();

@JS('lmsExitFullscreen')
external void _lmsExitFullscreenJS();

@JS('lmsRefreshVideoLayout')
external void _lmsRefreshVideoLayoutJS();

@JS('lmsSetParticipantNames')
external void _lmsSetParticipantNamesJS(JSString localName, JSString remoteName);

@JS('lmsSetVideoFit')
external void _lmsSetVideoFitJS(JSString mode);

@JS('lmsSetTileName')
external void _lmsSetTileNameJS(JSNumber uid, JSString name);

// appId and token fetched by caller from AgoraService
Future<void> lmsJoinChannel(String roomName, String appId, String token, bool isInstructor) async {
  await _lmsAgoraJoinJS(appId.toJS, roomName.toJS, token.toJS, 0.toJS, isInstructor.toJS).toDart;
}

void lmsLeaveChannel() { _lmsAgoraLeaveJS(); }
void lmsMuteMic(bool mute) => _lmsAgoraMuteMicJS(mute.toJS);
void lmsMuteCamera(bool mute) => _lmsAgoraMuteCameraJS(mute.toJS);
void lmsSetPanelWidth(bool panelOpen) {}
void lmsStartRecording() => _lmsStartRecordingJS();
void lmsStopRecordingAndUpload(String sessionId, String backendUrl, String authToken) =>
    _lmsStopRecordingAndUploadJS(sessionId.toJS, backendUrl.toJS, authToken.toJS);
Future<void> lmsEnableMediaAndPublish() async {
  await _lmsEnableMediaAndPublishJS().toDart;
}

Future<void> lmsStudentEnableAudio() async {
  await _lmsStudentEnableAudioJS().toDart;
}

Future<String> lmsToggleScreenShare() async {
  final r = await _lmsToggleScreenShareJS().toDart;
  return r.toDart;
}

void lmsRequestFullscreen() => _lmsRequestFullscreenJS();
void lmsExitFullscreen() => _lmsExitFullscreenJS();
void lmsRefreshVideoLayout() => _lmsRefreshVideoLayoutJS();
void lmsSetParticipantNames(String localName, String remoteName) =>
    _lmsSetParticipantNamesJS(localName.toJS, remoteName.toJS);
void lmsSetVideoFit(String mode) => _lmsSetVideoFitJS(mode.toJS);
void lmsSetTileName(int uid, String name) => _lmsSetTileNameJS(uid.toJS, name.toJS);

void lmsListenForScreenShareEnded(void Function() callback) {
  web.window.addEventListener('lms-screen-share-ended', ((web.Event _) {
    callback();
  }).toJS);
}

/// Listen for a remote participant joining — fires when JS creates a new tile.
void lmsListenForRemoteJoined(void Function(int uid) callback) {
  web.window.addEventListener('lms-remote-joined', ((web.Event e) {
    try {
      final detail = (e as dynamic).detail;
      final uid = int.tryParse(detail?.toString() ?? '') ?? 0;
      if (uid > 0) callback(uid);
    } catch (_) {}
  }).toJS);
}

/// Listen for a remote participant leaving — fires when JS removes the tile.
void lmsListenForRemoteLeft(void Function(int uid) callback) {
  web.window.addEventListener('lms-remote-left', ((web.Event e) {
    try {
      final detail = (e as dynamic).detail;
      final uid = int.tryParse(detail?.toString() ?? '') ?? 0;
      if (uid > 0) callback(uid);
    } catch (_) {}
  }).toJS);
}

void lmsSetCallbacks({void Function(int, bool)? onRemote, void Function()? onJoined}) {}
Widget lmsGetLocalVideoWidget(String? viewName) => const SizedBox.shrink();
Widget lmsGetRemoteVideoWidget(int uid, String channelId) => const SizedBox.shrink();

/// Register the LMS host container as a Flutter platform view.
/// Creates a CSS Grid container (lms-grid-container) for remote tiles + a
/// small local preview pinned to the bottom-right corner.
String registerLmsVideoView() {
  const viewId = 'lms-jitsi-view';
  try {
    ui.platformViewRegistry.registerViewFactory(viewId, (int id) {
      final container = web.document.createElement('div') as web.HTMLDivElement;
      container.id = 'lms-jitsi-host';
      container.style.width = '100%';
      container.style.height = '100%';
      container.style.background = '#1C2333';
      container.style.position = 'relative';
      container.style.overflow = 'hidden';

      // Remote grid — fills entire area; JS creates per-UID tile divs inside
      final grid = web.document.createElement('div') as web.HTMLDivElement;
      grid.id = 'lms-grid-container';
      grid.style.width = '100%';
      grid.style.height = '100%';
      grid.style.display = 'grid';
      grid.style.gridTemplateColumns = '1fr';
      grid.style.gap = '4px';
      grid.style.padding = '4px';
      grid.style.boxSizing = 'border-box';
      container.appendChild(grid);

      // Local video — small preview pinned to bottom-right corner
      final local = web.document.createElement('div') as web.HTMLDivElement;
      local.id = 'lms-agora-local';
      local.style.position = 'absolute';
      local.style.bottom = '8px';
      local.style.right = '8px';
      local.style.width = '130px';
      local.style.height = '98px';
      local.style.background = '#000';
      local.style.borderRadius = '8px';
      local.style.overflow = 'hidden';
      local.style.zIndex = '20';
      local.style.border = '2px solid rgba(255,255,255,0.2)';
      container.appendChild(local);

      // Local name label
      final localName = web.document.createElement('div') as web.HTMLDivElement;
      localName.id = 'lms-local-name';
      localName.style.position = 'absolute';
      localName.style.bottom = '12px';
      localName.style.right = '12px';
      localName.style.background = 'rgba(0,0,0,0.6)';
      localName.style.color = '#fff';
      localName.style.fontSize = '9px';
      localName.style.fontWeight = '600';
      localName.style.padding = '2px 5px';
      localName.style.borderRadius = '3px';
      localName.style.zIndex = '25';
      localName.style.display = 'none';
      container.appendChild(localName);

      return container;
    });
  } catch (_) {}
  return viewId;
}
