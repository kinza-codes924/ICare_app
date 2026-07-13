import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/api_constants.dart';
import '../utils/shared_pref.dart';
import 'video_player_widget.dart';
import 'doc_preview_widget.dart';

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
    final qIndex = u.indexOf('?');
    final clean = qIndex > 0 ? u.substring(0, qIndex) : u;
    final dot = clean.lastIndexOf('.');
    if (dot == -1) return '';
    return clean.substring(dot);
  }

  bool get _isImage => ['.png', '.jpg', '.jpeg', '.gif', '.webp'].contains(_extension);

  bool get _isVideo =>
      ['.mp4', '.webm', '.mov', '.ogg', '.m3u8'].contains(_extension) ||
      _effectiveUrl.contains('/video/upload/');

  bool get _isPdf => _extension == '.pdf';

  @override
  Widget build(BuildContext context) {
    if (!_hasUrl) return const SizedBox.shrink();
    if (_isImage) return _buildImage();
    if (_isVideo) return _buildVideo();
    return _buildDocCard(context);
  }

  // ── Image ──────────────────────────────────────────────────────────────

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
        loadingBuilder: (ctx, child, prog) => prog == null
            ? child
            : const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
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

  // ── Video ──────────────────────────────────────────────────────────────

  Widget _buildVideo() {
    if (kIsWeb) {
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
    return _buildTapCard(
      icon: Icons.play_circle_fill_rounded,
      color: const Color(0xFF3B82F6),
      title: name ?? 'Video',
      subtitle: label ?? 'Tap to watch video',
      onTap: () => _launchUrl(_effectiveUrl),
    );
  }

  // ── Document / PDF ─────────────────────────────────────────────────────

  Widget _buildDocCard(BuildContext context) {
    final icon = _isPdf ? Icons.picture_as_pdf_rounded : Icons.description_outlined;
    final color = _isPdf ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    final defaultTitle = _isPdf ? 'View PDF' : 'View Document';

    return _buildTapCard(
      icon: icon,
      color: color,
      title: name?.isNotEmpty == true ? name! : defaultTitle,
      subtitle: label ?? 'Tap to preview',
      trailingIcon: Icons.preview_rounded,
      onTap: () => _openDocInApp(context),
    );
  }

  // ── Shared tap card ────────────────────────────────────────────────────

  Widget _buildTapCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    IconData trailingIcon = Icons.open_in_new_rounded,
  }) {
    return GestureDetector(
      onTap: onTap,
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
                    style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                ],
              ),
            ),
            Icon(trailingIcon, color: const Color(0xFF94A3B8), size: 16),
          ],
        ),
      ),
    );
  }

  // ── Open document inline in app ────────────────────────────────────────

  Future<void> _openDocInApp(BuildContext context) async {
    final proxyUrl = await _resolveUrl(_effectiveUrl);
    if (!context.mounted) return;

    final fileName = name?.isNotEmpty == true
        ? name!
        : _effectiveUrl.split('/').last.split('?').first;

    await showDocPreview(context, proxyUrl, fileName);
  }

  // Route files through backend proxies so the browser never touches restricted URLs.
  // Cloudinary raw files → doc-stream proxy
  // Vercel Blob private files → blob-download proxy
  Future<String> _resolveUrl(String original) async {
    try {
      final token = await SharedPref().getToken() ?? '';
      if (token.isEmpty) return original;
      final encoded = Uri.encodeComponent(original);
      final t = Uri.encodeComponent(token);

      if (original.contains('res.cloudinary.com')) {
        return '${ApiConstants.baseUrl}/upload/doc-stream?url=$encoded&token=$t';
      }
      // Public Vercel Blob URLs (.public.blob.vercel-storage.com) are directly accessible
      // via CDN — no proxy needed. Only private blob URLs need the blob-download proxy.
      if (original.contains('.public.blob.vercel-storage.com')) {
        return original;
      }
      if (original.contains('blob.vercel-storage.com')) {
        return '${ApiConstants.baseUrl}/upload/blob-download?url=$encoded&token=$t';
      }
      return original;
    } catch (_) {
      return original;
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
