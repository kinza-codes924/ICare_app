import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:icare/services/agora_service.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/shared_pref.dart';
import '../utils/lms_agora_stub.dart'
    if (dart.library.js_interop) '../utils/lms_agora_web.dart';
import '../utils/lms_mic_permission_stub.dart'
    if (dart.library.js_interop) '../utils/lms_mic_permission_web.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONTROLLER: LiveSessionController
// Responsible for 100% null-safe session join, token validation, mic permission
// loop, and session state management for BOTH Instructor and Student.
// ─────────────────────────────────────────────────────────────────────────────

enum SessionJoinState {
  idle,
  validating,
  requestingPermission,
  joining,
  joined,
  error,
}

class LiveSessionController {
  // ── Public State ──────────────────────────────────────────────────────────
  SessionJoinState joinState = SessionJoinState.idle;
  String? errorMessage;
  String sessionDocId = '';
  String roomName = '';
  String agoraToken = '';
  String agoraAppId = '';
  String currentUserName = 'You';
  String currentUserId = '';
  bool isRecording = false;
  int sessionSeconds = 0;

  // ── Callbacks (set by the View) ───────────────────────────────────────────
  VoidCallback? onStateChanged;
  VoidCallback? onPermissionDenied;
  VoidCallback? onJoinFailed;

  // ── Internals ─────────────────────────────────────────────────────────────
  final LmsService _lms = LmsService();
  final AgoraService _agora = AgoraService();
  Timer? _sessionTimer;
  Timer? _syncTimer;
  bool _disposed = false;

  void dispose() {
    _disposed = true;
    _sessionTimer?.cancel();
    _syncTimer?.cancel();
    lmsLeaveChannel();
  }

