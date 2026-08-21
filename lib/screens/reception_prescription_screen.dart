import 'package:flutter/material.dart';
import 'package:icare/screens/in_consultation_prescription_form.dart';
import 'package:icare/screens/reception_procedures_screen.dart';
import 'package:icare/screens/video_call.dart';
import 'package:icare/services/call_service.dart';
import 'package:icare/services/reception_service.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/reception_prescription_live_preview.dart';

// Walk-in flow's prescription step. Two states on the SAME screen (no
// navigation between them — an earlier version pushed VideoCall as a
// separate route, which took the receptionist out of this screen's state
// entirely and lost the walk-in details/dashboard underneath):
//   1. Form-only — InConsultationPrescriptionForm full width, "Call Doctor"
//      FAB available if the receptionist wants to loop the doctor in.
//   2. Call split view — once "Call Doctor" is pressed: video on the left,
//      a READ-ONLY live preview of the doctor's prescription draft on the
//      right (doctor_call_with_prescription_screen.dart is where the
//      doctor actually writes it — that screen autosaves every 5s, this
//      one polls the same draft on the same interval). Per client's
//      explicit request: "jab doctor fill kare to receptionist ke paas
//      bhi aa jaye... sync sahi se karna".
// Either state finishes the same way: onPrescriptionComplete(true) moves on
// to Procedures.
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

  // Set once the call actually starts — switches to the full-screen call
  // layout. Carries what VideoCall needs so it isn't refetched mid-call.
  String? _doctorId;
  String? _doctorName;
  String? _myId;
  String? _myName;

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
      // No navigation — just swap this same screen's layout to the
      // full-screen call. Staying on one screen/one route is what keeps
      // the walk-in form state and the reception dashboard underneath
      // intact.
      setState(() {
        _doctorId = doctorId;
        _doctorName = doctorName ?? 'Doctor';
        _myId = myId;
        _myName = myName;
      });
    } finally {
      if (mounted) setState(() => _calling = false);
    }
  }

  void _onCallEnded() {
    if (mounted) setState(() => _doctorId = null);
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
    final inCall = _doctorId != null;

    if (inCall) {
      return Row(
        children: [
          Expanded(
            flex: 6,
            child: VideoCall(
              channelName: widget.consultationId,
              remoteUserName: _doctorName ?? 'Doctor',
              currentUserId: _myId ?? '',
              currentUserName: _myName ?? 'Front Desk',
              consultationId: widget.consultationId,
              onCallEnded: _onCallEnded,
              popOnCallEnded: false,
            ),
          ),
          Expanded(
            flex: 4,
            child: ReceptionPrescriptionLivePreview(consultationId: widget.consultationId),
          ),
        ],
      );
    }

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
