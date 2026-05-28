// Stub for dart:html on non-web platforms

class _StyleElement {
  String width = '';
  String height = '';
  String objectFit = '';
  String borderRadius = '';
  String transform = '';
  String backgroundColor = '';
  String background = '';
  String position = '';
  String bottom = '';
  String right = '';
  String top = '';
  String left = '';
  String zIndex = '';
  String overflow = '';
  String border = '';
  String cssText = '';
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

class DivElement {
  String id = '';
  final _StyleElement style = _StyleElement();
  void append(dynamic element) {}
  void appendChild(dynamic element) {}
  void remove() {}
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
  void open(String url, String target) {}
}

class Body {
  void append(dynamic element) {}
  void appendChild(dynamic element) {}
}

class Document {
  Body? get body => Body();
  dynamic createElement(String tagName) => DivElement();
  dynamic getElementById(String id) => null;
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
