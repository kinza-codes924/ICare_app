// Mobile — Jitsi Meet via InAppWebView.
//
// Loads the same JitsiMeetExternalAPI the web build uses (web/index.html
// lmsJitsiJoin) instead of navigating straight to https://domain/room. A plain
// room URL ignores config passed in the URL hash, which is why the session came
// up with Jitsi's stock UI: raw room id as the title, "Consultation" hangup
// labels, no polls tab, and no auto-recording. Driving external_api.js lets
// mobile use the exact configOverwrite/interfaceConfigOverwrite web does.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const String _jitsiDomain = 'vh.itserver.biz';

/// Mirrors _JITSI_TOOLBAR_BUTTONS in web/index.html — 'chat' and 'polls' are
/// what render the Chat / Polls / File Upload tabs; 'recording' is instructor-only.
const List<String> _toolbarButtons = [
  'microphone', 'camera', 'desktop', 'embedmeeting',
  'fullscreen', 'fodeviceselection', 'hangup', 'profile', 'chat', 'polls',
  'recording', 'etherpad', 'shareaudio',
  'settings', 'raisehand', 'videoquality', 'filmstrip',
  'stats', 'shortcuts', 'tileview', 'videobackgroundblur',
  'download', 'help', 'mute-everyone', 'security', 'toggle-camera',
  'select-background', 'noise-suppression', 'whiteboard',
];

void Function()? _onJoined;
InAppWebViewController? _webCtrl;

void lmsSetCallbacks({void Function(int, bool)? onRemote, void Function()? onJoined}) {
  _onJoined = onJoined;
}

String _pendingRoom = '';
String _pendingJwt = '';
String _pendingName = '';
String _pendingSubject = '';
bool _pendingIsInstructor = false;
bool _sessionClosed = false;

Future<void> lmsJoinChannel(String roomName, String displayName, bool isInstructor,
    {String jwt = '', String subject = '', String authToken = ''}) async {
  _pendingRoom = roomName;
  _pendingJwt = jwt.isNotEmpty ? jwt : authToken;
  _pendingName = displayName;
  _pendingSubject = subject;
  _pendingIsInstructor = isInstructor;
  _sessionClosed = false;
  await Future.delayed(const Duration(milliseconds: 500));
  _onJoined?.call();
}

void lmsLeaveChannel() {
  try { _webCtrl?.evaluateJavascript(source: 'window.icareLeave && window.icareLeave();'); } catch (_) {}
  try { _webCtrl?.loadUrl(urlRequest: URLRequest(url: WebUri('about:blank'))); } catch (_) {}
  _webCtrl = null;
}

/// Jibri only finalizes + uploads a recording once it receives an explicit stop
/// command, so this must run before lmsLeaveChannel when a session ends.
void lmsStopRecording() {
  try { _webCtrl?.evaluateJavascript(source: 'window.icareStopRecording && window.icareStopRecording();'); } catch (_) {}
}

void lmsMuteMic(bool mute) {}
void lmsMuteCamera(bool mute) {}
void lmsSetPanelWidth(bool open) {}
Future<void> lmsEnableMediaAndPublish() async {}

/// True once Jitsi fires readyToClose (its own hangup button was pressed).
bool lmsIsSessionClosed() => _sessionClosed;

void lmsHardRedirect(String path) {}

String registerLmsVideoView() => '';
Widget lmsGetLocalVideoWidget(String? viewName) => const SizedBox.shrink();
Widget lmsGetRemoteVideoWidget(int uid, String channelId) => const SizedBox.shrink();

void lmsListenForScreenShareEnded(void Function() callback) {}
void lmsListenForRemoteJoined(void Function(int uid) callback) {}
void lmsListenForRemoteLeft(void Function(int uid) callback) {}

