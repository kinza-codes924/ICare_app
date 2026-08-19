import 'package:flutter/material.dart';
import 'package:icare/screens/in_consultation_prescription_form.dart';
import 'package:icare/screens/reception_procedures_screen.dart';

// Thin host for the walk-in flow's prescription step — opens the shared
// InConsultationPrescriptionForm (appointment: null, walkInPatientName set),
// which already owns its own Scaffold/AppBar (Save Draft/Complete actions,
// back button), and moves on to Procedures once notes are saved. A floating
// "Skip" button overlays the form for a payment-only visit with no
// prescription at all.
class ReceptionPrescriptionScreen extends StatelessWidget {
  final String consultationId;
  final String patientName;

  const ReceptionPrescriptionScreen({
    super.key,
    required this.consultationId,
    required this.patientName,
  });

  void _goToProcedures(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ReceptionProceduresScreen(
          consultationId: consultationId,
          patientName: patientName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InConsultationPrescriptionForm(
          consultationId: consultationId,
          walkInPatientName: patientName,
          onPrescriptionComplete: (isComplete) {
            if (isComplete) {
              // The form pops itself on completion — schedule the forward
              // navigation for right after that pop finishes.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) _goToProcedures(context);
              });
            }
          },
        ),
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton.extended(
            heroTag: 'reception_skip_prescription',
            onPressed: () => _goToProcedures(context),
            label: const Text('Skip Prescription'),
            icon: const Icon(Icons.arrow_forward_rounded),
            backgroundColor: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}
