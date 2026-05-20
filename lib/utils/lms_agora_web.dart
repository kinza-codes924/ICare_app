// Web-only — uses dart:js_interop (same as doctor-patient video_call_web.dart)
import 'dart:js_interop';

@JS('lmsJoin')
external JSPromise _lmsJoinJS(String appId, String channelId, String? token, int uid);

@JS('lmsLeave')
external void _lmsLeaveJS();

@JS('lmsMuteMic')
external void _lmsMuteMicJS(bool mute);

@JS('lmsMuteCamera')
external void _lmsMuteCameraJS(bool mute);

@JS('lmsSetPanelWidth')
external void _lmsSetPanelWidthJS(bool panelOpen);

void lmsJoinChannel(String appId, String channelId, String? token, int uid) {
  _lmsJoinJS(appId, channelId, token, uid);
}

void lmsLeaveChannel() => _lmsLeaveJS();
void lmsMuteMic(bool mute) => _lmsMuteMicJS(mute);
void lmsMuteCamera(bool mute) => _lmsMuteCameraJS(mute);
void lmsSetPanelWidth(bool panelOpen) => _lmsSetPanelWidthJS(panelOpen);
