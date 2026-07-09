// Stub for dart:ui_web on non-web platforms
class _PlatformViewRegistry {
  void registerViewFactory(String viewType, dynamic Function(int) factory) {}
}

final platformViewRegistry = _PlatformViewRegistry();
