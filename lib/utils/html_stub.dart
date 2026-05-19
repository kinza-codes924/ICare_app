// Stub for dart:html on non-web platforms
class Window {}
class Navigator {}
class Geolocation {}
class AnchorElement {}
class Document {
  Body? get body => null;
}
class Body {}

final window = Window();
final document = Document();
