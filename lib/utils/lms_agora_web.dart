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

@JS('lmsGetLocalUid')
external JSString _lmsGetLocalUidJS();

@JS('lmsApplyRemoteScreenShare')
external void _lmsApplyRemoteScreenShareJS(JSString sharingUid);

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

@JS('lmsTileAtPoint')
external JSString _lmsTileAtPointJS(JSNumber x, JSNumber y);

@JS('lmsToggleTileExpand')
external void _lmsToggleTileExpandJS(JSString uid);

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

String lmsGetLocalUid() => _lmsGetLocalUidJS().toDart;
void lmsApplyRemoteScreenShare(String sharingUid) =>
    _lmsApplyRemoteScreenShareJS(sharingUid.toJS);

void lmsRequestFullscreen() => _lmsRequestFullscreenJS();
void lmsExitFullscreen() => _lmsExitFullscreenJS();
void lmsRefreshVideoLayout() => _lmsRefreshVideoLayoutJS();
void lmsSetParticipantNames(String localName, String remoteName) =>
    _lmsSetParticipantNamesJS(localName.toJS, remoteName.toJS);
void lmsSetVideoFit(String mode) => _lmsSetVideoFitJS(mode.toJS);
void lmsSetTileName(int uid, String name) => _lmsSetTileNameJS(uid.toJS, name.toJS);

/// Hit-tests the remote video tiles against a viewport point — returns the
/// uid of the tile under (x, y) or '' if none. Needed because pointer events
/// land on Flutter's glass pane, never on the DOM tiles themselves.
String lmsTileAtPoint(double x, double y) => _lmsTileAtPointJS(x.toJS, y.toJS).toDart;

/// Manually expand/collapse a tile to a 90/10 split (tap-to-expand).
void lmsToggleTileExpand(String uid) => _lmsToggleTileExpandJS(uid.toJS);

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

      // Local video — small preview pinned to the TOP-right corner (same
      // placement as the doctor↔patient consultation screen), below the
      // Fit/Fill + fullscreen buttons Flutter overlays at the very top.
      // The bottom edge now belongs to the floating call controls, so the
      // preview can't live there anymore without colliding with them on
      // narrow screens. Sized with clamp() so it shrinks on mobile
      // viewports (16:9-ish box: width scales 84px-130px, height follows).
      final local = web.document.createElement('div') as web.HTMLDivElement;
      local.id = 'lms-agora-local';
      local.style.position = 'absolute';
      local.style.top = '48px';
      local.style.right = '8px';
      local.style.width = 'clamp(84px, 22vw, 130px)';
      local.style.height = 'clamp(63px, 16.5vw, 98px)';
      local.style.background = '#000';
      local.style.borderRadius = '8px';
      local.style.overflow = 'hidden';
      local.style.zIndex = '20';
      local.style.border = '2px solid rgba(255,255,255,0.2)';
      container.appendChild(local);

      // Local name label lives INSIDE the preview box itself (bottom-left,
      // like every remote tile's .lms-tile-name) instead of as a separate
      // absolutely-positioned sibling anchored to the same corner — the old
      // standalone #lms-local-name div sat at the same bottom-right corner
      // as this box and rendered directly on top of it/its video.
      final localName = web.document.createElement('div') as web.HTMLDivElement;
      localName.id = 'lms-local-name';
      localName.className = 'lms-tile-name';
      localName.style.display = 'none';
      local.appendChild(localName);

      return container;
    });
  } catch (_) {}
  return viewId;
}
