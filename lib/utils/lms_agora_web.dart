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

void lmsListenForScreenShareEnded(void Function() callback) {
  web.window.addEventListener('lms-screen-share-ended', ((web.Event _) {
    callback();
  }).toJS);
}

void lmsSetCallbacks({void Function(int, bool)? onRemote, void Function()? onJoined}) {}
Widget lmsGetLocalVideoWidget(String? viewName) => const SizedBox.shrink();
Widget lmsGetRemoteVideoWidget(int uid, String channelId) => const SizedBox.shrink();

/// Register the LMS host container as a Flutter platform view.
/// Creates agora-remote and lms-agora-local divs INSIDE the platform view
/// (same pattern as the working doctor-patient call in video_call_web.dart).
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

      // Remote video — fills entire area
      final remote = web.document.createElement('div') as web.HTMLDivElement;
      remote.id = 'lms-agora-remote';
      remote.style.position = 'relative';
      remote.style.width = '100%';
      remote.style.height = '100%';
      remote.style.background = '#000';
      remote.style.overflow = 'hidden';
      container.appendChild(remote);

      // Remote name label
      final remoteName = web.document.createElement('div') as web.HTMLDivElement;
      remoteName.id = 'lms-remote-name';
      remoteName.style.position = 'absolute';
      remoteName.style.bottom = '8px';
      remoteName.style.left = '8px';
      remoteName.style.background = 'rgba(0,0,0,0.6)';
      remoteName.style.color = '#fff';
      remoteName.style.fontSize = '12px';
      remoteName.style.fontWeight = '600';
      remoteName.style.padding = '3px 8px';
      remoteName.style.borderRadius = '4px';
      remoteName.style.zIndex = '10';
      remoteName.style.display = 'none';
      remote.appendChild(remoteName);

      // Local video — small preview in bottom-right corner
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
