import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/call_service.dart';
import '../utils/shared_pref.dart';
import '../utils/app_keys.dart';
import '../screens/video_call.dart';
import '../screens/consultation_chat_screen_v2.dart';
import '../screens/doctor_call_with_prescription_screen.dart';
import '../screens/doctor_consultation_call_screen.dart';
import '../models/appointment_detail.dart';
import '../services/consultation_service.dart';
import '../services/appointment_service.dart';

// Conditional import for web-only dart:js_interop
import '../utils/js_interop_stub.dart'
    if (dart.library.html) 'dart:js_interop';

@JS('playRingtone')
external void _jsPlayRingtone();

@JS('stopRingtone')
external void _jsStopRingtone();

void _playRingtone() {
  if (kIsWeb) {
    try { _jsPlayRingtone(); } catch (_) {}
  }
}

void _stopRingtone() {
  if (kIsWeb) {
    try { _jsStopRingtone(); } catch (_) {}
  }
}

/// Wraps the app and polls for incoming calls every 3 seconds.
/// When a call is detected it shows a full-screen incoming call dialog.
class IncomingCallListener extends StatefulWidget {
  final Widget child;

  const IncomingCallListener({super.key, required this.child});

  @override
  State<IncomingCallListener> createState() => _IncomingCallListenerState();
}

