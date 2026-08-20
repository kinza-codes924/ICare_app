import 'package:flutter/material.dart';
import 'package:icare/screens/in_consultation_prescription_form.dart';
import 'package:icare/screens/reception_procedures_screen.dart';
import 'package:icare/screens/video_call.dart';
import 'package:icare/services/call_service.dart';
import 'package:icare/services/reception_service.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/utils/theme.dart';

// Thin host for the walk-in flow's prescription step — opens the shared
// InConsultationPrescriptionForm (appointment: null, walkInPatientName set),
// which already owns its own Scaffold/AppBar (Save Draft/Complete actions,
// back button), and moves on to Procedures once notes are saved. A floating
// "Skip" button overlays the form for a payment-only visit with no
// prescription at all. A "Call Doctor" button lets the receptionist bring
// the doctor onto a live Jitsi call from her own device — the walk-in
// patient has no app account, so she calls on the patient's behalf and lets
// them talk through her screen (per client's explicit direction).
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

      await CallService().initiateCall(
        receiverId: doctorId,
        channelName: widget.consultationId,
        callerName: myName,
        callType: 'video',
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoCall(
            channelName: widget.consultationId,
            remoteUserName: doctorName ?? 'Doctor',
            currentUserId: myId,
            currentUserName: myName,
            consultationId: widget.consultationId,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _calling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InConsultationPrescriptionForm(
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
        ),
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
