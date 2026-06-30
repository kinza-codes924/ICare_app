import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'video_player_widget.dart';

/// Reusable widget for displaying quiz/assignment attachments.
/// Detects file type from the Cloudinary URL extension and renders:
///  - Images (.png, .jpg, .jpeg, .gif, .webp) inline via Image.network()
///  - Videos (.mp4, .mov, .webm, .ogg, .m3u8) inline via VideoPlayerWidget
///  - Documents (.pdf, .docx, .txt, etc.) as a tappable card that opens via url_launcher
///  - Falls back to url_launcher for unknown types
///
/// NOTE: Backend signing APIs (/upload/doc-url) have been completely bypassed.
/// Cloudinary raw URLs (secure_url) open directly in the browser.
class AttachmentViewer extends StatelessWidget {
  final String? url;
  final String? name;
  final String? label;
  final bool allowDownload;

  const AttachmentViewer({
    super.key,
    this.url,
    this.name,
    this.label,
    this.allowDownload = true,
  });

  bool get _hasUrl => url != null && url!.trim().isNotEmpty;

  String get _effectiveUrl => url!.trim();

  String get _extension {
    final u = _effectiveUrl.toLowerCase();
    // Strip query params
    final qIndex = u.indexOf('?');
    final clean = qIndex > 0 ? u.substring(0, qIndex) : u;
    final dot = clean.lastIndexOf('.');
    if (dot == -1) return '';
    return clean.substring(dot);
  }

  bool get _isImage {
    return _extension == '.png' ||
        _extension == '.jpg' ||
        _extension == '.jpeg' ||
        _extension == '.gif' ||
        _extension == '.webp';
  }

  bool get _isVideo {
    return _extension == '.mp4' ||
        _extension == '.webm' ||
        _extension == '.mov' ||
        _extension == '.ogg' ||
        _extension == '.m3u8' ||
        _effectiveUrl.contains('/video/upload/');
  }

  bool get _isPdf {
    return _extension == '.pdf';
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasUrl) return const SizedBox.shrink();

    if (_isImage) {
      return _buildImage();
    } else if (_isVideo) {
      return _buildVideo();
    } else {
      return _buildDocCard();
    }
  }

  // ── Image ────────────────────────────────────────────────────────────

  Widget _buildImage() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        _effectiveUrl,
        fit: BoxFit.contain,
        width: double.infinity,
        loadingBuilder: (ctx, child, prog) {
          if (prog == null) return child;
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (ctx, e, s) => Container(
          height: 120,
          color: const Color(0xFFF8FAFC),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8), size: 32),
                SizedBox(height: 4),
                Text('Image unavailable', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Video ────────────────────────────────────────────────────────────

  Widget _buildVideo() {
    if (kIsWeb) {
      // Use the existing inline HTML5 video player on web
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: VideoPlayerWidget(videoUrl: _effectiveUrl),
        ),
      );
    }

    // Mobile fallback: open externally
    return _buildOpenInBrowserCard(
      icon: Icons.play_circle_fill_rounded,
      color: const Color(0xFF3B82F6),
      title: name ?? 'Video',
      subtitle: label ?? 'Tap to watch video',
    );
  }

  // ── Documents (PDF, DOCX, etc.) ──────────────────────────────────────

  Widget _buildDocCard() {
    IconData icon;
    Color color;
    String defaultLabel;

    if (_isPdf) {
      icon = Icons.picture_as_pdf_rounded;
      color = const Color(0xFFEF4444);
      defaultLabel = 'View PDF';
    } else {
      icon = Icons.description_outlined;
      color = const Color(0xFF10B981);
      defaultLabel = 'View Document';
    }

    return _buildOpenInBrowserCard(
      icon: icon,
      color: color,
      title: name?.isNotEmpty == true ? name! : defaultLabel,
      subtitle: label ?? 'Tap to open in browser',
    );
  }

  // ── Shared card that opens URL in external browser ───────────────────

  Widget _buildOpenInBrowserCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return GestureDetector(
      onTap: () => _openInBrowser(_effectiveUrl),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: color,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new_rounded, color: Color(0xFF94A3B8), size: 16),
          ],
        ),
      ),
    );
  }

  // ── URL launcher (no backend API call) ───────────────────────────────

  Future<void> _openInBrowser(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('❌ Failed to open URL: $url — $e');
    }
  }
}