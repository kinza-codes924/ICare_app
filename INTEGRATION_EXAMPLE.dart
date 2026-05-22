// ============================================================================
// VIDEO CONSULTATION INTEGRATION EXAMPLE
// Copy this code to your appointment/booking screens
// ============================================================================

import 'package:flutter/material.dart';
import 'package:icare/services/consultation_service.dart';
import 'package:icare/screens/consultation_chat_screen_v2.dart';
import 'package:icare/models/appointment_detail.dart';
import 'package:icare/utils/shared_pref.dart';

// ============================================================================
// EXAMPLE 1: Start Consultation Button (For Doctor/Patient)
// ============================================================================

class StartConsultationButton extends StatelessWidget {
  final AppointmentDetail appointment;
  final bool isDoctor;

  const StartConsultationButton({
    super.key,
    required this.appointment,
    required this.isDoctor,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _startConsultation(context),
      icon: const Icon(Icons.chat_rounded),
      label: const Text('Start Consultation'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
      ),
    );
  }

  Future<void> _startConsultation(BuildContext context) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final consultationService = ConsultationService();
      final sharedPref = SharedPref();
      
      // Get current user ID and name
      final currentUserId = await sharedPref.getUserId();
      final currentUserName = await sharedPref.getUserName();

      // Start consultation
      final result = await consultationService.startConsultationV2(
        appointmentId: appointment.id ?? '',
        patientId: appointment.patient?.id ?? '',
        doctorId: appointment.doctor?.id ?? '',
        reason: 'Video consultation',
      );

      // Close loading
      Navigator.pop(context);

