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

/// Register the LMS host container as a Flutter platform view
String registerLmsVideoView() {
  const viewId = 'lms-jitsi-view';
  try {
    ui.platformViewRegistry.registerViewFactory(viewId, (int id) {
      final container = web.document.createElement('div') as web.HTMLDivElement;
      container.id = 'lms-jitsi-host';
      container.style.width = '100%';
      container.style.height = '100%';
      container.style.background = '#1C2333';
      container.style.overflow = 'hidden';
      return container;
    });
  } catch (_) {}
  return viewId;
}
