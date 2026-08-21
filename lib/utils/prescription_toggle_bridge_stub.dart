// No-op mobile/desktop stub — see prescription_toggle_bridge_web.dart. The
// real DOM button only exists inside the Jitsi web page, so on mobile the
// doctor/reception call screens fall back to their own in-Flutter FAB
// instead of calling show()/hide() (see doctor_call_with_prescription_screen
// .dart / reception_prescription_screen.dart for the platform check).
import 'package:flutter/foundation.dart' show VoidCallback;

class PrescriptionToggleBridge {
  void show({required String side, required VoidCallback onToggle}) {}
  void hide() {}
  void dispose() {}
}
