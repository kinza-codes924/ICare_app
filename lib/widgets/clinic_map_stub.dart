import 'package:flutter/material.dart';

/// Non-web fallback — no iframe support, so nothing renders here. The
/// "Get Directions" button (url_launcher, works on all platforms) remains
/// the way to open the location on mobile.
class ClinicMapEmbed extends StatelessWidget {
  final String address;
  const ClinicMapEmbed({super.key, required this.address});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
