// Stub for dart:html on non-web platforms

class _StyleElement {
  String width = '';
  String height = '';
  String objectFit = '';
  String borderRadius = '';
  String transform = '';
}

class MediaStreamTrack {
  bool enabled = true;
  void stop() {}
}

class MediaStream {
  List<MediaStreamTrack> getVideoTracks() => [];
  List<MediaStreamTrack> getAudioTracks() => [];
  List<MediaStreamTrack> getTracks() => [];
}

class VideoElement {
  bool autoplay = false;
  bool muted = false;
  final _StyleElement style = _StyleElement();
  MediaStream? srcObject;
}

class MediaDevices {
  Future<MediaStream> getUserMedia(dynamic constraints) async => MediaStream();
}

class Coords {
  double? get latitude => null;
  double? get longitude => null;
}

class Geoposition {
  Coords? get coords => Coords();
}

class Geolocation {
  Future<Geoposition> getCurrentPosition() async {
    throw UnsupportedError('Geolocation not supported on this platform');
  }
}

class Navigator {
  Geolocation get geolocation => Geolocation();
  MediaDevices get mediaDevices => MediaDevices();
}

class Window {
  Navigator get navigator => Navigator();
}

class Body {
  void append(dynamic element) {}
}

class Document {
  Body? get body => Body();
}

class AnchorElement {
  String href = '';
  String target = '';
  String rel = '';
  String download = '';
  void click() {}
  void remove() {}
}

final window = Window();
final document = Document();
