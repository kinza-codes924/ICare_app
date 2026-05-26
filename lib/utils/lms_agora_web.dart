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
      remote.style.width = '100%';
      remote.style.height = '100%';
      remote.style.background = '#1C2333';
      container.appendChild(remote);

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

      return container;
    });
  } catch (_) {}
  return viewId;
}
