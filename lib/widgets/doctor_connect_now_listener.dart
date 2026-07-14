import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/connect_now_service.dart';
import '../services/consultation_service.dart';
import '../services/appointment_service.dart';
import '../utils/shared_pref.dart';
import '../utils/app_keys.dart';
import '../utils/connect_now_events.dart';
import '../models/appointment_detail.dart';
import '../models/user.dart';

/// Starts (or resumes, idempotently) the Consultation and pushes the
/// doctor into the live chat. Shared by the immediate-fallback path (no
/// Appointment record to gate on) and by [_WaitingForPaymentScreen] once
/// payment is confirmed.
Future<void> _enterConsultation(
  BuildContext context, {
  required String appointmentId,
  required String patientId,
  required String patientName,
  required String doctorId,
  required String doctorName,
  required String channelName,
}) async {
  final consultResult = await ConsultationService().startConsultationV2(
    appointmentId: appointmentId,
    patientId: patientId,
    doctorId: doctorId,
    channelName: channelName,
  );

  if (!context.mounted) return;

  if (consultResult['success'] == true) {
    final appointment = AppointmentDetail(
      id: appointmentId,
      patient: User(id: patientId, name: patientName, email: '', phoneNumber: '', role: 'patient'),
      doctor: User(id: doctorId, name: doctorName, email: '', phoneNumber: '', role: 'doctor'),
      status: 'confirmed',
      timeSlot: 'Now',
      date: DateTime.now(),
      channelName: channelName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final consultationId = consultResult['consultationId']?.toString() ?? appointmentId;
    context.go(
      '/consultation/$consultationId',
      extra: {
        'appointment': appointment,
        'isDoctor': true,
        'currentUserId': doctorId,
        'currentUserName': doctorName,
      },
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(consultResult['message']?.toString() ?? 'Failed to start consultation'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

/// Shown to the doctor right after accepting — the consultation (and its
/// timer) must NOT start until the patient's payment is confirmed, so this
/// polls the appointment's paymentStatus instead of jumping straight into
/// the chat screen.
class _WaitingForPaymentScreen extends StatefulWidget {
  final String appointmentId;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final String channelName;

  const _WaitingForPaymentScreen({
    required this.appointmentId,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.channelName,
  });

  @override
  State<_WaitingForPaymentScreen> createState() => _WaitingForPaymentScreenState();
}

class _WaitingForPaymentScreenState extends State<_WaitingForPaymentScreen> {
  final AppointmentService _appointmentService = AppointmentService();
  Timer? _pollTimer;
  bool _timedOut = false;
  bool _entering = false;
  final _deadline = DateTime.now().add(const Duration(minutes: 5));

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkPaymentStatus());
  }

  Future<void> _checkPaymentStatus() async {
    if (!mounted || _entering) return;
    if (DateTime.now().isAfter(_deadline)) {
      _pollTimer?.cancel();
      if (mounted) setState(() => _timedOut = true);
      return;
    }
    final appt = await _appointmentService.getAppointmentById(widget.appointmentId);
    if (!mounted || _entering) return;
    if (appt?['paymentStatus'] == 'paid') {
      _entering = true;
      _pollTimer?.cancel();
      await _enterConsultation(
        context,
        appointmentId: widget.appointmentId,
        patientId: widget.patientId,
        patientName: widget.patientName,
        doctorId: widget.doctorId,
        doctorName: widget.doctorName,
        channelName: widget.channelName,
      );
    }
  }

  void _goBack() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('doctor_in_consultation', false);
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1628),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_timedOut) ...[
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 28),
                    const Text(
                      'Waiting for patient to complete payment',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${widget.patientName} is completing payment for this consultation. '
                      'The chat will open automatically once payment is confirmed.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                    ),
                  ] else ...[
                    const Icon(Icons.hourglass_disabled_rounded, color: Colors.orange, size: 56),
                    const SizedBox(height: 20),
                    const Text(
                      'Patient has not completed payment',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'You can go back and continue accepting other requests.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                    ),
                  ],
                  const SizedBox(height: 32),
                  OutlinedButton(
                    onPressed: _goBack,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Go Back', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
  StreamSubscription<Map<String, dynamic>>? _fcmSub;
  bool _dialogShowing = false;
  bool _isChecking = false; // prevents concurrent in-flight calls

  // Cached role/token — avoids SharedPreferences hit every tick
  String? _cachedRole;
  String? _cachedToken;

  // In-memory cache (fast lookup)
  final Set<String> _handledRequestIds = {};

  // SharedPreferences key for persisting handled IDs across app restarts
  static const String _kHandledKey = 'connect_now_handled_ids';

  @override
  void initState() {
    super.initState();
    _loadHandledIds().then((_) {
      // Clear stuck in-consultation flag on fresh app start
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool('doctor_in_consultation', false);
      }).catchError((_) {});
      _startPolling();
      _subscribeToFcmEvents();
    });
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

  /// Subscribe to FCM-triggered events — fires _checkPending() immediately
  /// when Firebase push notification arrives (no polling delay).
  void _subscribeToFcmEvents() {
    _fcmSub = ConnectNowEvents.onRequest.listen((data) {
      debugPrint('🚨 [ConnectNow] FCM event received → immediate poll');
      _checkPending();
    });
  }

  void _startPolling() {
    // 3-second fallback poll. FCM handles the instant case; this is the
    // safety net for when FCM is delayed or app is backgrounded.
    // _isChecking guard prevents concurrent in-flight calls.
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _checkPending());
    // Fire once immediately on start (500ms delay to let initState settle)
    Future.delayed(const Duration(milliseconds: 500), _checkPending);
  }

  Future<void> _checkPending() async {
    // Hard guard: skip if a previous call is still in-flight or dialog is open
    if (_isChecking || _dialogShowing || !mounted) return;
    _isChecking = true;
    try {
      await _doCheckPending();
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _doCheckPending() async {
    if (!mounted) return;

    // Use cached role/token to avoid SharedPreferences round-trip every tick
    _cachedRole ??= await _sharedPref.getUserRole();
    if (_cachedRole == null || _cachedRole!.toLowerCase() != 'doctor') return;

    _cachedToken ??= await _sharedPref.getToken();
    if (_cachedToken == null || _cachedToken!.isEmpty) return;

    // Check prefs flags (availability + in-consultation)
    try {
      final prefs = await SharedPreferences.getInstance();
      final isAvailable = prefs.getBool('doctor_instant_consult_available') ?? true;
      if (!isAvailable) return;
      final isInConsultation = prefs.getBool('doctor_in_consultation') ?? false;
      if (isInConsultation) return;
    } catch (_) {}

    if (!mounted) return;

    try {
      final result = await _service.checkPending();
      if (result['hasPending'] == true && mounted) {
        final request = result['request'] as Map<String, dynamic>;
        final requestId = request['id']?.toString() ?? '';

        // Skip if already handled (persisted across restarts)
        if (requestId.isNotEmpty && _handledRequestIds.contains(requestId)) return;

        _dialogShowing = true;
        try {
          await _showRequestDialog(request);
        } finally {
          _dialogShowing = false;
        }
      }
    } catch (e) {
      debugPrint('❌ ConnectNow poll error: $e');
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

              if (appointmentId.isEmpty) {
                // Rare fallback: no Appointment record was created, so there's
                // nothing to gate payment on — preserve the old immediate behavior.
                await _enterConsultation(
                  nav.context,
                  appointmentId: '',
                  patientId: patientId,
                  patientName: callPatient,
                  doctorId: doctorId,
                  doctorName: doctorName,
                  channelName: callChannel,
                );
                return;
              }

              // Neither side's consultation/timer should start until the
              // patient's payment is confirmed — show a waiting screen that
              // polls the appointment's paymentStatus instead.
              nav.push(
                MaterialPageRoute(
                  builder: (_) => _WaitingForPaymentScreen(
                    appointmentId: appointmentId,
                    patientId: patientId,
                    patientName: callPatient,
                    doctorId: doctorId,
                    doctorName: doctorName,
                    channelName: callChannel,
                  ),
                ),
              );
            } catch (e) {
              debugPrint('❌ Accept failed: $e');
              if (nav.canPop()) nav.pop();
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
    _fcmSub?.cancel();
    _cachedRole = null;
    _cachedToken = null;
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
