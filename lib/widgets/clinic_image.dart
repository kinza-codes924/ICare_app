import 'package:flutter/material.dart';

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