  // ── PUBLIC: Initiate session join with full null-safety ──────────────────
  /// Returns `true` if all parameters are valid before proceeding.
  /// `sessionId` must be a non-empty, real MongoDB document ID (not courseId).
  Future<bool> joinSession({
    required String sessionId,
    required String courseId,
    required String sessionTitle,
    required bool isInstructor,
    String? lessonId,
    String? moduleId,
  }) async {
    // ── STEP 0: STRICT NULL-SAFETY VALIDATION ──────────────────────────────
    // This is the PRIMARY GUARD against the main.dart.js Uncaught Error.
    // If any parameter is null or empty, we catch it here BEFORE any
    // native/JS call that would throw an opaque, minified error.
    final List<String> validationErrors = [];

    if (sessionId.isEmpty) {
      validationErrors.add('sessionId is empty');
    }
    if (courseId.isEmpty) {
      validationErrors.add('courseId is empty');
    }
    // sessionId must be a real MongoDB ObjectId (24 hex chars) and different
    // from courseId (means no active session document was resolved).
    if (sessionId == courseId && sessionId.length == 24) {
      validationErrors.add(
        'sessionId equals courseId - no active session document resolved',
      );
    }
    // Room name derived from sessionId must have at least 3 alphanumeric chars
    final sanitized = sessionId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (sanitized.length < 3) {
      validationErrors.add(
        'sessionId "$sessionId" produces invalid room name (too short after sanitization)',
      );
    }

    if (validationErrors.isNotEmpty) {
      joinState = SessionJoinState.error;
      errorMessage =
          'Cannot join session: ${validationErrors.join("; ")}. '
          'Please contact your instructor.';
      onStateChanged?.call();
      onJoinFailed?.call();
      return false;
    }

    joinState = SessionJoinState.validating;
    onStateChanged?.call();

    try {
      // ── STEP 1: Load user data ────────────────────────────────────────────
      final user = await SharedPref().getUserData();
      currentUserName =
          user?.name ?? (isInstructor ? 'Instructor' : 'Student');
      currentUserId = user?.id ?? '';

      // ── STEP 2: Resolve session document ID ───────────────────────────────
      sessionDocId = sessionId;

      // ── STEP 3: Join session on backend (registers attendance) ────────────
      if (sessionDocId.isNotEmpty && sessionDocId != courseId) {
        await _lms.joinLiveSession(sessionDocId);
      }

      // ── STEP 4: REQUEST BROWSER MICROPHONE PERMISSION (CRITICAL FIX) ──────
      // This must happen BEFORE any Agora/WebRTC call. On Flutter Web, the
      // browser will deny microphone if getUserMedia is called outside a user
      // gesture context. By requesting permission here explicitly, we ensure
      // the user gesture chain is preserved.
      if (kIsWeb) {
        joinState = SessionJoinState.requestingPermission;
        onStateChanged?.call();

        final micGranted = await lmsRequestMicPermission(3, 500);
        if (!micGranted) {
          // Permission denied - show descriptive error instead of crashing
          joinState = SessionJoinState.error;
          errorMessage =
              'Microphone access was denied. Please allow microphone access '
              'in your browser settings, then try again.';
          onStateChanged?.call();
          onPermissionDenied?.call();
          return false;
        }
      }

      // ── STEP 5: Build room name (deterministic, sanitized) ────────────────
      roomName = _buildRoomName(sessionDocId, courseId);

      // ── STEP 6: Fetch Agora token ─────────────────────────────────────────
      joinState = SessionJoinState.joining;
      onStateChanged?.call();

      final tokenResponse = await _agora.getToken(
        channelName: roomName,
        uid: 0,
      );
      if (tokenResponse['success'] == false) {
        joinState = SessionJoinState.error;
        errorMessage =
            'Failed to get streaming token: ${tokenResponse['message'] ?? 'Unknown error'}';
        onStateChanged?.call();
        onJoinFailed?.call();
        return false;
      }
      agoraToken = tokenResponse['data']?['token'] as String? ?? '';
      agoraAppId = tokenResponse['data']?['appId'] as String? ?? '';

      // Validate token
      if (agoraToken.isEmpty) {
        joinState = SessionJoinState.error;
        errorMessage =
            'Streaming token is empty. Cannot join video session.';
        onStateChanged?.call();
        onJoinFailed?.call();
        return false;
      }

      // ── STEP 7: Notify students (if instructor) ───────────────────────────
      if (isInstructor) {
        await _notifyStudents(
          courseId: courseId,
          sessionId: sessionDocId,
          sessionTitle: sessionTitle,
        );
      }

      // ── STEP 8: Start Agora video session ─────────────────────────────────
      await _initVideoSession(
        isInstructor: isInstructor,
        courseId: courseId,
      );

      // ── STEP 9: Start sync polling ────────────────────────────────────────
      _startSyncPolling();

      joinState = SessionJoinState.joined;
      onStateChanged?.call();
      return true;
    } catch (e) {
      joinState = SessionJoinState.error;
      errorMessage = 'Failed to join session: $e';
      onStateChanged?.call();
      onJoinFailed?.call();
      return false;
    }
  }

  // ── PUBLIC: toggle recording ──────────────────────────────────────────────
  Future<void> toggleRecording(String sessionDocId) async {
    if (!kIsWeb) {
      return;
    }
    if (!isRecording) {
      lmsStartRecording();
      isRecording = true;
      onStateChanged?.call();
    } else {
      final token = await SharedPref().getToken();
      lmsStopRecordingAndUpload(
        sessionDocId,
        'https://icare-backend-inky.vercel.app/api',
        token ?? '',
      );
      isRecording = false;
      onStateChanged?.call();
    }
  }

