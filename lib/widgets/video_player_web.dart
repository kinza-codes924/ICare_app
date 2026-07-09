// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerWidget({super.key, required this.videoUrl});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late final String _viewType;

  static bool _isDirectVideo(String url) {
    final lower = url.toLowerCase();
    return lower.contains('cloudinary.com') ||
        lower.endsWith('.mp4') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.m3u8') ||
        (lower.contains('/video/upload/') && !lower.contains('youtube'));
  }

  @override
  void initState() {
    super.initState();
    _viewType = 'video-${widget.videoUrl.hashCode}-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
      if (_isDirectVideo(widget.videoUrl)) {
        // HTML5 native video player for Cloudinary/direct URLs
        return html.VideoElement()
          ..src = widget.videoUrl
          ..controls = true
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.borderRadius = '8px'
          ..style.backgroundColor = '#000'
          ..setAttribute('playsinline', 'true')
          ..setAttribute('preload', 'metadata');
      } else {
        // iframe for YouTube/Vimeo embeds
        return html.IFrameElement()
          ..src = _toEmbedUrl(widget.videoUrl)
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%'
          ..setAttribute('allowfullscreen', 'true')
          ..setAttribute('allow',
              'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share');
      }
    });
  }

  static String _toEmbedUrl(String url) {
    if (url.contains('youtube.com/embed/')) return url;
    final short = RegExp(r'youtu\.be/([^?&\s]+)').firstMatch(url);
    if (short != null) return 'https://www.youtube.com/embed/${short.group(1)}';
    final watch = RegExp(r'[?&]v=([^&\s]+)').firstMatch(url);
    if (watch != null) return 'https://www.youtube.com/embed/${watch.group(1)}';
    final shorts = RegExp(r'shorts/([^?&\s]+)').firstMatch(url);
    if (shorts != null) return 'https://www.youtube.com/embed/${shorts.group(1)}';
    final vimeo = RegExp(r'vimeo\.com/(\d+)').firstMatch(url);
    if (vimeo != null) return 'https://player.vimeo.com/video/${vimeo.group(1)}';
    return url;
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
