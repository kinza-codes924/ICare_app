import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:icare/services/live_session_controller.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import '../utils/lms_agora_stub.dart'
    if (dart.library.js_interop) '../utils/lms_agora_web.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LIVE STREAM VIEW
// Provides a unified view for both Instructor and Student live sessions.
// The StudentView receives route arguments (sessionId, courseId, sessionTitle)
// and uses them to join the EXACT same channel as the Instructor.
//
// CRITICAL FIX for Bug #1 (Student Routing Crash):
// - Validates all route arguments before any JS/Agora call
// - Shows a descriptive error page instead of crashing
// - Uses LiveSessionController for null-safe session join
// ─────────────────────────────────────────────────────────────────────────────

class LiveStreamView extends StatefulWidget {
  final String sessionId;
  final String courseId;
  final String sessionTitle;
  final bool isInstructor;
  final String? lessonId;
  final String? moduleId;

  const LiveStreamView({
    super.key,
    required this.sessionId,
    required this.courseId,
    required this.sessionTitle,
    this.isInstructor = false,
    this.lessonId,
    this.moduleId,
  });

  @override
  State<LiveStreamView> createState() => _LiveStreamViewState();
}

class _LiveStreamViewState extends State<LiveStreamView> with SingleTickerProviderStateMixin {
  final LiveSessionController _controller = LiveSessionController();
  final LmsService _lms = LmsService();

  bool _joined = false;
  bool _loading = true;
  String? _fatalError;
  bool _micOn = true;
  bool _cameraOn = true;
  bool _chatOpen = false;
  bool _participantsOpen = false;
  bool _handRaised = false;
  bool _isRecording = false;

  late TabController _panelTab;
  final TextEditingController _chatCtrl = TextEditingController();
  final ScrollController _chatScroll = ScrollController();
  final List<Map<String, dynamic>> _chatMessages = [];
  final List<Map<String, dynamic>> _polls = [];
  final Map<String, int> _votedPolls = {};
  final List<Map<String, dynamic>> _participants = [];
  final List<String> _raisedHands = [];
  final List<String> _waitingStudents = [];

  String _currentUserName = 'You';
  String _currentUserId = '';
  Timer? _sessionTimer;
  Timer? _syncTimer;
  int _sessionSeconds = 0;

  @override
  void initState() {
    super.initState();
    _panelTab = TabController(length: 3, vsync: this);

    // ── CRITICAL: Set controller callbacks ──────────────────────────────────
    _controller.onStateChanged = _onControllerStateChanged;
    _controller.onPermissionDenied = _onPermissionDenied;
    _controller.onJoinFailed = _onJoinFailed;

    // Start the join process
    _initSession();

    // Clear any stale "active course" state from previous sessions
    LmsLiveSessionScreen.activeCourseId = widget.courseId;
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _syncTimer?.cancel();
    _chatCtrl.dispose();
    _chatScroll.dispose();
    _panelTab.dispose();
    _controller.dispose();
    LmsLiveSessionScreen.activeCourseId = null;
    super.dispose();
  }

  // ── Controller Callbacks ───────────────────────────────────────────────────
  void _onControllerStateChanged() {
    if (mounted) {
      setState(() {
        _isRecording = _controller.isRecording;
        _sessionSeconds = _controller.sessionSeconds;
      });
    }
  }

  void _onPermissionDenied() {
    if (mounted) {
      setState(() {
        _fatalError =
            'Microphone access was denied. Please allow microphone access '
            'in your browser settings, then try again.';
        _loading = false;
      });
    }
  }

  void _onJoinFailed() {
    if (mounted) {
      setState(() {
        _fatalError = _controller.errorMessage ?? 'Failed to join session.';
        _loading = false;
      });
    }
  }

