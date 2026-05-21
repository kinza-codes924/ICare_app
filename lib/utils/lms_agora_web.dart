// Web-only — uses dart:js_interop + dart:ui_web (same as doctor-patient video_call_web.dart)
import 'dart:js_interop';
import 'dart:ui_web' as ui;
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

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

Future<void> lmsJoinChannel(String appId, String channelId, String? token, int uid) async {
  _lmsJoinJS(appId, channelId, token, uid);
}

void lmsLeaveChannel() => _lmsLeaveJS();
void lmsMuteMic(bool mute) => _lmsMuteMicJS(mute);
void lmsMuteCamera(bool mute) => _lmsMuteCameraJS(mute);
void lmsSetPanelWidth(bool panelOpen) => _lmsSetPanelWidthJS(panelOpen);

// No-ops on web — video is handled via HtmlElementView + JS Agora SDK
void lmsSetCallbacks({void Function(int, bool)? onRemote, void Function()? onJoined}) {}
Widget lmsGetLocalVideoWidget(String? viewName) => const SizedBox.shrink();
Widget lmsGetRemoteVideoWidget(int uid, String channelId) => const SizedBox.shrink();

/// Register the video container as a Flutter platform view
/// This is the SAME approach as the working doctor-patient video_call_web.dart
String registerLmsVideoView() {
  const viewId = 'lms-video-view';
  try {
    ui.platformViewRegistry.registerViewFactory(viewId, (int id) {
      final container = web.document.createElement('div') as web.HTMLDivElement;
      container.id = 'lms-video-grid';
      container.style.width = '100%';
      container.style.height = '100%';
      container.style.background = '#1C2333';
      container.style.position = 'relative';

      // Remote video — full area
      final remote = web.document.createElement('div') as web.HTMLDivElement;
      remote.id = 'lms-remote-main';
      remote.style.width = '100%';
      remote.style.height = '100%';
      remote.style.background = '#1C2333';
      container.appendChild(remote);

      // Local PiP — bottom right
      final local = web.document.createElement('div') as web.HTMLDivElement;
      local.id = 'lms-local-video';
      local.style.cssText = 'position:absolute;bottom:16px;right:16px;width:180px;height:135px;'
          'border-radius:10px;overflow:hidden;background:#2D3748;z-index:10;'
          'border:2px solid rgba(255,255,255,0.5);';
      container.appendChild(local);

      return container;
    });
  } catch (_) {}
  return viewId;
}
