import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:icare/screens/certificate_templates_screen.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/video_player_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class LessonPlayer extends StatefulWidget {
  final Map<String, dynamic> lesson;
  final Map<String, dynamic>? nextLesson;
  final String? studentName;
  final String? courseTitle;
  final String? instructorName;
  final bool isLastLesson;
  final CertificateTemplate certificateTemplate;
  final bool certificateReleased; // instructor must release before student can download
  final String? enrollmentId;

  const LessonPlayer({
    super.key,
    required this.lesson,
    this.nextLesson,
    this.studentName,
    this.courseTitle,
    this.instructorName,
    this.isLastLesson = false,
    this.certificateTemplate = CertificateTemplate.classic,
    this.certificateReleased = false,
    this.enrollmentId,
  });

  @override
  State<LessonPlayer> createState() => _LessonPlayerState();
}

class _LessonPlayerState extends State<LessonPlayer> {
  bool _isCompleted = false;

  // ── helpers ──────────────────────────────────────────────────────────────

  String? _youtubeId(String url) {
    // youtu.be/ID
    final s = RegExp(r'youtu\.be/([^?&\s]+)').firstMatch(url);
    if (s != null) return s.group(1);
    // watch?v=ID
    final w = RegExp(r'[?&]v=([^&\s]+)').firstMatch(url);
    if (w != null) return w.group(1);
    // shorts/ID
    final sh = RegExp(r'shorts/([^?&\s]+)').firstMatch(url);
    if (sh != null) return sh.group(1);
    return null;
  }

  // ALL video URLs play in-app via VideoPlayerWidget (HTML5 for direct, iframe for YouTube)
  bool _isEmbeddable(String url) => url.trim().isNotEmpty;

