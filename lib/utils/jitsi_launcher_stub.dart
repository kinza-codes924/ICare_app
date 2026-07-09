import 'package:url_launcher/url_launcher.dart';

Future<void> launchJitsiMeet(String roomName) async {
  // On mobile: open Jitsi Meet in browser (or Jitsi app if installed)
  final uri = Uri.parse('https://meet.jit.si/$roomName');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
