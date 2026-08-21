import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:icare/screens/in_consultation_prescription_form.dart';
import 'package:icare/screens/video_call.dart';
import 'package:icare/utils/prescription_toggle_bridge.dart';

// Doctor's side of a walk-in "Call Doctor" (reception's front-desk flow) —
// full-screen video with a dismissible/reopenable prescription-form panel on
// the LEFT (same pattern as the receptionist's read-only live-preview panel
// in reception_prescription_screen.dart's _ReceptionCallScreen — client
// confirmed that pattern is correct and asked for the doctor's side to match
// it exactly, just editable instead of read-only, and on the left instead of
// the right). Starts CLOSED — client: "pehle se na khula ho, main kisi tab
// mein click karoon phir yeh aaye" — a small tab button opens it.
class DoctorCallWithPrescriptionScreen extends StatefulWidget {
  final String consultationId;
  final String callerName; // receptionist's display name, for the video tile
  final String currentUserId;
  final String currentUserName;

  const DoctorCallWithPrescriptionScreen({
    super.key,
    required this.consultationId,
    required this.callerName,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<DoctorCallWithPrescriptionScreen> createState() => _DoctorCallWithPrescriptionScreenState();
}

class _DoctorCallWithPrescriptionScreenState extends State<DoctorCallWithPrescriptionScreen> {
  bool _showForm = false;
  final PrescriptionToggleBridge _toggleBridge = PrescriptionToggleBridge();

  void _onCallEnded() {
    _toggleBridge.hide();
    // The prescription form only exists as the in-call panel — once the
    // call ends (however it ends: hangup, "End Consultation for All", the
    // other side leaving), go straight back to the dashboard. Per the
    // client's explicit instruction: no post-call fallback form, whether or
    // not the doctor completed it live during the call.
    if (mounted) Navigator.of(context).pop();
  }

  void _togglePanel() {
    setState(() => _showForm = !_showForm);
    _syncToggleVisibility();
  }

  void _syncToggleVisibility() {
    if (!kIsWeb) return;
    if (_showForm) {
      _toggleBridge.hide();
    } else {
      _toggleBridge.show(side: 'left', onToggle: _togglePanel);
    }
  }

  void _onPrescriptionComplete(bool isComplete) {
    if (!isComplete || !_showForm) return;
    // Just close the panel — the call keeps going, ending it is a separate,
    // explicit action (hangup / "End Consultation for All").
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) _togglePanel();
    });
  }

  @override
  void initState() {
    super.initState();
    // On web, a Flutter widget stacked over VideoCall's live Jitsi iframe
    // doesn't reliably receive clicks (platform-view/glass-pane click
    // routing loses to the iframe once Jitsi has joined) — so the toggle
    // button there is a real DOM element built by web/index.html's
    // showPrescriptionToggle(), with taps reported back via a window
    // CustomEvent (see PrescriptionToggleBridge). On mobile there's no such
    // iframe (native Agora view), so the ordinary in-Flutter FAB works fine.
    _syncToggleVisibility();
  }

  @override
  void dispose() {
    _toggleBridge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The panel is laid out SIDE-BY-SIDE with the video (a Row that shrinks
    // the video), never stacked on top of it. A Flutter widget overlaid
    // directly over VideoCall's live Jitsi iframe (via Positioned/Stack)
    // doesn't just fail to receive clicks — text fields inside it never
    // get focus either, so typing silently went nowhere. Giving the panel
    // its own non-overlapping region of the page is the only reliable fix;
    // the toggle button has the same constraint, hence the real-DOM-button
    // approach in PrescriptionToggleBridge on web (that button also needs
    // to sit outside the video's rectangle once it's shrunk).
    return Scaffold(
      backgroundColor: Colors.black,
      body: Row(
        children: [
          if (_showForm)
            SizedBox(
              width: 380,
              child: Material(
                elevation: 8,
                color: const Color(0xFFF8FAFC),
                child: InConsultationPrescriptionForm(
                  consultationId: widget.consultationId,
                  // Autosaves every 5s while the doctor types, so the
                  // receptionist's read-only preview can poll the same
                  // draft and show it live.
                  liveSync: true,
                  onPrescriptionComplete: _onPrescriptionComplete,
                  // Panel's own close (X) button — closes the panel, never
                  // navigates away from the live call.
                  onClose: _togglePanel,
                ),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: VideoCall(
                    channelName: widget.consultationId,
                    remoteUserName: widget.callerName,
                    currentUserId: widget.currentUserId,
                    currentUserName: widget.currentUserName,
                    consultationId: widget.consultationId,
                    onCallEnded: _onCallEnded,
                    popOnCallEnded: false,
                  ),
                ),
                if (!_showForm && !kIsWeb)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: FloatingActionButton.extended(
                      heroTag: 'doctor_show_prescription',
                      onPressed: _togglePanel,
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Prescription'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
