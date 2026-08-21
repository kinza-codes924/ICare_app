import 'package:flutter/material.dart';
import 'package:icare/screens/in_consultation_prescription_form.dart';
import 'package:icare/screens/video_call.dart';

// Doctor's side of a walk-in "Call Doctor" (reception's front-desk flow) —
// full-screen video on the left, the SAME prescription form the doctor
// would otherwise fill in after the call on the right, so they can write it
// live while talking to the receptionist/patient. Per client's explicit
// correction: the split view belongs on the DOCTOR's screen (the one who
// actually writes the prescription), not the receptionist's — the
// receptionist's own screen just shows the plain full-screen call.
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

  void _onCallEnded() {
    if (mounted) setState(() => _callEnded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_callEnded) {
      // Call ended (Jitsi hangup or the other side left) — the
      // prescription form is still exactly where it was, uninterrupted;
      // the doctor just finishes writing it full-width with no video.
      return InConsultationPrescriptionForm(
        consultationId: widget.consultationId,
        onPrescriptionComplete: (isComplete) {
          if (isComplete) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) Navigator.of(context).pop();
            });
          }
        },
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 6,
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
        Expanded(
          flex: 4,
          child: Material(
            color: const Color(0xFFF8FAFC),
            child: InConsultationPrescriptionForm(
              consultationId: widget.consultationId,
              // Autosaves every 5s while the doctor types, so the
              // receptionist's read-only preview (reception_prescription_
              // screen.dart) can poll the same draft and show it live.
              liveSync: true,
              onPrescriptionComplete: (isComplete) {
                if (isComplete) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) Navigator.of(context).pop();
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