      if (result['success'] == true) {
        final consultationId = result['consultationId'];

        // Navigate to chat screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConsultationChatScreenV2(
              consultationId: consultationId,
              appointment: appointment,
              isDoctor: isDoctor,
              currentUserId: currentUserId ?? '',
              currentUserName: currentUserName ?? 'User',
            ),
          ),
        );
      } else {
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to start consultation'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Close loading
      Navigator.pop(context);
      
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// ============================================================================
// EXAMPLE 2: Replace in booking_card.dart
// ============================================================================

/*
OLD CODE (Line ~106 in booking_card.dart):

onPressed: () {
  final channelName = appointment.channelName?.isNotEmpty == true
      ? appointment.channelName!
      : appointment.id;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => VideoCall(
        channelName: channelName,
        remoteUserName: selectedRole == 'Doctor'
            ? appointment.patientName
            : appointment.doctorName,
        appointmentId: appointment.id,
      ),
    ),
  );
},

NEW CODE (Replace with this):

onPressed: () async {
  // Show loading
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final consultationService = ConsultationService();
    final sharedPref = SharedPref();
    
    final currentUserId = await sharedPref.getUserId();
    final currentUserName = await sharedPref.getUserName();
    final isDoctor = selectedRole == 'Doctor';

    // Start consultation
    final result = await consultationService.startConsultationV2(
      appointmentId: appointment.id ?? '',
      patientId: appointment.patientId ?? '',
      doctorId: appointment.doctorId ?? '',
    );

    Navigator.pop(context); // Close loading

    if (result['success'] == true) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConsultationChatScreenV2(
            consultationId: result['consultationId'],
            appointment: appointment,
            isDoctor: isDoctor,
            currentUserId: currentUserId ?? '',
            currentUserName: currentUserName ?? 'User',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Failed to start')),
      );
    }
  } catch (e) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
},
*/

// ============================================================================
// EXAMPLE 3: Replace in bookings.dart
// ============================================================================

/*
OLD CODE (Line ~1073 in bookings.dart):

onPressed: () {
  final channelName = appt.channelName?.isNotEmpty == true
      ? appt.channelName!
      : appt.id;
  Navigator.of(ctx).push(
    MaterialPageRoute(
      builder: (_) => VideoCall(
        channelName: channelName,
        remoteUserName: appt.doctorName,
        appointmentId: appt.id,
      ),
    ),
  );
},

NEW CODE (Replace with this):

onPressed: () async {
  showDialog(
    context: ctx,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final consultationService = ConsultationService();
    final sharedPref = SharedPref();
    
    final currentUserId = await sharedPref.getUserId();
    final currentUserName = await sharedPref.getUserName();

    final result = await consultationService.startConsultationV2(
      appointmentId: appt.id ?? '',
      patientId: appt.patientId ?? '',
      doctorId: appt.doctorId ?? '',
    );

    Navigator.pop(ctx);

    if (result['success'] == true) {
      Navigator.push(
        ctx,
        MaterialPageRoute(
          builder: (_) => ConsultationChatScreenV2(
            consultationId: result['consultationId'],
            appointment: appt,
            isDoctor: false, // Patient side
            currentUserId: currentUserId ?? '',
            currentUserName: currentUserName ?? 'User',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Failed')),
      );
    }
  } catch (e) {
    Navigator.pop(ctx);
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
},
*/

// ============================================================================
// EXAMPLE 4: For Doctor Dashboard
// ============================================================================

class DoctorConsultationButton extends StatelessWidget {
  final AppointmentDetail appointment;

  const DoctorConsultationButton({
    super.key,
    required this.appointment,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _startConsultation(context),
      icon: const Icon(Icons.video_call_rounded),
      label: const Text('Start Consultation'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF8B5CF6),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  Future<void> _startConsultation(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final consultationService = ConsultationService();
      final sharedPref = SharedPref();
      
      final doctorId = await sharedPref.getUserId();
      final doctorName = await sharedPref.getUserName();

      final result = await consultationService.startConsultationV2(
        appointmentId: appointment.id ?? '',
        patientId: appointment.patient?.id ?? '',
        doctorId: doctorId ?? '',
      );

      Navigator.pop(context);

      if (result['success'] == true) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConsultationChatScreenV2(
              consultationId: result['consultationId'],
              appointment: appointment,
              isDoctor: true,
              currentUserId: doctorId ?? '',
              currentUserName: doctorName ?? 'Doctor',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to start consultation'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

// ============================================================================
// EXAMPLE 5: For Patient Dashboard
// ============================================================================

class PatientJoinConsultationButton extends StatelessWidget {
  final AppointmentDetail appointment;

  const PatientJoinConsultationButton({
    super.key,
    required this.appointment,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _joinConsultation(context),
      icon: const Icon(Icons.chat_rounded),
      label: const Text('Join Consultation'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  Future<void> _joinConsultation(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final consultationService = ConsultationService();
      final sharedPref = SharedPref();
      
      final patientId = await sharedPref.getUserId();
      final patientName = await sharedPref.getUserName();

      // If consultation already exists, just navigate
      // Otherwise start new consultation
      final result = await consultationService.startConsultationV2(
        appointmentId: appointment.id ?? '',
        patientId: patientId ?? '',
        doctorId: appointment.doctor?.id ?? '',
      );

      Navigator.pop(context);

      if (result['success'] == true) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConsultationChatScreenV2(
              consultationId: result['consultationId'],
              appointment: appointment,
              isDoctor: false,
              currentUserId: patientId ?? '',
              currentUserName: patientName ?? 'Patient',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to join consultation'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

// ============================================================================
// TESTING CODE
// ============================================================================

/*
To test if API is working, add this button anywhere:

ElevatedButton(
  onPressed: () async {
    final service = ConsultationService();
    final result = await service.startConsultationV2(
      appointmentId: 'test123',
      patientId: 'patient123',
      doctorId: 'doctor123',
    );
    print('Result: $result');
    // Should print: {success: true, consultationId: '...'}
  },
  child: Text('Test API'),
)
*/

// ============================================================================
// IMPORTANT NOTES
// ============================================================================

/*
1. Make sure to import these files:
   import 'package:icare/services/consultation_service.dart';
   import 'package:icare/screens/consultation_chat_screen_v2.dart';
   import 'package:icare/utils/shared_pref.dart';

2. Replace ALL instances of:
   VideoCall(...) 
   with:
   ConsultationChatScreenV2(...)

3. The chat screen includes:
   - Auto-send consent message
   - Timer (10 min minimum, 30 min maximum)
   - Voice call button
   - Video call button (opens VideoCall screen)
   - Prescription button (doctor only)
   - End consultation button

4. Backend is already deployed at:
   https://icare-backend-inky.vercel.app/api

5. All API endpoints are working and ready to use.
*/
