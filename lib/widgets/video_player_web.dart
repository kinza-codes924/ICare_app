import 'dart:async';
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
        return _buildDirectPlayer(widget.videoUrl);
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

  // Everything below is plain DOM, built once per view factory call and
  // wired up with vanilla JS-interop event listeners.
  //
  // Why not Flutter widgets for the controls? Flutter web always composites
  // an HtmlElementView (a platform view / native <video>) ABOVE the rest of
  // the Flutter widget tree, so any Flutter Positioned/Slider drawn "on top"
  // of the video in a Stack is actually rendered underneath it and never
  // receives pointer events or shows up visually — that's why the previous
  // attempt's seek bar never appeared. The fix is to build the whole control
  // bar (seek bar, play/pause, mute, fullscreen) as sibling DOM nodes inside
  // the SAME html.DivElement as the <video>, so they live in the same
  // compositing layer and stack correctly with CSS.
  html.Element _buildDirectPlayer(String url) {
    final container = html.DivElement()
      ..style.position = 'relative'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#000'
      ..style.overflow = 'hidden';

    final video = html.VideoElement()
      ..src = url
      ..controls = false
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.display = 'block'
      ..style.backgroundColor = '#000'
      ..setAttribute('playsinline', 'true')
      ..setAttribute('preload', 'metadata');

    final seekBar = html.InputElement(type: 'range')
      ..min = '0'
      ..max = '1000'
      ..value = '0'
      ..style.width = '100%'
      ..style.height = '18px'
      ..style.margin = '0'
      ..style.cursor = 'pointer';
    seekBar.style.setProperty('accent-color', '#0036BC');

    final timeLabel = html.SpanElement()
      ..text = '0:00 / 0:00'
      ..style.color = '#fff'
      ..style.fontSize = '12px'
      ..style.fontFamily = 'inherit'
      ..style.marginLeft = '4px';

    final playBtn = html.ButtonElement()
      ..innerHtml = _iconSvg('play')
      ..style.background = 'transparent'
      ..style.border = 'none'
      ..style.cursor = 'pointer'
      ..style.padding = '4px'
      ..style.display = 'flex'
      ..style.alignItems = 'center';

    final muteBtn = html.ButtonElement()
      ..innerHtml = _iconSvg('volume')
      ..style.background = 'transparent'
      ..style.border = 'none'
      ..style.cursor = 'pointer'
      ..style.padding = '4px'
      ..style.display = 'flex'
      ..style.alignItems = 'center';

    final fullscreenBtn = html.ButtonElement()
      ..innerHtml = _iconSvg('fullscreen')
      ..style.background = 'transparent'
      ..style.border = 'none'
      ..style.cursor = 'pointer'
      ..style.padding = '4px'
      ..style.marginLeft = 'auto'
      ..style.display = 'flex'
      ..style.alignItems = 'center';

    final buttonRow = html.DivElement()
      ..style.display = 'flex'
      ..style.alignItems = 'center'
      ..style.padding = '0 10px 8px 6px'
      ..append(playBtn)
      ..append(muteBtn)
      ..append(timeLabel)
      ..append(html.DivElement()..style.flex = '1')
      ..append(fullscreenBtn);

    final controlsBar = html.DivElement()
      ..style.position = 'absolute'
      ..style.left = '0'
      ..style.right = '0'
      ..style.bottom = '0'
      ..style.background =
          'linear-gradient(to top, rgba(0,0,0,0.85), rgba(0,0,0,0.55) 60%, transparent)'
      ..style.paddingTop = '20px'
      ..style.transition = 'opacity 0.2s ease'
      ..style.opacity = '1'
      ..append(seekBar)
      ..append(buttonRow);

    container..append(video)..append(controlsBar);

    bool seeking = false;
    Timer? hideTimer;

    void showControls() {
      controlsBar.style.opacity = '1';
    }

    void scheduleHide() {
      hideTimer?.cancel();
      hideTimer = Timer(const Duration(seconds: 3), () {
        if (!video.paused) {
          controlsBar.style.opacity = '0';
        }
      });
    }

    String fmt(num seconds) {
      if (seconds.isNaN || seconds.isInfinite) return '0:00';
      final total = seconds.round();
      final h = total ~/ 3600;
      final m = (total % 3600) ~/ 60;
      final s = total % 60;
      final mm = h > 0 ? m.toString().padLeft(2, '0') : m.toString();
      final ss = s.toString().padLeft(2, '0');
      return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
    }

    // Chrome-recorded WebM (MediaRecorder output — how LMS session
    // recordings are produced) often ships with duration = Infinity in its
    // metadata header. The browser only computes the real duration once you
    // seek near the end, so on load we force a seek to a huge timestamp and
    // immediately back to 0 — the standard workaround for this Chromium bug.
    bool durationFixed = false;
    void fixDurationIfNeeded() {
      if (durationFixed) return;
      final d = video.duration;
      if (d.isInfinite || d.isNaN) {
        video.currentTime = 1e101;
        video.onTimeUpdate.first.then((_) {
          video.currentTime = 0;
          durationFixed = true;
        });
      } else {
        durationFixed = true;
      }
    }

    num effectiveDuration() {
      final d = video.duration;
      return (d.isFinite && !d.isNaN) ? d : 0;
    }

    void updateTimeLabel() {
      timeLabel.text = '${fmt(video.currentTime)} / ${fmt(effectiveDuration())}';
    }

    video.onLoadedMetadata.listen((_) {
      fixDurationIfNeeded();
      updateTimeLabel();
    });
    video.onDurationChange.listen((_) => updateTimeLabel());

    video.onTimeUpdate.listen((_) {
      if (!seeking) {
        final dur = effectiveDuration();
        if (dur > 0) {
          seekBar.valueAsNumber = (video.currentTime / dur) * 1000;
        }
      }
      updateTimeLabel();
    });

    video.onPlay.listen((_) {
      playBtn.innerHtml = _iconSvg('pause');
      scheduleHide();
    });
    video.onPause.listen((_) {
      playBtn.innerHtml = _iconSvg('play');
      showControls();
      hideTimer?.cancel();
    });
    video.onEnded.listen((_) {
      playBtn.innerHtml = _iconSvg('play');
      showControls();
      hideTimer?.cancel();
    });

    playBtn.onClick.listen((_) {
      if (video.paused) {
        video.play();
      } else {
        video.pause();
      }
    });

    muteBtn.onClick.listen((_) {
      video.muted = !video.muted;
      muteBtn.innerHtml = _iconSvg(video.muted ? 'muted' : 'volume');
    });

    seekBar.onInput.listen((_) {
      seeking = true;
      final dur = effectiveDuration();
      if (dur > 0) {
        final target = (seekBar.valueAsNumber ?? 0) / 1000 * dur;
        timeLabel.text = '${fmt(target)} / ${fmt(dur)}';
      }
      showControls();
      hideTimer?.cancel();
    });
    seekBar.onChange.listen((_) {
      final dur = effectiveDuration();
      if (dur > 0) {
        video.currentTime = (seekBar.valueAsNumber ?? 0) / 1000 * dur;
      }
      seeking = false;
      if (!video.paused) scheduleHide();
    });

    fullscreenBtn.onClick.listen((_) {
      if (html.document.fullscreenElement == null) {
        container.requestFullscreen();
      } else {
        html.document.exitFullscreen();
      }
    });

    container.onMouseMove.listen((_) {
      showControls();
      if (!video.paused) scheduleHide();
    });
    container.onClick.listen((event) {
      // Ignore clicks that originated on the controls bar itself.
      if (controlsBar.contains(event.target as html.Node?)) return;
      if (video.paused) {
        video.play();
      } else {
        video.pause();
      }
    });

    return container;
  }

  static String _iconSvg(String kind) {
    switch (kind) {
      case 'play':
        return '<svg width="26" height="26" viewBox="0 0 24 24" fill="white"><path d="M8 5v14l11-7z"/></svg>';
      case 'pause':
        return '<svg width="26" height="26" viewBox="0 0 24 24" fill="white"><path d="M6 5h4v14H6zm8 0h4v14h-4z"/></svg>';
      case 'volume':
        return '<svg width="22" height="22" viewBox="0 0 24 24" fill="white"><path d="M3 10v4h4l5 5V5L7 10H3zm13.5 2A4.5 4.5 0 0 0 14 7.97v8.05A4.5 4.5 0 0 0 16.5 12z"/></svg>';
      case 'muted':
        return '<svg width="22" height="22" viewBox="0 0 24 24" fill="white"><path d="M16.5 12A4.5 4.5 0 0 0 14 7.97v2.21l2.45 2.45c.03-.2.05-.42.05-.63zm2.5 0c0 .94-.2 1.82-.54 2.64l1.51 1.51A8.796 8.796 0 0 0 21 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71zM4.27 3L3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06a8.99 8.99 0 0 0 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3zM12 4L9.91 6.09 12 8.18V4z"/></svg>';
      case 'fullscreen':
        return '<svg width="20" height="20" viewBox="0 0 24 24" fill="white"><path d="M7 14H5v5h5v-2H7v-3zm-2-4h2V7h3V5H5v5zm12 7h-3v2h5v-5h-2v3zM14 5v2h3v3h2V5h-5z"/></svg>';
      default:
        return '';
    }
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
