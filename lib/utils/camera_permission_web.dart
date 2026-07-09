import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<void> requestWebCameraPermission() async {
  final stream = await web.window.navigator.mediaDevices
      .getUserMedia(
          web.MediaStreamConstraints(video: true.toJS, audio: true.toJS))
      .toDart;
  final tracks = stream.getTracks().toDart;
  for (final t in tracks) {
    t.stop();
  }
}
