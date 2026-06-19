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
  bool _fullscreen = false;

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
      final uri = Uri.parse(widget.videoUrl);
      _ctrl = VideoPlayerController.networkUrl(uri);
      await _ctrl!.initialize();
      if (mounted) setState(() => _initialized = true);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    if (_fullscreen) _exitFullscreen();
    super.dispose();
  }

  void _enterFullscreen() {
    setState(() => _fullscreen = true);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  void _exitFullscreen() {
    setState(() => _fullscreen = false);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(widget.videoUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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

    final player = AspectRatio(
      aspectRatio: _fullscreen ? 16 / 9 : _ctrl!.value.aspectRatio,
      child: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            VideoPlayer(_ctrl!),
            if (_showControls) _controls(),
          ],
        ),
      ),
    );

    if (_fullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: player),
      );
    }
    return player;
  }

  Widget _controls() {
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
              onPressed: () => setState(
                () => playing ? _ctrl!.pause() : _ctrl!.play(),
              ),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${_fmt(pos)} / ${_fmt(dur)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed:
                      _fullscreen ? _exitFullscreen : _enterFullscreen,
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
          const Text(
            'Tap to open video',
            style: TextStyle(color: Colors.white70),
          ),
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
                borderRadius: BorderRadius.circular(10),
              ),
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
          const Text(
            'Video could not load',
            style: TextStyle(color: Colors.white70),
          ),
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
