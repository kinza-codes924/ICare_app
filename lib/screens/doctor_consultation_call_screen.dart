import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:icare/models/appointment_detail.dart';
import 'package:icare/screens/in_consultation_prescription_form.dart';
import 'package:icare/screens/patient_history_form_screen.dart';
import 'package:icare/screens/video_call.dart';
import 'package:icare/utils/prescription_toggle_bridge.dart';
import 'package:icare/utils/html_stub.dart'
    // ignore: uri_does_not_exist
    if (dart.library.html) 'dart:html' as html;


// Doctor's call screen for a NORMAL (appointment-based) consultation — full-
// screen video with a dismissible/reopenable panel on the left holding
// either the Prescription form or the Patient History form (only one open
// at a time, like a tab bar). Per client's explicit instruction: Prescription
// and Patient History no longer live as standalone buttons on the chat
// screen (consultation_chat_screen_v2.dart) — they only exist during the
// live call now, same pattern already built for walk-in reception calls
// (doctor_call_with_prescription_screen.dart). Ending the call (hangup, "End
// Consultation for All", or the other side leaving) always pops straight
// back — no post-call fallback form, regardless of completion state.
class DoctorConsultationCallScreen extends StatefulWidget {
  final AppointmentDetail appointment;
  final String consultationId;
  final String remoteUserName;
  final bool isAudioOnly;
  final String currentUserId;
  final String currentUserName;
  final int consultationElapsedSeconds;
  final String? outgoingSignalId;

  const DoctorConsultationCallScreen({
    super.key,
    required this.appointment,
    required this.consultationId,
    required this.remoteUserName,
    this.isAudioOnly = false,
    required this.currentUserId,
    required this.currentUserName,
    this.consultationElapsedSeconds = 0,
    this.outgoingSignalId,
  });

  @override
  State<DoctorConsultationCallScreen> createState() => _DoctorConsultationCallScreenState();
}

enum _CallPanel { none, prescription, history }

class _DoctorConsultationCallScreenState extends State<DoctorConsultationCallScreen> {
  _CallPanel _panel = _CallPanel.none;
  String? _existingHistoryId;
  bool _prescriptionComplete = false;
  final CallTabButtonsBridge _toggleBridge = CallTabButtonsBridge();

  void _onCallEnded() {
    _toggleBridge.hide();
    // This screen was pushed from ConsultationChatScreenV2's own
    // _initiateCall (a normal Navigator.push, not a root-navigator escape
    // like the walk-in call screens) — popping lands both doctor and
    // patient back on the chat screen, same as the old flow before this
    // screen existed. Prescription/History only exist as in-call panels
    // now, but ending the CALL is not ending the CONSULTATION: that's still
    // a separate, explicit action from the chat screen's own "End
    // Consultation" button (auto-triggered at the max-duration timer, or
    // whenever the doctor chooses).
    if (mounted) Navigator.of(context).pop();
  }

  void _openPanel(_CallPanel panel) {
    final willOpen = _panel != panel;
    setState(() => _panel = willOpen ? panel : _CallPanel.none);
    _syncToggleVisibility();
    if (kIsWeb) {
      html.window.dispatchEvent(html.CustomEvent(
        willOpen ? 'icare-panel-open' : 'icare-panel-close',
      ));
    }
  }

  void _closePanel() {
    setState(() => _panel = _CallPanel.none);
    _syncToggleVisibility();
    if (kIsWeb) {
      html.window.dispatchEvent(html.CustomEvent('icare-panel-close'));
    }
  }

  void _syncToggleVisibility() {
    if (!kIsWeb) return;
    if (_panel != _CallPanel.none) {
      _toggleBridge.hide();
    } else {
      _toggleBridge.show(
        buttons: [
          {'id': 'prescription', 'label': 'Prescription', 'side': 'center', 'top': 16},
          {'id': 'history', 'label': 'Patient History', 'side': 'center', 'top': 72},
        ],
        onToggle: (id) => _openPanel(id == 'prescription' ? _CallPanel.prescription : _CallPanel.history),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // See prescription_toggle_bridge_web.dart / doctor_call_with_
    // prescription_screen.dart for why these are real DOM buttons on web
    // instead of Flutter FABs — a Flutter widget stacked over VideoCall's
    // live Jitsi iframe doesn't reliably receive clicks once Jitsi has
    // joined. On mobile there's no such iframe (native Agora view), so the
    // ordinary in-Flutter buttons below work fine.
    _syncToggleVisibility();
  }

  @override
  void dispose() {
    _toggleBridge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Side-by-side, not stacked over the video — see doctor_call_with_
    // prescription_screen.dart's build() for why: any Flutter widget
    // overlaid directly on top of VideoCall's live Jitsi iframe (via
    // Positioned/Stack) can silently fail to receive clicks or focus,
    // including text field typing inside a form panel.
    return Scaffold(
      backgroundColor: Colors.black,
      body: Row(
        children: [
          if (_panel != _CallPanel.none)
            SizedBox(
              width: 380,
              child: Material(
                elevation: 8,
                color: const Color(0xFFF8FAFC),
                child: _panel == _CallPanel.prescription
                    ? InConsultationPrescriptionForm(
                        appointment: widget.appointment,
                        consultationId: widget.consultationId,
                        liveSync: true,
                        onPrescriptionComplete: (isComplete) {
                          setState(() => _prescriptionComplete = isComplete);
                          if (isComplete) _closePanel();
                        },
                        onClose: _closePanel,
                      )
                    : PatientHistoryFormScreen(
                        appointment: widget.appointment,
                        consultationId: widget.consultationId,
                        existingHistoryId: _existingHistoryId,
                        onHistoryComplete: (historyId) {
                          setState(() => _existingHistoryId = historyId);
                          _closePanel();
                        },
                        onClose: _closePanel,
                      ),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: VideoCall(
                    channelName: widget.consultationId,
                    remoteUserName: widget.remoteUserName,
                    isAudioOnly: widget.isAudioOnly,
                    appointmentId: widget.appointment.id,
                    patientId: widget.appointment.patient?.id,
                    consultationId: widget.consultationId,
                    currentUserId: widget.currentUserId,
                    currentUserName: widget.currentUserName,
                    consultationElapsedSeconds: widget.consultationElapsedSeconds,
                    outgoingSignalId: widget.outgoingSignalId,
                    onCallEnded: _onCallEnded,
                    popOnCallEnded: false,
                  ),
                ),
                if (_panel == _CallPanel.none && !kIsWeb)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FloatingActionButton.extended(
                          heroTag: 'doctor_consult_show_prescription',
                          onPressed: () => _openPanel(_CallPanel.prescription),
                          icon: Icon(
                            Icons.description_outlined,
                            color: _prescriptionComplete ? Colors.green : null,
                          ),
                          label: const Text('Prescription'),
                        ),
                        const SizedBox(height: 12),
                        FloatingActionButton.extended(
                          heroTag: 'doctor_consult_show_history',
                          onPressed: () => _openPanel(_CallPanel.history),
                          icon: const Icon(Icons.history_edu_rounded),
                          label: const Text('Patient History'),
                        ),
                      ],
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