class _IncomingCallListenerState extends State<IncomingCallListener> {
  final CallService _callService = CallService();
  final SharedPref _sharedPref = SharedPref();
  Timer? _timer;
  bool _dialogShowing = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _checkIncoming());
  }

  Future<void> _checkIncoming() async {
    if (_dialogShowing || !mounted) return;

    // Only poll if user is logged in
    final token = await _sharedPref.getToken();
    if (token == null || token.isEmpty) return;

    debugPrint('🔔 Polling for incoming calls...');
    final signal = await _callService.checkIncomingCall();
    if (signal == null || !mounted) return;

    debugPrint('📞 Incoming call detected: ${signal['callerName']}');
    _dialogShowing = true;
    _playRingtone();
    try {
      await _showIncomingCallDialog(signal);
    } finally {
      _stopRingtone();
      _dialogShowing = false;
    }
  }

  Future<void> _showIncomingCallDialog(Map<String, dynamic> signal) async {
    final signalId = signal['id']?.toString() ?? '';
    final callerName = signal['callerName']?.toString() ?? 'Unknown';
    final channelName = signal['channelName']?.toString() ?? '';
    final callType = signal['callType']?.toString() ?? 'video';
    final isAudioOnly = callType == 'audio';

    final nav = appNavigatorKey.currentState;
    if (nav == null) {
      debugPrint('⚠️ Navigator not ready, skipping call dialog');
      return;
    }

    await nav.push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        barrierDismissible: false,
        pageBuilder: (ctx, _, _) => _IncomingCallDialog(
          callerName: callerName,
          isAudioOnly: isAudioOnly,
          isConsultation: callType == 'consultation',
          onAccept: () async {
            // Fire server ack in background — don't await it before navigating.
            // The old flow awaited respondToCall() before popping, which added
            // a full network round-trip of lag before the dialog even closed.
            _callService.respondToCall(signalId, 'accepted').ignore();
            final userData = await _sharedPref.getUserData();
            nav.pop();

            if (callType == 'consultation') {
              // Whoever answers, not always the patient. isDoctor was
              // hard-coded false here, so a doctor answering a patient's call
              // was treated as the patient — which is why the Prescription and
              // Patient History panels never appeared on that side, while the
              // doctor-initiated path (ConsultationChatScreenV2._initiateCall)
              // showed them fine. Give the doctor the same call screen.
              final isDoctorUser =
                  (userData?.role ?? '').toLowerCase() == 'doctor';
              AppointmentDetail? appointment;
              if (isDoctorUser) {
                // Those panels need a real AppointmentDetail — the signal
                // only carries the consultation id, so resolve it.
                try {
                  final cRes = await ConsultationService()
                      .getConsultationV2(channelName);
                  final apptId = cRes['consultation']?['appointmentId'];
                  if (apptId != null && apptId.toString().isNotEmpty) {
                    final aRes = await AppointmentService()
                        .getAppointmentById(apptId.toString());
                    if (aRes != null) {
                      appointment = AppointmentDetail.fromJson(aRes);
                    }
                  }
                } catch (e) {
                  debugPrint('Could not resolve appointment for call: $e');
                }
              }

              if (isDoctorUser && appointment != null) {
                nav.push(
                  MaterialPageRoute(
                    builder: (_) => DoctorConsultationCallScreen(
                      appointment: appointment!,
                      consultationId: channelName,
                      remoteUserName: callerName,
                      isAudioOnly: isAudioOnly,
                      currentUserId: userData?.id ?? '',
                      currentUserName: userData?.name ?? 'User',
                    ),
                  ),
                );
              } else {
                nav.push(
                  MaterialPageRoute(
                    builder: (_) => ConsultationChatScreenV2(
                      appointment: appointment,
                      isDoctor: isDoctorUser,
                      currentUserId: userData?.id ?? '',
                      currentUserName: userData?.name ?? 'User',
                      consultationId: channelName,
                      remoteUserName: callerName, // e.g. "Dr. Ahmed"
                    ),
                  ),
                );
              }
            } else if (callType == 'reception') {
              // Walk-in front-desk call — channelName is the walk-in
              // Consultation id. Doctor sees the same prescription form
              // they'd otherwise fill in after the call, split alongside
              // the video so they can write it live.
              nav.push(
                MaterialPageRoute(
                  builder: (_) => DoctorCallWithPrescriptionScreen(
                    consultationId: channelName,
                    callerName: callerName,
                    currentUserId: userData?.id ?? '',
                    currentUserName: userData?.name ?? 'User',
                  ),
                ),
              );
            } else {
              // A patient calling from inside a consultation sends callType
              // 'audio'/'video', never 'consultation' — so this branch, not
              // the one above, is what the doctor lands on. It opened a bare
              // VideoCall, which is why the Prescription and Patient History
              // panels were there when the doctor placed the call and missing
              // when the doctor answered one. channelName is the consultation
              // id in that case, so the same screen can be used.
              final isDoctorUser =
                  (userData?.role ?? '').toLowerCase() == 'doctor';
              AppointmentDetail? appointment;
              if (isDoctorUser && channelName.isNotEmpty) {
                try {
                  final cRes = await ConsultationService()
                      .getConsultationV2(channelName);
                  final c = (cRes['consultation'] ?? cRes) as Map<String, dynamic>?;
                  final rawAppt = c?['appointmentId'];
                  final apptId = (rawAppt is Map ? rawAppt['_id'] : rawAppt)?.toString();
                  if (apptId != null && apptId.isNotEmpty) {
                    final aRes =
                        await AppointmentService().getAppointmentById(apptId);
                    if (aRes != null) {
                      appointment = AppointmentDetail.fromJson(aRes);
                    }
                  }
                } catch (e) {
                  debugPrint('Could not resolve appointment for call: $e');
                }
              }

              if (isDoctorUser && appointment != null) {
                nav.push(
                  MaterialPageRoute(
                    builder: (_) => DoctorConsultationCallScreen(
                      appointment: appointment!,
                      consultationId: channelName,
                      remoteUserName: callerName,
                      isAudioOnly: isAudioOnly,
                      currentUserId: userData?.id ?? '',
                      currentUserName: userData?.name ?? 'User',
                    ),
                  ),
                );
              } else {
                nav.push(
                  MaterialPageRoute(
                    builder: (_) => VideoCall(
                      channelName: channelName,
                      remoteUserName: callerName,
                      isAudioOnly: isAudioOnly,
                      currentUserId: userData?.id ?? '',
                      currentUserName: userData?.name ?? 'User',
                    ),
                  ),
                );
              }
            }
          },
          onDecline: () {
            // Same pattern: fire-and-forget the server ack, close immediately.
            _callService.respondToCall(signalId, 'rejected').ignore();
            nav.pop();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _IncomingCallDialog extends StatelessWidget {
  final String callerName;
  final bool isAudioOnly;
  final bool isConsultation;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _IncomingCallDialog({
    required this.callerName,
    required this.isAudioOnly,
    this.isConsultation = false,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E3A5F), Color(0xFF0F172A)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: Colors.white24,
              child: Text(
                callerName.isNotEmpty ? callerName[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 40, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              callerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isConsultation
                  ? 'Your consultation has started'
                  : isAudioOnly
                      ? 'Incoming Audio Call'
                      : 'Incoming Video Call',
              style: const TextStyle(color: Colors.white60, fontSize: 14),
            ),
            const SizedBox(height: 36),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Decline
                GestureDetector(
                  onTap: onDecline,
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call_end_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Decline',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Accept
                GestureDetector(
                  onTap: onAccept,
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isAudioOnly
                              ? Icons.call_rounded
                              : Icons.videocam_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Accept',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

