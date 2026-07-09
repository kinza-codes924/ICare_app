import 'package:web/web.dart' as web;

Future<void> launchJitsiMeet(String roomName) async {
  // On web: redirect the current browser tab to Jitsi Meet
  web.window.location.href = 'https://meet.jit.si/$roomName';
}
