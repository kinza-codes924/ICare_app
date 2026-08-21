import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:icare/screens/in_consultation_prescription_form.dart';
import 'package:icare/screens/reception_procedures_screen.dart';
import 'package:icare/screens/video_call.dart';
import 'package:icare/services/call_service.dart';
import 'package:icare/services/consultation_service.dart';
import 'package:icare/services/reception_service.dart';
import 'package:icare/utils/prescription_toggle_bridge.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/reception_prescription_live_preview.dart';

// Walk-in flow's prescription step.
//   1. Form-only (this screen, inside the reception ShellRoute) —
//      InConsultationPrescriptionForm full width, "Call Doctor" FAB
//      available if the receptionist wants to loop the doctor in.
//   2. Once "Call Doctor" is pressed, _ReceptionCallScreen (below) is
//      PUSHED on the root navigator — genuinely full-screen, no sidebar/
//      dashboard chrome — with the video full-width and a dismissible
//      READ-ONLY live preview panel of the doctor's prescription draft
//      (doctor_call_with_prescription_screen.dart is where the doctor
//      actually writes it — that screen autosaves every 5s, this one polls
//      the same draft on the same interval; the receptionist can close/
//      reopen the panel at will). Per client's explicit requests: full-
//      screen with no dashboard visible during the call, live sync, and a
//      panel the receptionist can toggle rather than a fixed permanent split.
// Ending the call pops back to this exact screen/state — walk-in details
// and the dashboard underneath were never touched, nothing is lost.
// Completing the prescription (on either side) moves on to Procedures.
class ReceptionPrescriptionScreen extends StatefulWidget {
  final String consultationId;
  final String patientName;

  const ReceptionPrescriptionScreen({
    super.key,
    required this.consultationId,
    required this.patientName,
  });

  @override
  State<ReceptionPrescriptionScreen> createState() => _ReceptionPrescriptionScreenState();
}

class _ReceptionPrescriptionScreenState extends State<ReceptionPrescriptionScreen> {
  final ReceptionService _receptionService = ReceptionService();
  bool _calling = false;

