import 'package:flutter/services.dart';

// Non-web platforms: SystemSound.play actually does something (native OS
// alert sound), unlike on web where it's a silent no-op — see
// notify_tone_web.dart for why that needed a real Web Audio API beep instead.
void playNotifyTone() {
  SystemSound.play(SystemSoundType.alert);
}