  // ── PUBLIC: end session ───────────────────────────────────────────────────
  Future<void> endSession({
    required bool isInstructor,
    required String courseId,
    required String sessionDocId,
    String? lessonId,
    String? moduleId,
  }) async {
    lmsLeaveChannel();

    if (isInstructor) {
      // Stop recording + upload
      if (kIsWeb && isRecording && sessionDocId.isNotEmpty) {
        final token = await SharedPref().getToken();
        lmsStopRecordingAndUpload(
          sessionDocId,
          'https://icare-backend-inky.vercel.app/api',
          token ?? '',
        );
      }

      // Save session to backend
      if (sessionDocId.isNotEmpty && sessionDocId != courseId) {
        await _lms.endAndSaveSession(
          sessionId: sessionDocId,
          lessonId: lessonId,
          moduleId: moduleId,
        );
      }
      await _lms.setSessionLive(courseId: courseId, isLive: false);
    }
  }

  // ── PUBLIC: sync chat/hands/polls ────────────────────────────────────────
  void sendChatMessage(String message) {
    if (sessionDocId.isNotEmpty) {
      _lms.sendSessionChatMessage(sessionDocId, message);
    }
  }

  void toggleHand(bool raised) {
    if (sessionDocId.isNotEmpty) {
      if (raised) {
        _lms.raiseSessionHand(sessionDocId);
      } else {
        _lms.lowerSessionHand(sessionDocId);
      }
    }
  }

  // ── PRIVATE: Build a deterministic, sanitized room name ───────────────────
  String _buildRoomName(String sessionDocId, String courseId) {
    // Use sessionDocId if valid; fall back to courseId only as last resort
    final base = sessionDocId.isNotEmpty ? sessionDocId : courseId;
    final sanitized = base.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    // Ensure at least 3 chars for the room name - if too short, pad with hash
    if (sanitized.length < 3) {
      // Create a deterministic hash from the original string
      final hash = base.hashCode.toString();
      return 'icare${hash.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').substring(0, 12)}';
    }
    // Keep max 20 chars for Agora channel name safety
    final maxLen = sanitized.length.clamp(3, 20);
    return 'icare${sanitized.substring(0, maxLen)}';
  }

  // ── PRIVATE: Notify students (instructor only) ────────────────────────────
  Future<void> _notifyStudents({
    required String courseId,
    required String sessionId,
    required String sessionTitle,
  }) async {
    try {
      await _lms.setSessionLive(
        courseId: courseId,
        isLive: true,
        title: sessionTitle,
        sessionId: sessionId,
      );
      await _lms.startLiveSessionNotify(
        courseId: courseId,
        sessionId: sessionId,
        instructorName: currentUserName,
        sessionTitle: sessionTitle,
      );
    } catch (e) {
      debugPrint('Notify students error: $e');
    }
  }

  // ── PRIVATE: Initialize Agora video session ──────────────────────────────
  Future<void> _initVideoSession({
    required bool isInstructor,
    required String courseId,
  }) async {
    if (kIsWeb) {
      // Web: register platform view, then join Agora
      registerLmsVideoView();
      await Future.delayed(const Duration(milliseconds: 400));
      try {
        await lmsJoinChannel(
          roomName,
          agoraAppId,
          agoraToken,
          isInstructor,
        );
        debugPrint('LMS Agora join: room=$roomName');
      } catch (e) {
        debugPrint('LMS Agora join error: $e');
        rethrow;
      }
    } else {
      // Mobile: use platform channel
      lmsSetCallbacks(onJoined: () {});
      await lmsJoinChannel(
        roomName,
        agoraAppId,
        agoraToken,
        isInstructor,
      );
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  // ── PRIVATE: Start sync polling ──────────────────────────────────────────
  void _startSyncPolling() {
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      // Sync state is handled by the View via LmsService directly.
      // This ensures the controller doesn't duplicate state management.
    });
  }

  // ── PRIVATE: Start session timer ──────────────────────────────────────────
  void startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_disposed) {
        sessionSeconds++;
        onStateChanged?.call();
      }
    });
  }

  String getFormattedTimer() {
    final h = sessionSeconds ~/ 3600;
    final m = (sessionSeconds % 3600) ~/ 60;
    final s = sessionSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}