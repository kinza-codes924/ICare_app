import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// Mobile/Desktop: open video in external browser or native player
class VideoPlayerWidget extends StatelessWidget {
  final String videoUrl;
  const VideoPlayerWidget({super.key, required this.videoUrl});

  Future<void> _openVideo(BuildContext context) async {
    final uri = Uri.tryParse(videoUrl);
    if (uri != null) {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open video'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
          ),
          const SizedBox(height: 20),
          const Text(
            'Tap to watch video',
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _openVideo(context),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Open Video'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0036BC),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
