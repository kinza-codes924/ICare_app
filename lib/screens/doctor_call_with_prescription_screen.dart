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
  bool _callEnded = false;
  bool _showForm = false;
  final PrescriptionToggleBridge _toggleBridge = PrescriptionToggleBridge();

  void _onCallEnded() {
    _toggleBridge.hide();
    if (mounted) setState(() => _callEnded = true);
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
    if (!isComplete) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      if (_callEnded) {
        Navigator.of(context).pop();
      } else if (_showForm) {
        // Call is still going — just close the panel, don't leave the call.
        _togglePanel();
      }
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
    if (_callEnded) {
      // Call ended (Jitsi hangup or the other side left) — the
      // prescription form is still exactly where it was, uninterrupted;
      // the doctor just finishes writing it full-width with no video.
      return InConsultationPrescriptionForm(
        consultationId: widget.consultationId,
        onPrescriptionComplete: _onPrescriptionComplete,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
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
          if (_showForm)
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
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
            )
          else if (!kIsWeb)
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
    );
  }
}
