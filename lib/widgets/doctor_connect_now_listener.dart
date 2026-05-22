import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/connect_now_service.dart';
import '../services/consultation_service.dart';
import '../utils/shared_pref.dart';
import '../utils/app_keys.dart';
import '../screens/consultation_chat_screen_v2.dart';
import '../models/appointment_detail.dart';
import '../models/user.dart';

/// Wraps the doctor's app and polls for Connect Now requests every 5 seconds.
class DoctorConnectNowListener extends StatefulWidget {
  final Widget child;

  const DoctorConnectNowListener({super.key, required this.child});

  @override
  State<DoctorConnectNowListener> createState() => _DoctorConnectNowListenerState();
}

class _DoctorConnectNowListenerState extends State<DoctorConnectNowListener> {
  final ConnectNowService _service = ConnectNowService();
  final SharedPref _sharedPref = SharedPref();
  Timer? _timer;
  bool _dialogShowing = false;

  // In-memory cache (fast lookup)
  final Set<String> _handledRequestIds = {};

  // SharedPreferences key for persisting handled IDs across app restarts
  static const String _kHandledKey = 'connect_now_handled_ids';

  @override
  void initState() {
    super.initState();
    _loadHandledIds().then((_) => _startPolling());
  }

  /// Load previously handled request IDs from persistent storage
  Future<void> _loadHandledIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_kHandledKey) ?? [];
      _handledRequestIds.addAll(stored);
      debugPrint('📋 Loaded ${stored.length} handled request IDs');
    } catch (e) {
      debugPrint('⚠️ Could not load handled IDs: $e');
    }
  }

  /// Persist a handled request ID so it survives app restarts
  Future<void> _markHandled(String requestId) async {
    if (requestId.isEmpty) return;
    _handledRequestIds.add(requestId);
    try {
      final prefs = await SharedPreferences.getInstance();
      // Keep only last 50 IDs to avoid unbounded growth
      final list = _handledRequestIds.toList();
      if (list.length > 50) list.removeRange(0, list.length - 50);
      await prefs.setStringList(_kHandledKey, list);
      debugPrint('✅ Marked request $requestId as handled (persisted)');
    } catch (e) {
      debugPrint('⚠️ Could not persist handled ID: $e');
    }
  }

  void _startPolling() {
    // Poll every 1.5 seconds so doctor gets request faster
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) => _checkPending());
    // Also fire once immediately on start
    Future.delayed(const Duration(milliseconds: 500), _checkPending);
  }

  Future<void> _checkPending() async {
    if (_dialogShowing || !mounted) return;

    final userRole = await _sharedPref.getUserRole();
    if (userRole == null) return;
    if (userRole.toLowerCase() != 'doctor') return;

    final token = await _sharedPref.getToken();
    if (token == null || token.isEmpty) return;

    // Check if doctor has toggled "Available for Instant Consultation"
    // Default = true so doctor receives requests as soon as they're online
    try {
      final prefs = await SharedPreferences.getInstance();
      final isAvailable = prefs.getBool('doctor_instant_consult_available') ?? true;
      if (!isAvailable) {
        debugPrint('⏸️ Doctor not available for instant consultation — skipping poll');
        return;
      }
      // Check if doctor is currently in a consultation
      final isInConsultation = prefs.getBool('doctor_in_consultation') ?? false;
      if (isInConsultation) {
        debugPrint('🔒 Doctor is in active consultation — skipping instant consult requests');
        return;
      }
    } catch (_) {}

    debugPrint('🩺 Checking for Connect Now requests...');

    try {
      final result = await _service.checkPending();
      if (result['hasPending'] == true && mounted) {
        final request = result['request'] as Map<String, dynamic>;
        final requestId = request['id']?.toString() ?? '';

        // Skip if already handled (persisted across restarts)
        if (requestId.isNotEmpty && _handledRequestIds.contains(requestId)) {
          debugPrint('⏭️ Skipping already-handled request: $requestId');
          return;
        }

        debugPrint('🚨 Pending request found: ${request['patientName']}');
        _dialogShowing = true;
        try {
          await _showRequestDialog(request);
        } finally {
          _dialogShowing = false;
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking pending requests: $e');
      _dialogShowing = false;
    }
  }

  Future<void> _showRequestDialog(Map<String, dynamic> request) async {
    final requestId = request['id']?.toString() ?? '';
    final patientId = request['patientId']?.toString() ?? '';
    final patientName = request['patientName']?.toString() ?? 'Patient';
    final channelName = request['channelName']?.toString() ?? '';

    final nav = appNavigatorKey.currentState;
    if (nav == null) {
      debugPrint('⚠️ Navigator not ready, skipping dialog');
      return;
    }

    await nav.push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        barrierDismissible: false,
        pageBuilder: (ctx, _, _) => _ConnectNowRequestDialog(
          patientName: patientName,
          onAccept: () async {
            // Mark as handled immediately — persisted so survives app restart
            await _markHandled(requestId);
            // Mark doctor as in consultation — blocks further instant consult requests
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('doctor_in_consultation', true);
            } catch (_) {}
            bool loadingShowing = false;
            try {
              final result = await _service.acceptRequest(requestId);
              final callChannel = result['channelName']?.toString() ?? channelName;
              final callPatient = result['patientName']?.toString() ?? patientName;
              final appointmentId = result['appointmentId']?.toString() ?? '';

              // Get doctor's own name and ID
              final userData = await _sharedPref.getUserData();
              final doctorName = userData?.name ?? 'Doctor';
              final doctorId = userData?.id ?? '';

              if (doctorId.isEmpty) {
                debugPrint('❌ Accept: doctorId is empty, cannot start consultation');
                if (nav.canPop()) nav.pop();
                ScaffoldMessenger.of(nav.context).showSnackBar(
                  const SnackBar(content: Text('Session expired — please log in again'), backgroundColor: Colors.red),
                );
                return;
              }

              // Close request dialog
              if (nav.canPop()) nav.pop();

              // Show loading spinner
              loadingShowing = true;
              showDialog(
                context: nav.context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator()),
              );

              final consultationService = ConsultationService();
              final consultResult = await consultationService.startConsultationV2(
                appointmentId: appointmentId,
                patientId: patientId,
                doctorId: doctorId,
                channelName: callChannel,
              );

              // Close loading spinner
              if (nav.canPop()) nav.pop();
              loadingShowing = false;

              if (consultResult['success'] == true) {
                final appointment = AppointmentDetail(
                  id: appointmentId.isNotEmpty ? appointmentId : '',
                  patient: User(id: patientId, name: callPatient, email: '', phoneNumber: '', role: 'patient'),
                  doctor: User(id: doctorId, name: doctorName, email: '', phoneNumber: '', role: 'doctor'),
                  status: 'confirmed',
                  timeSlot: 'Now',
                  date: DateTime.now(),
                  channelName: callChannel,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                nav.push(
                  MaterialPageRoute(
                    builder: (_) => _ConsultationWrapper(
                      child: ConsultationChatScreenV2(
                        consultationId: consultResult['consultationId']?.toString(),
                        appointment: appointment,
                        isDoctor: true,
                        currentUserId: doctorId,
                        currentUserName: doctorName,
                      ),
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(nav.context).showSnackBar(
                  SnackBar(
                    content: Text(consultResult['message']?.toString() ?? 'Failed to start consultation'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            } catch (e) {
              debugPrint('❌ Accept failed: $e');
              // Close any open dialog safely
              if (loadingShowing && nav.canPop()) nav.pop();
              if (!loadingShowing && nav.canPop()) nav.pop();
              ScaffoldMessenger.of(nav.context).showSnackBar(
                SnackBar(
                  content: Text('Failed to accept: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          onDecline: () async {
            // Mark as handled — persisted so survives app restart
            await _markHandled(requestId);
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

class _ConnectNowRequestDialog extends StatelessWidget {
  final String patientName;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _ConnectNowRequestDialog({
    required this.patientName,
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
            colors: [Color(0xFF1B4332), Color(0xFF0A1628)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.medical_services_rounded, color: Colors.green, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'Instant Consultation Request',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$patientName needs a doctor right now',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: onDecline,
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: Color(0xFF374151),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 8),
                      const Text('Decline', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
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
                        child: const Icon(Icons.video_call_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 8),
                      const Text('Accept', style: TextStyle(color: Colors.white70, fontSize: 12)),
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

/// Wraps VideoCall and clears doctor_in_consultation flag when call ends
class _ConsultationWrapper extends StatefulWidget {
  final Widget child;
  const _ConsultationWrapper({required this.child});

  @override
  State<_ConsultationWrapper> createState() => _ConsultationWrapperState();
}

class _ConsultationWrapperState extends State<_ConsultationWrapper> {
  @override
  void dispose() {
    // Clear in-consultation flag when video call screen is disposed
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('doctor_in_consultation', false);
      debugPrint('✅ Cleared doctor_in_consultation flag');
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
