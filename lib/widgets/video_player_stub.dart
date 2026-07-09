import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerWidget({super.key, required this.videoUrl});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _ctrl;
  bool _initialized = false;
  bool _error = false;
  bool _showControls = true;

  static bool _isDirect(String url) {
    final l = url.toLowerCase();
    return l.contains('cloudinary.com') ||
        l.endsWith('.mp4') ||
        l.endsWith('.webm') ||
        l.endsWith('.mov') ||
        l.endsWith('.ogg') ||
        l.endsWith('.m3u8') ||
        (l.contains('/video/upload/') && !l.contains('youtube'));
  }

  @override
  void initState() {
    super.initState();
    if (_isDirect(widget.videoUrl)) _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _ctrl!.initialize();
      if (mounted) setState(() => _initialized = true);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(widget.videoUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openFullscreen() {
    if (_ctrl == null || !_initialized) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenPlayer(controller: _ctrl!),
      ),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDirect(widget.videoUrl)) return _externalButton();
    if (_error) return _errorState();
    if (!_initialized) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Colors.black,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _ctrl!.value.aspectRatio,
      child: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            VideoPlayer(_ctrl!),
            if (_showControls) _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    final playing = _ctrl!.value.isPlaying;
    final pos = _ctrl!.value.position;
    final dur = _ctrl!.value.duration;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black87],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: IconButton(
              iconSize: 52,
              icon: Icon(
                playing
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_filled_rounded,
                color: Colors.white,
              ),
              onPressed: () =>
                  setState(() => playing ? _ctrl!.pause() : _ctrl!.play()),
            ),
          ),
          VideoProgressIndicator(
            _ctrl!,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: Color(0xFF0036BC),
              bufferedColor: Colors.white38,
              backgroundColor: Colors.white24,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
          Padding(
            padding:
                const EdgeInsets.only(left: 12, right: 4, bottom: 4),
            child: Row(
              children: [
                Text(
                  '${_fmt(pos)} / ${_fmt(dur)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.fullscreen, color: Colors.white, size: 24),
                  onPressed: _openFullscreen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _externalButton() {
    return Container(
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.play_circle_outline, color: Colors.white, size: 64),
          const SizedBox(height: 16),
          const Text('Tap to open video',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _openExternal,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Open Video'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0036BC),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Container(
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          const Text('Video could not load',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _openExternal,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Open in Browser'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0036BC),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Fullscreen page ─────────────────────────────────────────────────────────

class _FullscreenPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  const _FullscreenPlayer({required this.controller});

  @override
  State<_FullscreenPlayer> createState() => _FullscreenPlayerState();
}

class _FullscreenPlayerState extends State<_FullscreenPlayer> {
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: ctrl.value.aspectRatio,
                child: VideoPlayer(ctrl),
              ),
            ),
            if (_showControls)
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent, Colors.black87],
                    stops: [0.0, 0.4, 1.0],
                  ),
                ),
                child: Column(
                  children: [
                    // Top bar
                    SafeArea(
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.fullscreen_exit,
                                color: Colors.white, size: 28),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Center play/pause
                    ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: ctrl,
                      builder: (_, v, _) => Center(
                        child: IconButton(
                          iconSize: 64,
                          icon: Icon(
                            v.isPlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_filled_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () =>
                              v.isPlaying ? ctrl.pause() : ctrl.play(),
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Bottom seek + time
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: ctrl,
                        builder: (_, v, _) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            VideoProgressIndicator(
                              ctrl,
                              allowScrubbing: true,
                              colors: const VideoProgressColors(
                                playedColor: Color(0xFF0036BC),
                                bufferedColor: Colors.white38,
                                backgroundColor: Colors.white24,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 4, right: 4, bottom: 12),
                              child: Row(
                                children: [
                                  Text(
                                    '${_fmt(v.position)} / ${_fmt(v.duration)}',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