  // ── Session Init ───────────────────────────────────────────────────────────
  Future<void> _initSession() async {
    try {
      final user = await SharedPref().getUserData();
      _currentUserName =
          user?.name ?? (widget.isInstructor ? 'Instructor' : 'Student');
      _currentUserId = user?.id ?? '';

      final success = await _controller.joinSession(
        sessionId: widget.sessionId,
        courseId: widget.courseId,
        sessionTitle: widget.sessionTitle,
        isInstructor: widget.isInstructor,
        lessonId: widget.lessonId,
        moduleId: widget.moduleId,
      );

      if (success && mounted) {
        setState(() {
          _joined = true;
          _loading = false;
        });
        _controller.startSessionTimer();
        _startSyncPolling();
      } else if (!success && mounted && _fatalError == null) {
        // Controller already set error state via callback
        if (_controller.errorMessage != null) {
          setState(() {
            _fatalError = _controller.errorMessage;
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _fatalError = 'Unexpected error: $e';
          _loading = false;
        });
      }
    }
  }

  // ── Sync Polling ───────────────────────────────────────────────────────────
  void _startSyncPolling() {
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) => _syncState());
  }

  Future<void> _syncState() async {
    if (!mounted || _controller.sessionDocId.isEmpty) return;
    try {
      final data = await _lms.getSessionState(_controller.sessionDocId);
      final session = data['session'];
      if (session == null || !mounted) return;

      final attendees = (session['attendees'] as List?) ?? [];
      final newParticipants = attendees.map<Map<String, dynamic>>((a) => {
        'name': a['name'] ?? a['username'] ?? 'Participant',
        'id': a['_id']?.toString() ?? '',
        'isInstructor': false,
      }).toList();

      final waiting = (session['waitingStudents'] as List?) ?? [];
      final waitingNames =
          waiting.map((w) => w['name'] ?? w['username'] ?? 'Student').toList();

      final raisedHandsData = (session['raisedHands'] as List?) ??
          (session['handsRaised'] as List?) ??
          [];
      final newHands = raisedHandsData
          .map<String>((h) => h is Map
              ? (h['userName'] ?? h['name'] ?? 'Student').toString()
              : h.toString())
          .toList();

      List<dynamic> rawMessages = (session['chatMessages'] as List?) ?? [];
      if (rawMessages.isEmpty) {
        try {
          final chatData = await _lms.getSessionChatMessages(
            _controller.sessionDocId,
          );
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

      List<Map<String, dynamic>> newPolls = [];
      try {
        final pollsData = await _lms.getLiveSessionPolls(
          _controller.sessionDocId,
        );
        if (pollsData.isNotEmpty) {
          newPolls = pollsData
              .map<Map<String, dynamic>>(
                (p) => Map<String, dynamic>.from(p is Map ? p : {}),
              )
              .toList();
        } else {
          final pollsFromSession = (session['polls'] as List?) ?? [];
          newPolls = pollsFromSession
              .map<Map<String, dynamic>>(
                (p) => Map<String, dynamic>.from(p is Map ? p : {}),
              )
              .toList();
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _participants.clear();
          _participants.add({
            'name': '$_currentUserName (You)',
            'isInstructor': widget.isInstructor,
            'id': _currentUserId,
          });
          _participants.addAll(
            newParticipants.where((p) => p['id'] != _currentUserId),
          );
          _raisedHands
            ..clear()
            ..addAll(newHands);
          _chatMessages
            ..clear()
            ..addAll(newMessages);
          _polls
            ..clear()
            ..addAll(newPolls);
          _waitingStudents
            ..clear()
            ..addAll(waitingNames.cast<String>());

          if (_chatMessages.isNotEmpty && _chatScroll.hasClients) {
            _chatScroll.animateTo(
              _chatScroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (_) {}
  }

  // ── Timer ──────────────────────────────────────────────────────────────────
  String get _timerText {
    final h = _sessionSeconds ~/ 3600;
    final m = (_sessionSeconds % 3600) ~/ 60;
    final s = _sessionSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  void _toggleMic() {
    _micOn = !_micOn;
    lmsMuteMic(!_micOn);
    setState(() {});
  }

  void _toggleCamera() {
    _cameraOn = !_cameraOn;
    lmsMuteCamera(!_cameraOn);
    setState(() {});
  }

  void _toggleHand() {
    setState(() => _handRaised = !_handRaised);
    _controller.toggleHand(_handRaised);
  }

  void _sendChat() {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    _chatCtrl.clear();
    setState(() {
      _chatMessages.add({
        'sender': _currentUserName,
        'text': text,
        'time': _timerText,
        'isMe': true,
      });
    });
    _controller.sendChatMessage(text);
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

  Future<void> _toggleRecording() async {
    await _controller.toggleRecording(_controller.sessionDocId);
    setState(() => _isRecording = _controller.isRecording);
  }

  Future<void> _endSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          widget.isInstructor ? 'End Session for All?' : 'Leave Session?',
        ),
        content: Text(
          widget.isInstructor
              ? 'This will end the session for all participants.'
              : 'Are you sure you want to leave?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(widget.isInstructor ? 'End for All' : 'Leave'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _controller.endSession(
        isInstructor: widget.isInstructor,
        courseId: widget.courseId,
        sessionDocId: _controller.sessionDocId,
        lessonId: widget.lessonId,
        moduleId: widget.moduleId,
      );
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _admitStudent(String studentId) async {
    if (studentId.isEmpty || _controller.sessionDocId.isEmpty) return;
    try {
      await _lms.admitStudent(
        sessionId: _controller.sessionDocId,
        studentId: studentId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student admitted!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // ── LOADING STATE (showing join progress) ─────────────────────────────
    if (_loading) {
      String statusText = 'Joining session...';
      switch (_controller.joinState) {
        case SessionJoinState.validating:
          statusText = 'Validating session...';
          break;
        case SessionJoinState.requestingPermission:
          statusText = 'Requesting microphone access...';
          break;
        case SessionJoinState.joining:
          statusText = 'Connecting to stream...';
          break;
        default:
          statusText = 'Joining session...';
      }
      return Scaffold(
        backgroundColor: const Color(0xFF1C2333),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                statusText,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // ── ERROR STATE (null-safety guard triggered) ─────────────────────────
    if (_fatalError != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1C2333),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Cannot Join Session',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _fatalError!,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => goBackOrHome(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Go Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── MAIN SESSION UI ───────────────────────────────────────────────────
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Container(color: const Color(0xFF1C2333)),
            Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: LayoutBuilder(
                    builder: (ctx, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      if (isMobile) {
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
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(16),
                                        ),
                                      ),
                                      child: Column(children: [
                                        const SizedBox(height: 6),
                                        Container(
                                          width: 40,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Colors.white38,
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        ),
                                        Expanded(
                                          child: _buildSidePanel(),
                                        ),
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
                          if (_chatOpen || _participantsOpen)
                            _buildSidePanel(),
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

  // ── TOP BAR ────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      height: 52,
      color: const Color(0xFF252D3D),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '● LIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _timerText,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              widget.sessionTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(children: [
            const Icon(Icons.people_rounded, color: Colors.white54, size: 18),
            const SizedBox(width: 4),
            Text(
              '${_participants.length}',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ]),
          const SizedBox(width: 10),
          if (widget.isInstructor)
            GestureDetector(
              onTap: _toggleRecording,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _isRecording ? Colors.red : Colors.white24,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    _isRecording
                        ? Icons.stop_circle_rounded
                        : Icons.fiber_manual_record_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isRecording ? 'Stop REC' : 'Record',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ]),
              ),
            ),
          const SizedBox(width: 8),
          const Icon(Icons.lock_rounded, color: Colors.white54, size: 18),
        ],
      ),
    );
  }

  // ── VIDEO AREA ─────────────────────────────────────────────────────────────
  Widget _buildVideoArea() {
    // On web, use the platform view registered by controller
    if (kIsWeb && _joined) {
      return Stack(
        children: [
          const SizedBox.expand(),
          if (_raisedHands.isNotEmpty)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(children: [
                  const Text('✋', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    '${_raisedHands.length} hand(s) raised',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ]),
              ),
            ),
        ],
      );
    }
    if (kIsWeb) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
            SizedBox(height: 12),
            Text(
              'Connecting...',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Non-web: placeholder video grid
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primaryColor,
            child: Text(
              _currentUserName.isNotEmpty
                  ? _currentUserName[0].toUpperCase()
                  : 'Y',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _currentUserName,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                color: _micOn ? Colors.white : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                widget.isInstructor ? 'Instructor (Host)' : 'Student',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── SIDE PANEL ─────────────────────────────────────────────────────────────
  Widget _buildSidePanel() {
    return Container(
      width: 300,
      color: const Color(0xFF252D3D),
      child: Column(
        children: [
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

  // ── CHAT PANEL ─────────────────────────────────────────────────────────────
  Widget _buildChatPanel() {
    return Column(
      children: [
        Expanded(
          child: _chatMessages.isEmpty
              ? const Center(
                  child: Text(
                    'No messages yet',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  controller: _chatScroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: _chatMessages.length,
                  itemBuilder: (ctx, i) {
                    final msg = _chatMessages[i];
                    final isMe = msg['isMe'] == true ||
                        msg['sender'] == _currentUserName;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${msg['sender']} · ${msg['time']}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? AppColors.primaryColor
                                  : const Color(0xFF3D4A5C),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              msg['text'] ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
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
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  // ── PARTICIPANTS PANEL ─────────────────────────────────────────────────────
  Widget _buildParticipantsPanel() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
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
                  const Icon(Icons.hourglass_empty,
                      color: Colors.orange, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Waiting Room (${_waitingStudents.length})',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _admitStudent('all'),
                    child: const Text(
                      'Admit All',
                      style: TextStyle(color: Colors.orange, fontSize: 11),
                    ),
                  ),
                ]),
                ..._waitingStudents.map((name) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.orange.withValues(alpha: 0.3),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _admitStudent(''),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                          ),
                          child: const Text(
                            'Admit',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ]),
                    )),
              ],
            ),
          ),
        ],
        Text(
          '${_participants.length} participant(s)',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 8),
        _participantTile(
          _currentUserName,
          isHost: widget.isInstructor,
          isYou: true,
        ),
        ..._participants
            .where((p) => p['id'] != _currentUserId)
            .map(
              (p) => _participantTile(
                p['name'] ?? 'Participant',
                isHost: p['isInstructor'] == true,
                isYou: false,
              ),
            ),
      ],
    );
  }

  Widget _participantTile(
    String name, {
    required bool isHost,
    required bool isYou,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: isHost ? Colors.amber : const Color(0xFF3D4A5C),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(
        '$name${isYou ? ' (You)' : ''}${isHost ? ' 👑' : ''}',
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
    );
  }

  // ── POLLS PANEL ────────────────────────────────────────────────────────────
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
              ? const Center(
                  child: Text(
                    'No active polls',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _polls.length,
                  itemBuilder: (ctx, i) => _buildPollCard(_polls[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildPollCard(Map<String, dynamic> poll) {
    final rawOptions = poll['options'];
    final options = (rawOptions is List)
        ? rawOptions.map((o) => o.toString()).toList()
        : <String>[];
    final responses = (poll['responses'] as List?) ?? [];
    final totalVotes = responses.length;
    final pollId = poll['_id']?.toString() ?? poll['id']?.toString() ?? '';
    final votedIndex = _votedPolls[pollId];
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
          Text(
            poll['question'] ?? 'Poll',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.isInstructor && !hasVoted)
                    GestureDetector(
                      onTap: () async {
                        if (pollId.isNotEmpty) {
                          setState(() => _votedPolls[pollId] = optIndex);
                          try {
                            await _lms.respondToPoll(
                              pollId: pollId,
                              optionIndex: optIndex,
                            );
                          } catch (_) {}
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          optText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    Row(children: [
                      Expanded(
                        child: Text(
                          optText,
                          style: TextStyle(
                            color: isMyVote
                                ? AppColors.primaryColor
                                : Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (isMyVote)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primaryColor,
                          size: 14,
                        ),
                      const SizedBox(width: 4),
                      Text(
                        '$votes',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
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
                              isMyVote
                                  ? AppColors.primaryColor
                                  : Colors.blueGrey,
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(pct * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ]),
                  ],
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          Text(
            '$totalVotes vote(s)',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
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
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: const Color(0xFF252D3D),
          title: const Text(
            'Create Poll',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: questionCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Question',
                    labelStyle: TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primaryColor),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...optionCtrls.asMap().entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          controller: e.value,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Option ${e.key + 1}',
                            labelStyle:
                                const TextStyle(color: Colors.white54),
                            enabledBorder: const OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.white24),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.primaryColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                TextButton.icon(
                  onPressed: () => setState(
                    () => optionCtrls.add(
                      TextEditingController(
                        text: 'Option ${optionCtrls.length + 1}',
                      ),
                    ),
                  ),
                  icon: const Icon(
                    Icons.add,
                    color: AppColors.primaryColor,
                  ),
                  label: const Text(
                    'Add option',
                    style: TextStyle(color: AppColors.primaryColor),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                if (questionCtrl.text.isNotEmpty &&
                    _controller.sessionDocId.isNotEmpty) {
                  final options = optionCtrls
                      .where((c) => c.text.isNotEmpty)
                      .map((c) => c.text)
                      .toList();
                  try {
                    await _lms.createLiveSessionPoll(
                      sessionId: _controller.sessionDocId,
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
        ),
      ),
    );
  }

  // ── BOTTOM BAR ─────────────────────────────────────────────────────────────
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
    final endBtn = GestureDetector(
      onTap: _endSession,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 20,
          vertical: isMobile ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          widget.isInstructor ? 'End' : 'Leave',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );

    if (isMobile) {
      return Container(
        color: const Color(0xFF252D3D),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                micBtn,
                camBtn,
                if (handBtn != null) handBtn,
                chatBtn,
                peopleBtn,
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _endSession,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      widget.isInstructor
                          ? 'End Session for All'
                          : 'Leave Session',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Forward reference for the static activeCourseId field ───────────────────
// The LmsLiveSessionScreen has a static activeCourseId field that we clear
// when entering/leaving this view.
class LmsLiveSessionScreen {
  static String? activeCourseId;
}