String _jsString(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll("'", r"\'")
    .replaceAll('\n', ' ');

/// Host page that boots JitsiMeetExternalAPI with the same options as web.
String _buildHostHtml() {
  final toolbar = _pendingIsInstructor
      ? _toolbarButtons
      : _toolbarButtons.where((b) => b != 'recording').toList();
  final toolbarJs = toolbar.map((b) => "'$b'").join(',');
  final displayName = _pendingName.isNotEmpty
      ? _pendingName
      : (_pendingIsInstructor ? 'Instructor' : 'Student');

  return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<style>html,body{margin:0;padding:0;height:100%;background:#1C2333;overflow:hidden}#host{width:100%;height:100%}</style>
</head>
<body>
<div id="host"></div>
<script src="https://$_jitsiDomain/external_api.js"></script>
<script>
(function() {
  var api = null;
  function boot() {
    if (!window.JitsiMeetExternalAPI) { setTimeout(boot, 200); return; }
    api = new JitsiMeetExternalAPI('$_jitsiDomain', {
      roomName: '${_jsString(_pendingRoom)}',
      jwt: '${_jsString(_pendingJwt)}' || undefined,
      parentNode: document.getElementById('host'),
      width: '100%',
      height: '100%',
      configOverwrite: {
        prejoinPageEnabled: false,
        requireDisplayName: false,
        enableWelcomePage: false,
        enableClosePage: false,
        disableDeepLinking: true,
        disableInviteFunctions: true,
        toolbarButtons: [$toolbarJs],
        filmstrip: { disableResizable: false },
        startWithAudioMuted: false,
        startWithVideoMuted: false,
        disabledNotifications: ['notify.moderator'],
        subject: '${_jsString(_pendingSubject)}' || undefined
      },
      interfaceConfigOverwrite: {
        SHOW_JITSI_WATERMARK: false,
        SHOW_WATERMARK_FOR_GUESTS: false,
        SHOW_BRAND_WATERMARK: false,
        SHOW_POWERED_BY: false,
        HIDE_DEEP_LINKING_LOGO: true,
        MOBILE_APP_PROMO: false
      },
      userInfo: { displayName: '${_jsString(displayName)}' }
    });

    // Tells the server-side icare-custom.js which label set to use. Without
    // it the script stays in its default 'consultation' mode, which is why
    // the hangup menu read "End Consultation For All" / "Leave Consultation"
    // and the end screen said "The consultation has been terminated" inside
    // an LMS session. Re-sent on a short timer because the iframe's listener
    // is only attached once icare-custom.js has run.
    function pushContext() {
      try {
        var frame = document.querySelector('#host iframe');
        if (frame && frame.contentWindow) {
          frame.contentWindow.postMessage({ type: 'icare-context', mode: 'lms' }, '*');
        }
      } catch(e) {}
    }
    var ctxTries = 0;
    var ctxTimer = setInterval(function() {
      pushContext();
      if (++ctxTries > 40) clearInterval(ctxTimer);
    }, 500);

    api.on('videoConferenceJoined', function() {
      pushContext();
      var subject = '${_jsString(_pendingSubject)}';
      if (subject) { try { api.executeCommand('subject', subject); } catch(e) {} }
      if ($_pendingIsInstructor) {
        try { api.executeCommand('startRecording', { mode: 'file' }); } catch(e) {}
      }
    });
    // Dispose immediately on close so Jitsi's own "Thank you for using Jitsi
    // Meet" close page never gets a chance to render before Flutter navigates
    // back to the dashboard.
    api.on('readyToClose', function() {
      clearInterval(ctxTimer);
      try { if (api) { api.dispose(); api = null; } } catch(e) {}
      window.flutter_inappwebview.callHandler('icareClosed');
    });
    api.on('videoConferenceLeft', function() { window.flutter_inappwebview.callHandler('icareClosed'); });
  }

  window.icareStopRecording = function() {
    if (!api) return;
    try { api.executeCommand('stopRecording', 'file'); } catch(e) {}
  };
  window.icareLeave = function() {
    try { if (api) { api.dispose(); api = null; } } catch(e) {}
  };

  boot();
})();
</script>
</body>
</html>
''';
}

/// Full-screen Jitsi WebView — call from LmsLiveSessionScreen once joined.
Widget buildJitsiWebView() {
  return InAppWebView(
    // Served under the Jitsi origin so external_api.js and its iframe are
    // same-origin; a data:/about:blank base would break the postMessage bridge
    // the ExternalAPI relies on.
    initialData: InAppWebViewInitialData(
      data: _buildHostHtml(),
      mimeType: 'text/html',
      encoding: 'utf-8',
      baseUrl: WebUri('https://$_jitsiDomain/'),
    ),
    initialSettings: InAppWebViewSettings(
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      javaScriptEnabled: true,
      useHybridComposition: true,
      allowsBackForwardNavigationGestures: false,
      supportZoom: false,
      userAgent: 'Mozilla/5.0 (Linux; Android 11; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    ),
    onWebViewCreated: (ctrl) {
      _webCtrl = ctrl;
      ctrl.addJavaScriptHandler(
        handlerName: 'icareClosed',
        callback: (_) { _sessionClosed = true; return null; },
      );
    },
    // Surfaces Jitsi/ExternalAPI errors (failed startRecording, rejected
    // postMessage, etc) in logcat — otherwise they stay inside the WebView
    // and the only symptom is a feature silently not working.
    onConsoleMessage: (ctrl, msg) {
      debugPrint('[JitsiWebView] ${msg.messageLevel}: ${msg.message}');
    },
    onPermissionRequest: (ctrl, request) async =>
        PermissionResponse(resources: request.resources, action: PermissionResponseAction.GRANT),
  );
}
