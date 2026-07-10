// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
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
  html.VideoElement? _video;

  bool _isDirect = false;
  bool _playing = false;
  bool _showControls = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Timer? _hideTimer;

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
    _isDirect = _isDirectVideo(widget.videoUrl);
    _viewType = 'video-${widget.videoUrl.hashCode}-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
      if (_isDirect) {
        // Native controls are disabled on purpose: Flutter web's platform-view
        // compositor intercepts/re-dispatches pointer events on top of the
        // HTML layer, which makes dragging the browser's built-in scrubber
        // stutter or fail. A Flutter-side Slider (below) drives currentTime
        // directly instead, so there's only one system handling the drag.
        final el = html.VideoElement()
          ..src = widget.videoUrl
          ..controls = false
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.backgroundColor = '#000'
          ..setAttribute('playsinline', 'true')
          ..setAttribute('preload', 'metadata');
        _video = el;
        el.onLoadedMetadata.listen((_) {
          if (!mounted) return;
          setState(() => _duration = Duration(milliseconds: (el.duration * 1000).round()));
        });
        el.onTimeUpdate.listen((_) {
          if (!mounted) return;
          setState(() => _position = Duration(milliseconds: (el.currentTime * 1000).round()));
        });
        el.onPlay.listen((_) {
          if (!mounted) return;
          setState(() => _playing = true);
        });
        el.onPause.listen((_) {
          if (!mounted) return;
          setState(() => _playing = false);
        });
        el.onEnded.listen((_) {
          if (!mounted) return;
          setState(() => _playing = false);
        });
        return el;
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

  void _togglePlay() {
    final v = _video;
    if (v == null) return;
    if (v.paused) {
      v.play();
    } else {
      v.pause();
    }
  }

  void _seekTo(double seconds) {
    final v = _video;
    if (v == null) return;
    v.currentTime = seconds;
    setState(() => _position = Duration(milliseconds: (seconds * 1000).round()));
  }

  void _bumpAutoHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _playing) setState(() => _showControls = false);
    });
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = HtmlElementView(viewType: _viewType);
    if (!_isDirect) return view;

    final durMs = _duration.inMilliseconds;
    final posMs = _position.inMilliseconds.clamp(0, durMs == 0 ? 0 : durMs);

    return GestureDetector(
      onTap: () {
        setState(() => _showControls = !_showControls);
        if (_showControls) _bumpAutoHide();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          view,
          if (_showControls)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                padding: const EdgeInsets.only(top: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        activeTrackColor: const Color(0xFF0036BC),
                        inactiveTrackColor: Colors.white24,
                        thumbColor: const Color(0xFF0036BC),
                      ),
                      child: Slider(
                        min: 0,
                        max: durMs > 0 ? durMs.toDouble() : 1,
                        value: posMs.toDouble(),
                        onChangeStart: (_) => _hideTimer?.cancel(),
                        onChanged: (v) => setState(() => _position = Duration(milliseconds: v.round())),
                        onChangeEnd: (v) {
                          _seekTo(v / 1000);
                          _bumpAutoHide();
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.white, size: 28),
                            onPressed: () {
                              _togglePlay();
                              _bumpAutoHide();
                            },
                          ),
                          Text('${_fmt(_position)} / ${_fmt(_duration)}',
                              style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
