import 'package:flutter/material.dart';

/// Opens a full-screen, swipeable preview of one or more clinic images,
/// starting at [initialIndex]. Tap the backdrop or the close button to
/// dismiss.
Future<void> showImagePreview(BuildContext context, List<String> paths, {int initialIndex = 0}) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (context, _, _) => _ImagePreviewScreen(paths: paths, initialIndex: initialIndex),
    ),
  );
}

class _ImagePreviewScreen extends StatefulWidget {
  final List<String> paths;
  final int initialIndex;

  const _ImagePreviewScreen({required this.paths, required this.initialIndex});

  @override
  State<_ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<_ImagePreviewScreen> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.paths.length,
              itemBuilder: (context, i) => Center(
                child: InteractiveViewer(
                  child: ClinicImage(path: widget.paths[i], fit: BoxFit.contain),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders a clinic/service photo from either a bundled asset path
/// (assets/clinic_photos/...) or a network URL (e.g. a curated Unsplash
/// photo) — callers don't need to know which kind a given path is.
class ClinicImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;

  const ClinicImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final isNetwork = path.startsWith('http://') || path.startsWith('https://');
    if (isNetwork) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => Container(
          width: width,
          height: height,
          color: const Color(0xFFF1F5F9),
        ),
      );
    }
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
    );
  }
}
