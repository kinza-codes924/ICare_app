// Web-only — Jitsi Meet External API for LMS live sessions
import 'dart:js_interop';
import 'dart:ui_web' as ui;
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

@JS('lmsJitsiJoin')
external void _lmsJitsiJoinJS(JSString roomName, JSString displayName, JSBoolean isInstructor, JSString jwt, JSString subject, JSString authToken);

@JS('lmsJitsiLeave')
external void _lmsJitsiLeaveJS();

@JS('lmsJitsiMuteMic')
external void _lmsJitsiMuteMicJS(JSBoolean mute);

@JS('lmsJitsiMuteCamera')
external void _lmsJitsiMuteCameraJS(JSBoolean mute);

@JS('lmsJitsiIsClosed')
external JSBoolean _lmsJitsiIsClosedJS();

@JS('lmsStopRecording')
external void _lmsStopRecordingJS();

Future<void> lmsJoinChannel(String roomName, String displayName, bool isInstructor, {String jwt = '', String subject = '', String authToken = ''}) async {
  _lmsJitsiJoinJS(roomName.toJS, displayName.toJS, isInstructor.toJS, jwt.toJS, subject.toJS, authToken.toJS);
}

void lmsLeaveChannel() => _lmsJitsiLeaveJS();

/// Sends Jibri an explicit stop-recording command. Must be called BEFORE
/// lmsLeaveChannel/dispose — Jibri only finalizes + uploads a recording on
/// receiving this; simply disposing the Jitsi iframe leaves it recording
/// forever server-side with nothing ever reaching Classwork.
void lmsStopRecording() {
  try { _lmsStopRecordingJS(); } catch (_) {}
}
void lmsMuteMic(bool mute) => _lmsJitsiMuteMicJS(mute.toJS);
void lmsMuteCamera(bool mute) => _lmsJitsiMuteCameraJS(mute.toJS);
void lmsSetPanelWidth(bool panelOpen) {}
Future<void> lmsEnableMediaAndPublish() async {} // no-op: Jitsi manages media internally

/// True after the user presses Jitsi's own hangup button (readyToClose event)
bool lmsIsSessionClosed() {
  try {
    return _lmsJitsiIsClosedJS().toDart;
  } catch (_) {
    return false;
  }
}

/// Full page navigation — clears all Jitsi/recorder/platform-view state.
/// SPA navigation after a Jitsi session leaves broken platform views behind
/// (blank screen + MutationObserver errors), so we hard-reload instead.
void lmsHardRedirect(String path) {
  web.window.location.assign(path);
}

void lmsSetCallbacks({void Function(int, bool)? onRemote, void Function()? onJoined}) {}
Widget lmsGetLocalVideoWidget(String? viewName) => const SizedBox.shrink();
Widget lmsGetRemoteVideoWidget(int uid, String channelId) => const SizedBox.shrink();

/// Register the LMS Jitsi host container as a Flutter platform view.
/// Creates a single div that lmsJitsiJoin() will embed the Jitsi iframe into.
String registerLmsVideoView() {
  // Use a unique view ID per registration so multiple sessions don't conflict
  final viewId = 'lms-jitsi-view-${DateTime.now().millisecondsSinceEpoch}';
  try {
    ui.platformViewRegistry.registerViewFactory(viewId, (int id) {
      final container = web.document.createElement('div') as web.HTMLDivElement;
      container.id = 'lms-jitsi-host';
      container.style.width = '100%';
      container.style.height = '100%';
      container.style.background = '#1C2333';
      container.style.position = 'relative';
      return container;
    });
  } catch (_) {}
  return viewId;
}