  Future<void> _openExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Opens the YouTube/Vimeo iframe in a full-screen dialog.
  /// The dialog is separate from the scrollable lesson page,
  /// so NO iframe exists in the scrollable tree → scroll works freely.
  void _openVideoDialog(BuildContext context, String videoUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              // ── iframe video ──────────────────────────────────────────
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: VideoPlayerWidget(videoUrl: videoUrl),
                ),
              ),
              // ── close button ──────────────────────────────────────────
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final title = widget.lesson['title'] as String? ?? 'Lesson';
    final content = widget.lesson['content'] as String? ?? '';
    final videoUrl = widget.lesson['videoUrl'] as String? ??
        widget.lesson['video_url'] as String?;
    final hasVideo = videoUrl != null && videoUrl.trim().isNotEmpty;
    final ytId = hasVideo ? _youtubeId(videoUrl) : null;
    final embeddable = hasVideo && _isEmbeddable(videoUrl);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      // ── fully scrollable body — NO iframe here ─────────────────────────
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── VIDEO CARD (thumbnail + play, no iframe) ────────────────
            if (hasVideo)
              _VideoThumbnailCard(
                videoUrl: videoUrl,
                youtubeId: ytId,
                embeddable: embeddable,
                onPlay: embeddable
                    ? () => _openVideoDialog(context, videoUrl)
                    : () => _openExternal(videoUrl),
                onOpenTab: () => _openExternal(videoUrl),
              ),

            const SizedBox(height: 28),

            // ── TITLE ────────────────────────────────────────────────────
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),

            const SizedBox(height: 20),

            // ── LESSON CONTENT ───────────────────────────────────────────
            if (content.trim().isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  content,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF475569),
                    height: 1.7,
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // ── MARK COMPLETE + NEXT (side by side) ──────────────────────
            Row(
              children: [
                // Mark as Completed — small button on LEFT
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _isCompleted = !_isCompleted);
                    if (_isCompleted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Lesson marked as completed!'),
                          backgroundColor: Color(0xFF10B981),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: Icon(
                    _isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: _isCompleted ? const Color(0xFF10B981) : const Color(0xFF64748B),
                  ),
                  label: Text(
                    _isCompleted ? 'Completed' : 'Mark as Completed',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _isCompleted ? const Color(0xFF10B981) : const Color(0xFF475569),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _isCompleted ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
                    backgroundColor: _isCompleted ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),

                const Spacer(),

                // Next Lesson — button on RIGHT
                if (widget.nextLesson != null)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (ctx) => LessonPlayer(lesson: widget.nextLesson!),
                        ),
                      );
                    },
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('Next', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 32),

            // ── CERTIFICATE CARD (last lesson + completed) ──────────────
            if (widget.isLastLesson && _isCompleted)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.certificateReleased
                        ? [const Color(0xFFD4AF37).withValues(alpha: 0.15), const Color(0xFFD4AF37).withValues(alpha: 0.05)]
                        : [const Color(0xFF64748B).withValues(alpha: 0.08), const Color(0xFF64748B).withValues(alpha: 0.04)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: widget.certificateReleased
                      ? const Color(0xFFD4AF37).withValues(alpha: 0.4)
                      : const Color(0xFF94A3B8).withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    Icon(
                      widget.certificateReleased ? Icons.workspace_premium_rounded : Icons.lock_clock_rounded,
                      color: widget.certificateReleased ? const Color(0xFFD4AF37) : const Color(0xFF94A3B8),
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.certificateReleased ? '🎉 Congratulations!' : 'Course Completed!',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.certificateReleased
                          ? 'Your certificate is ready. View and download it below.'
                          : 'Your instructor has not yet released the certificate for this course. Check back soon.',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    if (widget.certificateReleased)
                    ElevatedButton.icon(
                      onPressed: () async {
                        final user = await SharedPref().getUserData();
                        if (!context.mounted) return;
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => LmsCertificateScreen(
                            studentName: widget.studentName ?? user?.name ?? 'Student',
                            courseTitle: widget.courseTitle ?? 'Course',
                            instructorName: widget.instructorName ?? 'Instructor',
                            template: widget.certificateTemplate,
                            completionDate: DateTime.now(),
                            enrollmentId: widget.enrollmentId,
                          ),
                        ));
                      },
                      icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                      label: const Text('View Certificate', style: TextStyle(fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Video thumbnail card — no iframe, fully Flutter-rendered → scroll works
// ─────────────────────────────────────────────────────────────────────────────

class _VideoThumbnailCard extends StatelessWidget {
  final String videoUrl;
  final String? youtubeId;
  final bool embeddable;
  final VoidCallback onPlay;
  final VoidCallback onOpenTab;

  const _VideoThumbnailCard({
    required this.videoUrl,
    required this.youtubeId,
    required this.embeddable,
    required this.onPlay,
    required this.onOpenTab,
  });

  /// Generate thumbnail URL from video URL
  String? _getThumbnailUrl() {
    if (youtubeId != null) {
      return 'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg';
    }
    // Cloudinary video thumbnail — replace /upload/ with /upload/w_800,h_450,c_fill,so_2/
    // and change extension to .jpg to get a frame thumbnail
    if (videoUrl.contains('cloudinary.com') && videoUrl.contains('/upload/')) {
      return videoUrl
          .replaceFirst('/upload/', '/upload/w_800,h_450,c_fill,so_2/')
          .replaceAll(RegExp(r'\.(mp4|webm|mov|avi|mkv)(\?.*)?$'), '.jpg');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final thumbUrl = _getThumbnailUrl();
    final isCloudinary = videoUrl.contains('cloudinary.com');

    return GestureDetector(
      onTap: onPlay,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── background: thumbnail or gradient ───────────────────────
              if (thumbUrl != null)
                Image.network(
                  thumbUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _buildVideoPlaceholder(isCloudinary),
                )
              else
                _buildVideoPlaceholder(isCloudinary),

              // ── dark overlay ─────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),

              // ── play button ──────────────────────────────────────────────
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Color(0xFF0F172A),
                    size: 44,
                  ),
                ),
              ),

              // ── "Click to watch" label ────────────────────────────────────
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Click to watch',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              // ── open in new tab (top-right) ──────────────────────────────
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: onOpenTab,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_new,
                            color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text('New tab',
                            style: TextStyle(
                                color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPlaceholder(bool isCloudinary) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isCloudinary
              ? [const Color(0xFF1E3A5F), const Color(0xFF0F172A)]
              : [const Color(0xFF1A1A2E), const Color(0xFF0F172A)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCloudinary ? Icons.videocam_rounded : Icons.play_circle_outline_rounded,
                color: Colors.white.withValues(alpha: 0.7),
                size: 36,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isCloudinary ? 'Video Lesson' : 'Video',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