  void _goToProcedures() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ReceptionProceduresScreen(
          consultationId: widget.consultationId,
          patientName: widget.patientName,
        ),
      ),
    );
  }

  Future<void> _callDoctor() async {
    setState(() => _calling = true);
    try {
      final result = await _receptionService.getConsultation(widget.consultationId);
      final consultation = result['consultation'] as Map?;
      final doctor = consultation?['doctorId'];
      final doctorId = doctor is Map ? doctor['_id']?.toString() : doctor?.toString();
      final doctorName = doctor is Map ? (doctor['name'] ?? doctor['username'])?.toString() : null;
      if (!mounted) return;
      if (doctorId == null || doctorId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find the assigned doctor')),
        );
        return;
      }
      final user = await SharedPref().getUserData();
      final myId = user?.id ?? '';
      final myName = user?.name ?? 'Front Desk';

      // 'reception' — not the generic 'video' type — is how the doctor's
      // incoming-call screen knows to show the prescription form split
      // alongside the video (see incoming_call_listener.dart).
      await CallService().initiateCall(
        receiverId: doctorId,
        channelName: widget.consultationId,
        callerName: myName,
        callType: 'reception',
      );
      if (!mounted) return;
      // Pushed on the ROOT navigator, not swapped into this screen's own
      // body: this screen lives inside the reception ShellRoute (sidebar +
      // dashboard chrome), so a plain setState-driven layout swap still
      // renders underneath/around that chrome — that's exactly the
      // "dashboard dikh raha hai during the call" bug that was reported.
      // Escaping to the root navigator here gives a genuinely bare
      // full-screen call+preview with nothing else on screen, and popping
      // back on call-end returns to this exact screen/state (walk-in
      // details, dashboard underneath — all still intact, nothing lost).
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => _ReceptionCallScreen(
            consultationId: widget.consultationId,
            patientName: widget.patientName,
            doctorName: doctorName ?? 'Doctor',
            myId: myId,
            myName: myName,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _calling = false);
    }
  }

  Widget _buildPrescriptionForm() {
    return InConsultationPrescriptionForm(
      consultationId: widget.consultationId,
      walkInPatientName: widget.patientName,
      onPrescriptionComplete: (isComplete) {
        if (isComplete) {
          // The form pops itself on completion — schedule the forward
          // navigation for right after that pop finishes.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) _goToProcedures();
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildPrescriptionForm(),
        Positioned(
          bottom: 168,
          right: 24,
          child: FloatingActionButton.extended(
            heroTag: 'reception_call_doctor',
            onPressed: _calling ? null : _callDoctor,
            label: Text(_calling ? 'Calling…' : 'Call Doctor'),
            icon: const Icon(Icons.video_call_rounded),
            backgroundColor: AppColors.primaryColor,
          ),
        ),
        Positioned(
          // Sits above the app-wide WhatsApp floating button (bottom: 20,
          // right: 20, 64px tall) so the two never overlap.
          bottom: 100,
          right: 24,
          child: FloatingActionButton.extended(
            heroTag: 'reception_skip_prescription',
            onPressed: _goToProcedures,
            label: const Text('Skip Prescription'),
            icon: const Icon(Icons.arrow_forward_rounded),
            backgroundColor: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

// Genuinely full-screen — pushed on the root navigator by _callDoctor()
// above, no ShellRoute chrome (sidebar/dashboard) anywhere in this tree.
// Video is always full-width; the live prescription preview is a
// dismissible overlay panel the receptionist can open/close at will (per
// client's request — "receptionist ke paas woh hata bhi sake, dobara laga
// bhi sake"), not a fixed split that eats screen space permanently.
class _ReceptionCallScreen extends StatefulWidget {
  final String consultationId;
  final String patientName;
  final String doctorName;
  final String myId;
  final String myName;

  const _ReceptionCallScreen({
    required this.consultationId,
    required this.patientName,
    required this.doctorName,
    required this.myId,
    required this.myName,
  });

  @override
  State<_ReceptionCallScreen> createState() => _ReceptionCallScreenState();
}

class _ReceptionCallScreenState extends State<_ReceptionCallScreen> {
  bool _showPreview = false;
  final ConsultationService _consultationService = ConsultationService();
  final PrescriptionToggleBridge _toggleBridge = PrescriptionToggleBridge();

  @override
  void initState() {
    super.initState();
    // See doctor_call_with_prescription_screen.dart for why the open toggle
    // is a real DOM button on web instead of a Flutter FAB — a Flutter
    // widget stacked over VideoCall's live Jitsi iframe doesn't reliably
    // receive clicks once Jitsi has joined.
    _syncToggleVisibility();
  }

  @override
  void dispose() {
    _toggleBridge.dispose();
    super.dispose();
  }

  void _togglePreview() {
    setState(() => _showPreview = !_showPreview);
    _syncToggleVisibility();
  }

  void _syncToggleVisibility() {
    if (!kIsWeb) return;
    if (_showPreview) {
      _toggleBridge.hide();
    } else {
      _toggleBridge.show(side: 'left', onToggle: _togglePreview);
    }
  }

  Future<void> _onCallEnded() async {
    _toggleBridge.hide();
    if (!mounted) return;
    // If the doctor already completed the prescription live during the
    // call, skip straight to Procedures instead of falling back to
    // ReceptionPrescriptionScreen's plain (still-empty-looking) form —
    // that re-shown form is what looked like "the prescription form is
    // coming back again" to the receptionist.
    bool alreadyComplete = false;
    try {
      final draft = await _consultationService.getPrescriptionDraft(widget.consultationId);
      alreadyComplete = draft != null && (draft['isComplete'] == true || draft['status'] == 'active');
    } catch (_) {}
    if (!mounted) return;
    if (alreadyComplete) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReceptionProceduresScreen(
            consultationId: widget.consultationId,
            patientName: widget.patientName,
          ),
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Side-by-side, not stacked over the video — see doctor_call_with_
    // prescription_screen.dart's build() for why: any Flutter widget
    // overlaid directly on top of VideoCall's live Jitsi iframe (via
    // Positioned/Stack) can silently fail to receive clicks, including this
    // panel's own close (X) button.
    return Scaffold(
      backgroundColor: Colors.black,
      body: Row(
        children: [
          if (_showPreview)
            SizedBox(
              width: 340,
              child: Material(
                elevation: 8,
                child: Stack(
                  children: [
                    ReceptionPrescriptionLivePreview(consultationId: widget.consultationId),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Hide prescription preview',
                        onPressed: _togglePreview,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: VideoCall(
                    channelName: widget.consultationId,
                    remoteUserName: widget.doctorName,
                    currentUserId: widget.myId,
                    currentUserName: widget.myName,
                    consultationId: widget.consultationId,
                    onCallEnded: _onCallEnded,
                    popOnCallEnded: false,
                  ),
                ),
                if (!_showPreview && !kIsWeb)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: FloatingActionButton.extended(
                      heroTag: 'reception_show_preview',
                      onPressed: _togglePreview,
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
