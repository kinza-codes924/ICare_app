// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DocPreviewDialog extends StatefulWidget {
  final String proxyUrl;
  final String fileName;
  const DocPreviewDialog({super.key, required this.proxyUrl, required this.fileName});

  @override
  State<DocPreviewDialog> createState() => _DocPreviewDialogState();
}

class _DocPreviewDialogState extends State<DocPreviewDialog> {
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'doc-preview-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int id) {
      // Vercel Blob URLs are publicly accessible — use direct iframe so Chrome's
      // built-in PDF viewer renders them without any proxy or external service.
      // For Cloudinary/proxy URLs fall back to Google Docs Viewer.
      final isPublicUrl = widget.proxyUrl.contains('blob.vercel-storage.com') ||
          (!widget.proxyUrl.contains('cloudinary') && !widget.proxyUrl.contains('doc-stream'));
      final src = isPublicUrl
          ? widget.proxyUrl
          : 'https://docs.google.com/viewer?url=${Uri.encodeComponent(widget.proxyUrl)}&embedded=true';
      return html.IFrameElement()
        ..src = src
        ..style.cssText = 'width:100%;height:100%;border:none;background:#f8f9fa;';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            widget.fileName,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Download',
              onPressed: () {
                final sep = widget.proxyUrl.contains('?') ? '&' : '?';
                final dlUrl = '${widget.proxyUrl}${sep}download=1';
                launchUrl(Uri.parse(dlUrl), mode: LaunchMode.externalApplication);
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: HtmlElementView(viewType: _viewId),
      ),
    );
  }
}

Future<void> showDocPreview(BuildContext context, String proxyUrl, String fileName) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => DocPreviewDialog(proxyUrl: proxyUrl, fileName: fileName),
  );
}
