import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:icare/services/agora_service.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/utils/theme.dart';
import '../utils/lms_agora_stub.dart'
    if (dart.library.js_interop) '../utils/lms_agora_web.dart';

/// LMS Live Session Screen — Google Meet style, Jitsi Meet + MediaRecorder
/// Completely separate from doctor-patient consultation
class LmsLiveSessionScreen extends StatefulWidget {
  final String sessionId;
  final String courseId;
  final String sessionTitle;
  final bool isInstructor;
  final String? lessonId;   // linked lesson for auto-save
  final String? moduleId;

  // Global flag — popup should not show when student is already in a session
  static String? activeCourseId;

  const LmsLiveSessionScreen({
    super.key,
    required this.sessionId,
    required this.courseId,
    required this.sessionTitle,
    this.isInstructor = false,
    this.lessonId,
    this.moduleId,
  });

  @override
  State<LmsLiveSessionScreen> createState() => _LmsLiveSessionScreenState();
}

class _LmsLiveSessionScreenState extends State<LmsLiveSessionScreen>
    with SingleTickerProviderStateMixin {
  bool _joined = false;
  bool _micOn = true;
  bool _cameraOn = true;

  bool _loading = true;
  String? _error;
  final List<int> _remoteUids = [];

  // UI State
  bool _chatOpen = false;
  bool _participantsOpen = false;
  bool _handRaised = false;
  bool _isRecording = false;
  late TabController _panelTab;

  // Chat — synced with backend
  final TextEditingController _chatCtrl = TextEditingController();
  final ScrollController _chatScroll = ScrollController();
  final List<Map<String, dynamic>> _chatMessages = [];

  // Polls
  final List<Map<String, dynamic>> _polls = [];
  final Map<String, int> _votedPolls = {}; // pollId → optionIndex the student chose

  // Participants + raised hands — synced with backend
  final List<Map<String, dynamic>> _participants = [];
  final List<String> _raisedHands = [];

  // Session info
  String _currentUserName = 'You';
  String _currentUserId = '';
  String _sessionDocId = ''; // actual MongoDB _id of the LiveSession document
  Timer? _sessionTimer;
  Timer? _syncTimer; // polls backend for chat/participants/raised hands
  int _sessionSeconds = 0;

  final LmsService _lms = LmsService();

  @override
  void initState() {
    super.initState();
    _panelTab = TabController(length: 3, vsync: this);
    LmsLiveSessionScreen.activeCourseId = widget.courseId; // stop popup
    _initSession();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _syncTimer?.cancel();
    _chatCtrl.dispose();
    _chatScroll.dispose();
    _panelTab.dispose();
    LmsLiveSessionScreen.activeCourseId = null; // allow popup again after leaving
    lmsLeaveChannel();
    super.dispose();
  }

  Future<void> _initSession() async {
    try {
      final user = await SharedPref().getUserData();
      _currentUserName = user?.name ?? (widget.isInstructor ? 'Instructor' : 'Student');
      _currentUserId = user?.id ?? '';

      // Step 1: Get the actual MongoDB _id of the live session
      final sessionData = await _lms.checkActiveLiveSession(widget.courseId);
      if (sessionData['session'] != null) {
        _sessionDocId = sessionData['session']['_id']?.toString() ?? '';
      }

      // Fallback: scan course sessions list for an active/live one
      if (_sessionDocId.isEmpty || _sessionDocId == widget.courseId) {
        try {
          final sessions = await _lms.getCourseSessions(widget.courseId);
          if (sessions.isNotEmpty) {
            final live = sessions.where((s) =>
                s['isLive'] == true || s['status'] == 'live' || s['status'] == 'active').toList();
            if (live.isNotEmpty) {
              _sessionDocId = live.first['_id']?.toString() ?? '';
            } else {
              // Use most recent session as last resort
              _sessionDocId = sessions.last['_id']?.toString() ?? '';
            }
          }
        } catch (_) {}
      }

      // Final fallback: use widget.sessionId if it looks like a real ID (not equal to courseId)
      if (_sessionDocId.isEmpty) {
        _sessionDocId = widget.sessionId.isNotEmpty ? widget.sessionId : widget.courseId;
      }

      // Step 2: Join the session (registers attendance)
      if (_sessionDocId.isNotEmpty && _sessionDocId != widget.courseId) {
        await _lms.joinLiveSession(_sessionDocId);
      }

      // Step 3: Start web camera
      if (kIsWeb) await _initWebCamera();

      // Step 4: Notify students if instructor
      if (widget.isInstructor) await _notifyStudents();

      // Step 5: Start polling for real-time sync
      _startSyncPolling();

      await _initVideoSession();
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _toggleRecording() async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording is only available on web'), duration: Duration(seconds: 2)),
      );
      return;
    }
    if (!_isRecording) {
      lmsStartRecording();
      if (mounted) setState(() => _isRecording = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording started'), backgroundColor: Colors.red, duration: Duration(seconds: 2)),
      );
    } else {
      final token = await SharedPref().getToken();
      lmsStopRecordingAndUpload(
        _sessionDocId,
        'https://icare-backend-inky.vercel.app/api',
        token ?? '',
      );
      if (mounted) setState(() => _isRecording = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording stopped — uploading to LMS...'), backgroundColor: Colors.green, duration: Duration(seconds: 3)),
      );
    }
  }

  void _startSyncPolling() {
    // 2-second interval for near-realtime chat/polls/participants
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) => _syncSessionState());
  }

  Future<void> _syncSessionState() async {
    if (!mounted || _sessionDocId.isEmpty) return;
    try {
      final data = await _lms.getSessionState(_sessionDocId);
      final session = data['session'];
      if (session == null || !mounted) return;

      // Update participants from attendees
      final attendees = (session['attendees'] as List?) ?? [];
      final newParticipants = attendees.map<Map<String, dynamic>>((a) => {
        'name': a['name'] ?? a['username'] ?? 'Participant',
        'id': a['_id']?.toString() ?? '',
        'isInstructor': false,
      }).toList();

      // Waiting room students (instructor sees these)
      final waiting = (session['waitingStudents'] as List?) ?? [];
      final waitingNames = waiting.map((w) => w['name'] ?? w['username'] ?? 'Student').toList();

      // Update raised hands
      final raisedHandsData = (session['raisedHands'] as List?)
          ?? (session['handsRaised'] as List?)
          ?? [];
      final newHands = raisedHandsData
          .map<String>((h) => h is Map
              ? (h['userName'] ?? h['name'] ?? 'Student').toString()
              : h.toString())
          .toList();

      // Update chat messages — prefer dedicated endpoint for freshest data
      List<dynamic> rawMessages = (session['chatMessages'] as List?) ?? [];
      if (rawMessages.isEmpty) {
        try {
          final chatData = await _lms.getSessionChatMessages(_sessionDocId);
          rawMessages = chatData;
        } catch (_) {}
      }
      final newMessages = rawMessages.map<Map<String, dynamic>>((m) {
        final msg = m is Map ? m : <String, dynamic>{};
        return {
          'sender': msg['userName'] ?? msg['name'] ?? 'User',
          'text': msg['message'] ?? msg['text'] ?? '',
          'time': '',
          'isMe': msg['userId']?.toString() == _currentUserId,
        };
      }).toList();

      // Polls: always try dedicated endpoint first for accurate real-time data
      List<Map<String, dynamic>> newPolls = [];
      try {
        final pollsData = await _lms.getLiveSessionPolls(_sessionDocId);
        if (pollsData.isNotEmpty) {
          newPolls = pollsData.map<Map<String, dynamic>>((p) => Map<String, dynamic>.from(p is Map ? p : {})).toList();
        } else {
          // Fall back to embedded polls in session document
          final pollsFromSession = (session['polls'] as List?) ?? [];
          newPolls = pollsFromSession.map<Map<String, dynamic>>((p) => Map<String, dynamic>.from(p is Map ? p : {})).toList();
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _participants.clear();
          // Add self first
          _participants.add({'name': '$_currentUserName (You)', 'isInstructor': widget.isInstructor, 'id': _currentUserId});
          _participants.addAll(newParticipants.where((p) => p['id'] != _currentUserId));
          _raisedHands
            ..clear()
            ..addAll(newHands);
          _chatMessages.clear();
          _chatMessages.addAll(newMessages);
          _polls.clear();
          _polls.addAll(newPolls);
          // Show waiting room badge for instructor
          if (widget.isInstructor && waitingNames.isNotEmpty) {
            _waitingStudents = waitingNames.cast<String>();
          } else {
            _waitingStudents = [];
          }
        });

        // Notify instructor of new join request
        if (widget.isInstructor && waitingNames.length > (_waitingStudents.length)) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✋ ${waitingNames.last} wants to join'),
            backgroundColor: Colors.blue,
            action: SnackBarAction(
              label: 'Admit',
              textColor: Colors.white,
              onPressed: () => _admitStudent(waiting.last['_id']?.toString() ?? ''),
            ),
            duration: const Duration(seconds: 8),
          ));
        }

        // Scroll chat to bottom
        if (_chatMessages.isNotEmpty && _chatScroll.hasClients) {
          _chatScroll.animateTo(_chatScroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        }
      }
    } catch (_) {}
  }

  List<String> _waitingStudents = [];

  Future<void> _admitStudent(String studentId) async {
    if (studentId.isEmpty || _sessionDocId.isEmpty) return;
    try {
      final api = LmsService();
      await api.admitStudent(sessionId: _sessionDocId, studentId: studentId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student admitted!'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
      );
    } catch (_) {}
  }

  Future<void> _initWebCamera() async {
    if (!kIsWeb) return;
    try {
      // Register Jitsi host div as Flutter platform view
      final viewId = registerLmsVideoView();
      if (mounted) setState(() => _cameraViewName = viewId);

      final sessionRoom = _sessionDocId.isNotEmpty ? _sessionDocId : widget.sessionId;
      final roomName = 'icare${sessionRoom.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').substring(0, sessionRoom.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').length.clamp(0, 20))}';

      // Join after the platform view is in the DOM
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final tokenData = await AgoraService().getToken(channelName: roomName, uid: 0);
        final agoraToken = tokenData['data']?['token'] as String? ?? '';
        final agoraAppId = tokenData['data']?['appId'] as String? ?? '';
        Future.delayed(const Duration(milliseconds: 400), () {
          lmsJoinChannel(roomName, agoraAppId, agoraToken, widget.isInstructor);
          debugPrint('LMS Agora join: room=$roomName');
        });
      });

      // Auto-show recording indicator for instructor (recording starts in JS after 3s)
      if (widget.isInstructor) {
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() => _isRecording = true);
        });
      }
    } catch (e) {
      debugPrint('LMS Jitsi init error: $e');
    }
  }

  String? _cameraViewName;

  Future<void> _notifyStudents() async {
    try {
      // Mark session as LIVE in backend — students polling will pick this up
      await _lms.setSessionLive(
        courseId: widget.courseId,
        isLive: true,
        title: widget.sessionTitle,
      );
      // Also send push notifications
      await _lms.startLiveSessionNotify(
        courseId: widget.courseId,
        sessionId: widget.sessionId,
        instructorName: _currentUserName,
        sessionTitle: widget.sessionTitle,
      );
    } catch (e) {
      debugPrint('Notify students error: $e');
    }
  }

  Future<void> _initVideoSession() async {
    if (kIsWeb) {
      // Web: Jitsi loads via _initWebCamera which was called before this
      if (mounted) setState(() { _joined = true; _loading = false; });
      _startSessionTimer();
      return;
    }

    // Mobile: lmsJoinChannel (stub) opens Jitsi in external browser
    lmsSetCallbacks(
      onJoined: () {
        if (mounted && !_joined) {
          setState(() { _joined = true; _loading = false; });
          _startSessionTimer();
        }
      },
    );

    final sessionRoom = _sessionDocId.isNotEmpty ? _sessionDocId : widget.sessionId;
    final roomName = 'icare${sessionRoom.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').substring(0, sessionRoom.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').length.clamp(0, 20))}';
    final tokenData = await AgoraService().getToken(channelName: roomName, uid: 0);
    final agoraToken = tokenData['data']?['token'] as String? ?? '';
    final agoraAppId = tokenData['data']?['appId'] as String? ?? '';
    await lmsJoinChannel(roomName, agoraAppId, agoraToken, widget.isInstructor);

    // Fallback: mark joined after 2s
    await Future.delayed(const Duration(seconds: 2));
    if (mounted && !_joined) {
      setState(() { _joined = true; _loading = false; });
      _startSessionTimer();
    }
  }

  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _sessionSeconds++);
    });
  }

  String get _timerText {
    final h = _sessionSeconds ~/ 3600;
    final m = (_sessionSeconds % 3600) ~/ 60;
    final s = _sessionSeconds % 60;
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _toggleMic() {
    _micOn = !_micOn;
    lmsMuteMic(!_micOn);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_micOn ? 'Microphone on' : 'Microphone muted'),
      duration: const Duration(seconds: 1),
      backgroundColor: _micOn ? Colors.green : Colors.grey,
    ));
  }

  void _toggleCamera() {
    _cameraOn = !_cameraOn;
    lmsMuteCamera(!_cameraOn);
    setState(() {});
  }


  void _toggleHand() {
    setState(() => _handRaised = !_handRaised);
    // Send to backend so instructor can see it
    if (_sessionDocId.isNotEmpty) {
      if (_handRaised) {
        _lms.raiseSessionHand(_sessionDocId);
      } else {
        _lms.lowerSessionHand(_sessionDocId);
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_handRaised ? '✋ Hand raised — instructor can see this' : 'Hand lowered'),
        duration: const Duration(seconds: 2),
        backgroundColor: _handRaised ? Colors.orange : Colors.grey,
      ),
    );
  }

  void _sendChat() {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    _chatCtrl.clear();

    // Optimistic UI update
    setState(() {
      _chatMessages.add({'sender': _currentUserName, 'text': text, 'time': _timerText, 'isMe': true});
    });

    // Send to backend — synced to all participants via polling
    if (_sessionDocId.isNotEmpty) {
      _lms.sendSessionChatMessage(_sessionDocId, text);
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _endSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.isInstructor ? 'End Session for All?' : 'Leave Session?'),
        content: Text(widget.isInstructor
            ? 'This will end the session for all participants.'
            : 'Are you sure you want to leave?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(widget.isInstructor ? 'End for All' : 'Leave'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      lmsLeaveChannel();

      if (widget.isInstructor) {
        // Stop recording + save to device (auto-download) + upload if Cloudinary configured
        if (kIsWeb && _isRecording && _sessionDocId.isNotEmpty) {
          final token = await SharedPref().getToken();
          lmsStopRecordingAndUpload(
            _sessionDocId,
            'https://icare-backend-inky.vercel.app/api',
            token ?? '',
          );
        }

        // Auto-save: end session + save chat transcript to lesson
        if (_sessionDocId.isNotEmpty && _sessionDocId != widget.courseId) {
          final result = await _lms.endAndSaveSession(
            sessionId: _sessionDocId,
            lessonId: widget.lessonId,
            moduleId: widget.moduleId,
          );
          if (mounted && result['success'] == true) {
            final msg = widget.lessonId != null
                ? 'Session saved and linked to lesson.'
                : 'Session ended. Chat transcript saved.';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(children: [
                  const Icon(Icons.save_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(msg)),
                ]),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
        await _lms.setSessionLive(courseId: widget.courseId, isLive: false);
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFF1C2333),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                'Joining session...',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1C2333),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            // Dark background behind everything
            Container(color: const Color(0xFF1C2333)),
            Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: LayoutBuilder(
                    builder: (ctx, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      if (isMobile) {
                        // Mobile: side panel slides up as overlay (Stack), video stays full-width
                        return Stack(
                          children: [
                            _buildVideoArea(),
                            if (_chatOpen || _participantsOpen)
                              Positioned.fill(
                                child: Container(
                                  color: Colors.black54,
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                      height: constraints.maxHeight * 0.65,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF252D3D),
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                      ),
                                      child: Column(children: [
                                        const SizedBox(height: 6),
                                        Container(
                                          width: 40, height: 4,
                                          decoration: BoxDecoration(
                                            color: Colors.white38,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        Expanded(child: _buildSidePanel()),
                                      ]),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: _buildVideoArea()),
                          if (_chatOpen || _participantsOpen) _buildSidePanel(),
                        ],
                      );
                    },
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 52,
      color: const Color(0xFF252D3D),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Timer + Live indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('● LIVE', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Text(
            _timerText,
            style: const TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'monospace'),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              widget.sessionTitle,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Participant count
          Row(children: [
            const Icon(Icons.people_rounded, color: Colors.white54, size: 18),
            const SizedBox(width: 4),
            Text('${_participants.length}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ]),
          const SizedBox(width: 10),
          // Recording button (instructor only)
          if (widget.isInstructor)
            GestureDetector(
              onTap: _toggleRecording,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _isRecording ? Colors.red : Colors.white24,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_isRecording ? Icons.stop_circle_rounded : Icons.fiber_manual_record_rounded,
                      color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(_isRecording ? 'Stop REC' : 'Record',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          const SizedBox(width: 8),
          const Icon(Icons.lock_rounded, color: Colors.white54, size: 18),
        ],
      ),
    );
  }

  Widget _buildVideoArea() {
    // On web: use HtmlElementView (same as working doctor-patient call)
    // platformViewRegistry creates divs IN Flutter's layout — buttons work naturally
    if (kIsWeb && _cameraViewName != null) {
      return Stack(
        children: [
          // Video platform view — contains lms-local-video + lms-remote-main
          SizedBox.expand(child: HtmlElementView(viewType: _cameraViewName!)),
          // Raised hand banner
          if (_raisedHands.isNotEmpty)
            Positioned(
              top: 12, left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                  const Text('✋', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text('${_raisedHands.length} hand(s) raised',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
        ],
      );
    }
    if (kIsWeb) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
          SizedBox(height: 12),
          Text('Connecting...', style: TextStyle(color: Colors.white54, fontSize: 13)),
        ]),
      );
    }

    return Stack(
      children: [
        // Video grid (mobile / fallback)
        _remoteUids.isEmpty
            ? _buildSelfVideoTile(isLarge: true)
            : _buildVideoGrid(),

        // Self preview (small, when others present)
        if (_remoteUids.isNotEmpty)
          Positioned(
            right: 12,
            bottom: 12,
            child: _buildSelfVideoTile(isLarge: false),
          ),

        // Raised hand notifications
        if (_raisedHands.isNotEmpty)
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                const Text('✋', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text('${_raisedHands.length} hand(s) raised',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _buildVideoGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _remoteUids.length <= 1 ? 2 : _remoteUids.length <= 3 ? 2 : 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 16 / 9,
      ),
      itemCount: _remoteUids.length,
      itemBuilder: (context, i) {
        return _buildRemoteVideoTile(_remoteUids[i]);
      },
    );
  }

  Widget _buildSelfVideoTile({required bool isLarge}) {
    return Container(
      width: isLarge ? double.infinity : 160,
      height: isLarge ? double.infinity : 90,
      decoration: BoxDecoration(
        color: const Color(0xFF2D3748),
        borderRadius: BorderRadius.circular(isLarge ? 0 : 8),
        border: isLarge ? null : Border.all(color: Colors.white24, width: 1),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (kIsWeb && _cameraOn && _cameraViewName != null)
            HtmlElementView(viewType: _cameraViewName!)
          else if (!kIsWeb && _cameraOn)
            lmsGetLocalVideoWidget(_cameraViewName)
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: isLarge ? 40 : 20,
                    backgroundColor: AppColors.primaryColor,
                    child: Text(
                      _currentUserName.isNotEmpty ? _currentUserName[0].toUpperCase() : 'Y',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isLarge ? 32 : 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (isLarge) ...[
                    const SizedBox(height: 12),
                    Text(_currentUserName, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  ],
                ],
              ),
            ),
          // Name + mic badge
          Positioned(
            bottom: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  _micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                  size: 12,
                  color: _micOn ? Colors.white : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  '$_currentUserName${widget.isInstructor ? ' (Host)' : ''} (You)',
                  style: TextStyle(color: Colors.white, fontSize: isLarge ? 12 : 9),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteVideoTile(int uid) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2D3748),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!kIsWeb)
            lmsGetRemoteVideoWidget(uid, 'lms_${widget.courseId}')
          else
            Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blueGrey,
                  child: Text('${uid % 100}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 8),
                const Text('Participant', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
          Positioned(
            bottom: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.mic_rounded, size: 12, color: Colors.white),
                SizedBox(width: 4),
                Text('Student', style: TextStyle(color: Colors.white, fontSize: 11)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidePanel() {
    return Container(
      width: 300,
      color: const Color(0xFF252D3D),
      child: Column(
        children: [
          // Panel tabs
          TabBar(
            controller: _panelTab,
            indicatorColor: AppColors.primaryColor,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: const [
              Tab(text: 'Chat'),
              Tab(text: 'People'),
              Tab(text: 'Polls'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _panelTab,
              children: [
                _buildChatPanel(),
                _buildParticipantsPanel(),
                _buildPollsPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPanel() {
    return Column(
      children: [
        Expanded(
          child: _chatMessages.isEmpty
              ? const Center(child: Text('No messages yet', style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  controller: _chatScroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: _chatMessages.length,
                  itemBuilder: (ctx, i) {
                    final msg = _chatMessages[i];
                    final isMe = msg['isMe'] == true || msg['sender'] == _currentUserName;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${msg['sender']} · ${msg['time']}',
                            style: const TextStyle(color: Colors.white54, fontSize: 10),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isMe ? AppColors.primaryColor : const Color(0xFF3D4A5C),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              msg['text'] ?? '',
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        // Chat input
        Container(
          padding: const EdgeInsets.all(8),
          color: const Color(0xFF1C2333),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _chatCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Send a message...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF3D4A5C),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onSubmitted: (_) => _sendChat(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendChat,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildParticipantsPanel() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Waiting room section (instructor only)
        if (widget.isInstructor && _waitingStudents.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.hourglass_empty, color: Colors.orange, size: 16),
                  const SizedBox(width: 6),
                  Text('Waiting Room (${_waitingStudents.length})',
                      style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w700, fontSize: 13)),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      // Admit all
                      try { await _lms.admitStudent(sessionId: _sessionDocId, studentId: 'all'); } catch(_) {}
                    },
                    child: const Text('Admit All', style: TextStyle(color: Colors.orange, fontSize: 11)),
                  ),
                ]),
                ..._waitingStudents.map((name) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    CircleAvatar(radius: 14, backgroundColor: Colors.orange.withValues(alpha: 0.3),
                        child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(name, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                    ElevatedButton(
                      onPressed: () => _admitStudent(''),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                      child: const Text('Admit', style: TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ]),
                )),
              ],
            ),
          ),
        ],

        Text('${_participants.length} participant(s)',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 8),
        _participantTile(_currentUserName, isHost: widget.isInstructor, isYou: true),
        ..._participants.where((p) => p['id'] != _currentUserId).map((p) =>
            _participantTile(p['name'] ?? 'Participant', isHost: p['isInstructor'] == true, isYou: false)),
      ],
    );
  }

  Widget _participantTile(String name, {required bool isHost, required bool isYou}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: isHost ? Colors.amber : const Color(0xFF3D4A5C),
        child: Text(name[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      title: Text(
        '$name${isYou ? ' (You)' : ''}${isHost ? ' 👑' : ''}',
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
      trailing: widget.isInstructor && !isYou
          ? IconButton(
              icon: const Icon(Icons.mic_off_rounded, color: Colors.white54, size: 18),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mute control coming soon'), duration: Duration(seconds: 1)),
                );
              },
            )
          : null,
    );
  }

  Widget _buildPollsPanel() {
    return Column(
      children: [
        if (widget.isInstructor)
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              onPressed: _createPoll,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Poll'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
          ),
        Expanded(
          child: _polls.isEmpty
              ? const Center(child: Text('No active polls', style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _polls.length,
                  itemBuilder: (ctx, i) => _buildPollCard(_polls[i], i),
                ),
        ),
      ],
    );
  }

  Widget _buildPollCard(Map<String, dynamic> poll, int index) {
    // Backend options are plain strings: ["Option A", "Option B", ...]
    final rawOptions = poll['options'];
    final options = (rawOptions is List)
        ? rawOptions.map((o) => o.toString()).toList()
        : <String>[];

    // Vote counts come from the responses array: [{optionIndex, userId, ...}]
    final responses = (poll['responses'] as List?) ?? [];
    final totalVotes = responses.length;

    final pollId = poll['_id']?.toString() ?? poll['id']?.toString() ?? '';
    final votedIndex = _votedPolls[pollId]; // int?
    final hasVoted = votedIndex != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF3D4A5C),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(poll['question'] ?? 'Poll',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 10),
          ...options.asMap().entries.map((entry) {
            final optIndex = entry.key;
            final optText = entry.value;
            final votes = responses.where((r) {
              if (r is! Map) return false;
              final ri = r['optionIndex'];
              if (ri is int) return ri == optIndex;
              if (ri is num) return ri.toInt() == optIndex;
              return false;
            }).length;
            final pct = totalVotes > 0 ? votes / totalVotes : 0.0;
            final isMyVote = votedIndex == optIndex;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Student can tap to vote if not voted yet; instructor always sees results
                if (!widget.isInstructor && !hasVoted)
                  GestureDetector(
                    onTap: () async {
                      if (pollId.isNotEmpty) {
                        setState(() => _votedPolls[pollId] = optIndex);
                        try {
                          await _lms.respondToPoll(pollId: pollId, optionIndex: optIndex);
                        } catch (_) {}
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(optText, style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  )
                else ...[
                  Row(children: [
                    Expanded(child: Text(optText, style: TextStyle(
                        color: isMyVote ? AppColors.primaryColor : Colors.white70, fontSize: 12))),
                    if (isMyVote) const Icon(Icons.check_circle_rounded, color: AppColors.primaryColor, size: 14),
                    const SizedBox(width: 4),
                    Text('$votes', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: Colors.white24,
                          valueColor: AlwaysStoppedAnimation(
                              isMyVote ? AppColors.primaryColor : Colors.blueGrey),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${(pct * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ]),
                ],
              ]),
            );
          }),
          const SizedBox(height: 4),
          Text('$totalVotes vote(s)', style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }

  void _createPoll() {
    final questionCtrl = TextEditingController();
    final List<TextEditingController> optionCtrls = [
      TextEditingController(text: 'Option A'),
      TextEditingController(text: 'Option B'),
    ];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) => AlertDialog(
        backgroundColor: const Color(0xFF252D3D),
        title: const Text('Create Poll', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: questionCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Question',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primaryColor)),
              ),
            ),
            const SizedBox(height: 12),
            ...optionCtrls.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: e.value,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Option ${e.key + 1}',
                  labelStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.primaryColor)),
                ),
              ),
            )),
            TextButton.icon(
              onPressed: () => setState(() => optionCtrls.add(TextEditingController(text: 'Option ${optionCtrls.length + 1}'))),
              icon: const Icon(Icons.add, color: AppColors.primaryColor),
              label: const Text('Add option', style: TextStyle(color: AppColors.primaryColor)),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor),
            onPressed: () async {
              Navigator.pop(ctx);
              if (questionCtrl.text.isNotEmpty && _sessionDocId.isNotEmpty) {
                final options = optionCtrls.where((c) => c.text.isNotEmpty).map((c) => c.text).toList();
                // Save poll to backend so students can see it
                try {
                  await _lms.createLiveSessionPoll(
                    sessionId: _sessionDocId,
                    question: questionCtrl.text,
                    options: options,
                  );
                } catch (e) {
                  debugPrint('Poll save error: $e');
                }
                this.setState(() {
                  _polls.add({
                    'question': questionCtrl.text,
                    'options': options,
                    'responses': [],
                  });
                });
                _panelTab.animateTo(2);
              }
            },
            child: const Text('Launch Poll'),
          ),
        ],
      )),
    );
  }

  Widget _buildBottomBar() {
    final isMobile = MediaQuery.of(context).size.width < 600;

    final micBtn = _controlBtn(
      icon: _micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
      label: _micOn ? 'Mute' : 'Unmute',
      color: _micOn ? Colors.white : Colors.red,
      onTap: _toggleMic,
    );
    final camBtn = _controlBtn(
      icon: _cameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
      label: _cameraOn ? 'Stop Video' : 'Start Video',
      color: _cameraOn ? Colors.white : Colors.red,
      onTap: _toggleCamera,
    );
    final chatBtn = _controlBtn(
      icon: Icons.chat_bubble_outline_rounded,
      label: 'Chat',
      color: _chatOpen ? AppColors.primaryColor : Colors.white,
      onTap: () {
        setState(() {
          _chatOpen = !_chatOpen;
          _participantsOpen = false;
          if (_chatOpen) _panelTab.animateTo(0);
        });
        if (kIsWeb) lmsSetPanelWidth(_chatOpen);
      },
      badge: _chatMessages.isNotEmpty ? '${_chatMessages.length}' : null,
    );
    final peopleBtn = _controlBtn(
      icon: Icons.people_rounded,
      label: 'People',
      color: _participantsOpen ? AppColors.primaryColor : Colors.white,
      onTap: () {
        setState(() {
          _participantsOpen = !_participantsOpen;
          _chatOpen = _participantsOpen;
          if (_participantsOpen) _panelTab.animateTo(1);
        });
        if (kIsWeb) lmsSetPanelWidth(_participantsOpen);
      },
    );
    final handBtn = !widget.isInstructor
        ? _controlBtn(
            icon: Icons.back_hand_rounded,
            label: _handRaised ? 'Lower Hand' : 'Raise Hand',
            color: _handRaised ? Colors.amber : Colors.white,
            onTap: _toggleHand,
          )
        : null;
    final pollsBtn = widget.isInstructor
        ? _controlBtn(
            icon: Icons.poll_rounded,
            label: 'Polls',
            color: Colors.white,
            onTap: () {
              setState(() {
                _chatOpen = true;
                _participantsOpen = false;
                _panelTab.animateTo(2);
              });
              if (kIsWeb) lmsSetPanelWidth(true);
            },
          )
        : null;
    final endBtn = GestureDetector(
      onTap: _endSession,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 20,
          vertical: isMobile ? 8 : 10,
        ),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
        child: Text(
          widget.isInstructor ? 'End' : 'Leave',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );

    if (isMobile) {
      // 2-row mobile layout — no overflow
      return Container(
        color: const Color(0xFF252D3D),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: all control buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                micBtn,
                camBtn,
                if (handBtn != null) handBtn,
                chatBtn,
                peopleBtn,
                if (pollsBtn != null) pollsBtn,
              ],
            ),
            const SizedBox(height: 6),
            // Row 2: end/leave full-width
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _endSession,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                  child: Center(
                    child: Text(
                      widget.isInstructor ? 'End Session for All' : 'Leave Session',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Desktop / tablet: original single-row layout
    return Container(
      height: 70,
      color: const Color(0xFF252D3D),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          micBtn,
          const SizedBox(width: 8),
          camBtn,
          const SizedBox(width: 8),
          if (handBtn != null) ...[handBtn, const SizedBox(width: 8)],
          chatBtn,
          const SizedBox(width: 8),
          peopleBtn,
          const SizedBox(width: 8),
          if (pollsBtn != null) ...[pollsBtn, const SizedBox(width: 8)],
          const Spacer(),
          endBtn,
        ],
      ),
    );
  }

  Widget _controlBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: color, size: 22),
              if (badge != null)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 10)),
        ]),
      ),
    );
  }
}
