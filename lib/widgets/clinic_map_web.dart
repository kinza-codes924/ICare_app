// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// Embedded Google Maps iframe (no API key needed) for the clinic's
/// address, matching the reference site's in-page map.
class ClinicMapEmbed extends StatefulWidget {
  final String address;
  const ClinicMapEmbed({super.key, required this.address});

  @override
  State<ClinicMapEmbed> createState() => _ClinicMapEmbedState();
}

class _ClinicMapEmbedState extends State<ClinicMapEmbed> {
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'clinic-map-${widget.address.hashCode}';
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int id) {
      final query = Uri.encodeComponent(widget.address);
      return html.IFrameElement()
        // www.google.com (not maps.google.com) — matches the app's CSP
        // frame-src allowlist in web/index.html.
        ..src = 'https://www.google.com/maps?q=$query&output=embed'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewId);
  }
}
