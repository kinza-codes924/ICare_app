import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/call_service.dart';
import '../services/api_service.dart';
import '../screens/lms_live_session_screen.dart';
import '../utils/shared_pref.dart';
import '../utils/app_keys.dart';
import '../screens/video_call.dart';
import '../screens/consultation_chat_screen_v2.dart';

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
  Timer? _lmsTimer;
  bool _dialogShowing = false;
  bool _lmsDialogShowing = false;
  String? _lastLiveCourseId;
  final Set<String> _shownSessions = {}; // never re-show for same courseId

  @override
  void initState() {
    super.initState();
    _startPolling();
    _startLmsPolling();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _checkIncoming());
  }

  void _startLmsPolling() {
    _checkLmsLive(); // run once immediately
    _lmsTimer = Timer.periodic(const Duration(seconds: 20), (_) => _checkLmsLive());
  }

  Future<void> _checkLmsLive() async {
    if (_lmsDialogShowing || !mounted) return;
    final token = await _sharedPref.getToken();
    if (token == null || token.isEmpty) return;
    final user = await _sharedPref.getUserData();
    if (user?.role.toLowerCase() != 'student') return;

    try {
      final api = ApiService();
      // Correct endpoint: /students/courses/enrollments/my
      final resp = await api.get('/students/courses/enrollments/my');
      final enrollments = (resp.data['items'] ?? resp.data['enrollments'] ?? []) as List;
      debugPrint('🎓 LMS live check: ${enrollments.length} enrollments');

      for (final e in enrollments) {
        final course = (e['course'] is Map ? e['course'] : e['courseId']) as Map?;
        if (course == null) continue;
        final courseId = course['_id']?.toString() ?? '';
        final courseTitle = course['title']?.toString() ?? 'Live Session';
        if (courseId.isEmpty) continue;

        final liveResp = await api.get('/live-sessions/course/$courseId/active');
        final isLive = liveResp.data['isLive'] == true;
        debugPrint('🔴 Course $courseTitle isLive=$isLive');

        if (isLive && mounted) {
          _lastLiveCourseId = courseId;
          // Don't show if: already in session, already shown, dialog open
          if (LmsLiveSessionScreen.activeCourseId == courseId) return;
          if (_shownSessions.contains(courseId)) return;
          if (_lmsDialogShowing) return;
          _shownSessions.add(courseId);
          _showLiveSessionAlert(courseId, courseTitle);
          return;
        }
        if (!isLive && _lastLiveCourseId == courseId) {
          _lastLiveCourseId = null;
          _lmsDialogShowing = false;
          _shownSessions.remove(courseId); // Allow next session to show popup
        }
      }
    } catch (e) {
      debugPrint('LMS live check error: $e');
    }
  }

  void _showLiveSessionAlert(String courseId, String courseTitle) {
    if (_lmsDialogShowing) return;
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;
    _lmsDialogShowing = true;
    nav.push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black54,
      barrierDismissible: false,
      pageBuilder: (ctx, _, _) => _LmsLiveDialog(
        courseId: courseId,
        courseTitle: courseTitle,
        onDismiss: () { _lmsDialogShowing = false; },
      ),
      transitionsBuilder: (ctx, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
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
            await _callService.respondToCall(signalId, 'accepted');
            final userData = await _sharedPref.getUserData();
            nav.pop();

            if (callType == 'consultation') {
              // Appointment-based consultation: enter chat screen (chat-first)
              // channelName holds the consultationId; callerName is "Dr. [Name]"
              nav.push(
                MaterialPageRoute(
                  builder: (_) => ConsultationChatScreenV2(
                    appointment: null,
                    isDoctor: false,
                    currentUserId: userData?.id ?? '',
                    currentUserName: userData?.name ?? 'User',
                    consultationId: channelName,
                    remoteUserName: callerName, // e.g. "Dr. Ahmed"
                  ),
                ),
              );
            } else {
              // Direct video/audio call
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
          },
          onDecline: () async {
            await _callService.respondToCall(signalId, 'rejected');
            nav.pop();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lmsTimer?.cancel();
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

// ─── LMS Live Session Alert Dialog ─────────────────────────────────────────

class _LmsLiveDialog extends StatelessWidget {
  final String courseId;
  final String courseTitle;
  final VoidCallback onDismiss;

  const _LmsLiveDialog({
    required this.courseId,
    required this.courseTitle,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async { onDismiss(); return true; },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF1C2333),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red, width: 2),
              boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.4), blurRadius: 20)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.live_tv_rounded, color: Colors.red, size: 64),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.circle, color: Colors.white, size: 10),
                    SizedBox(width: 6),
                    Text('LIVE NOW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                  ]),
                ),
                const SizedBox(height: 16),
                const Text('Your Instructor is LIVE!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(courseTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 15)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () { onDismiss(); Navigator.pop(context); },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white54,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Later'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          onDismiss();
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => LmsLiveSessionScreen(
                              sessionId: courseId,
                              courseId: courseId,
                              sessionTitle: courseTitle,
                              isInstructor: false,
                            ),
                          ));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 22),
                        label: const Text('JOIN NOW', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
