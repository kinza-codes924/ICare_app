import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DocPreviewDialog extends StatelessWidget {
  final String proxyUrl;
  final String fileName;
  const DocPreviewDialog({super.key, required this.proxyUrl, required this.fileName});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(fileName, overflow: TextOverflow.ellipsis),
      content: const Text('Document preview is available on the web app.\nWould you like to open it?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            launchUrl(Uri.parse(proxyUrl), mode: LaunchMode.externalApplication);
          },
          child: const Text('Open'),
        ),
      ],
    );
  }
}

Future<void> showDocPreview(BuildContext context, String proxyUrl, String fileName) {
  return showDialog(
    context: context,
    builder: (_) => DocPreviewDialog(proxyUrl: proxyUrl, fileName: fileName),
  );
}
