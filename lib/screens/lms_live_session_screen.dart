import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:icare/config/agora_config.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/utils/theme.dart';

/// LMS Live Session Screen — Google Meet style, Agora-based
/// Completely separate from doctor-patient consultation
class LmsLiveSessionScreen extends StatefulWidget {
  final String sessionId;
  final String courseId;
  final String sessionTitle;
  final bool isInstructor;

  const LmsLiveSessionScreen({
    super.key,
    required this.sessionId,
    required this.courseId,
    required this.sessionTitle,
    this.isInstructor = false,
  });

  @override
  State<LmsLiveSessionScreen> createState() => _LmsLiveSessionScreenState();
}

class _LmsLiveSessionScreenState extends State<LmsLiveSessionScreen>
    with SingleTickerProviderStateMixin {
  // Agora
  RtcEngine? _engine;
  bool _joined = false;
  bool _micOn = true;
  bool _cameraOn = true;
  bool _loading = true;
  String? _error;
  int? _remoteUid;
  final List<int> _remoteUids = [];

  // UI State
  bool _chatOpen = false;
  bool _participantsOpen = false;
  bool _handRaised = false;
  bool _screenRecording = false;
  late TabController _panelTab;

  // Chat
  final TextEditingController _chatCtrl = TextEditingController();
  final ScrollController _chatScroll = ScrollController();
  final List<Map<String, String>> _chatMessages = [];

  // Polls
  final List<Map<String, dynamic>> _polls = [];

  // Participants
  final List<Map<String, dynamic>> _participants = [];
  final List<String> _raisedHands = [];

  // Session info
  String _currentUserName = 'You';
  String _currentUserId = '';
  Timer? _sessionTimer;
  int _sessionSeconds = 0;

  final LmsService _lms = LmsService();

  @override
  void initState() {
    super.initState();
    _panelTab = TabController(length: 3, vsync: this);
    _initSession();
  }

  @override
  void dispose() {
    _engine?.leaveChannel();
    _engine?.release();
    _sessionTimer?.cancel();
    _chatCtrl.dispose();
    _chatScroll.dispose();
    _panelTab.dispose();
    super.dispose();
  }

  Future<void> _initSession() async {
    try {
      final user = await SharedPref().getUserData();
      _currentUserName = user?.name ?? (widget.isInstructor ? 'Instructor' : 'Student');
      _currentUserId = user?.id ?? '';

      // Add self to participants
      _participants.add({
        'uid': 0,
        'name': _currentUserName,
        'isInstructor': widget.isInstructor,
        'micOn': true,
        'cameraOn': true,
      });

      await _initAgora();
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _initAgora() async {
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(
      appId: AgoraConfig.appId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        if (mounted) setState(() { _joined = true; _loading = false; });
        _startSessionTimer();
      },
      onUserJoined: (connection, remoteUid, elapsed) {
        if (mounted) setState(() {
          if (!_remoteUids.contains(remoteUid)) _remoteUids.add(remoteUid);
        });
      },
      onUserOffline: (connection, remoteUid, reason) {
        if (mounted) setState(() {
          _remoteUids.remove(remoteUid);
        });
      },
      onError: (err, msg) {
        if (mounted) setState(() { _error = msg; _loading = false; });
      },
    ));

    // Enable video
    await _engine!.enableVideo();
    await _engine!.enableAudio();

    // Set role
    await _engine!.setClientRole(
      role: widget.isInstructor
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleBroadcaster,
    );

    if (!kIsWeb) {
      await _engine!.startPreview();
    }

    // Join channel — use sessionId as channel name
    final channelName = 'lms_${widget.sessionId}';
    await _engine!.joinChannel(
      token: '',
      channelId: channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      ),
    );
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

  Future<void> _toggleMic() async {
    _micOn = !_micOn;
    await _engine?.muteLocalAudioStream(!_micOn);
    setState(() {});
  }

  Future<void> _toggleCamera() async {
    _cameraOn = !_cameraOn;
    await _engine?.muteLocalVideoStream(!_cameraOn);
    setState(() {});
  }

  Future<void> _flipCamera() async {
    await _engine?.switchCamera();
  }

  void _toggleHand() {
    setState(() => _handRaised = !_handRaised);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_handRaised ? 'Hand raised ✋' : 'Hand lowered'),
        duration: const Duration(seconds: 2),
        backgroundColor: _handRaised ? Colors.orange : Colors.grey,
      ),
    );
  }

  void _sendChat() {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _chatMessages.add({'sender': _currentUserName, 'text': text, 'time': _timerText});
    });
    _chatCtrl.clear();
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
      await _engine?.leaveChannel();
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
      backgroundColor: const Color(0xFF1C2333),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Row(
                children: [
                  // Main video area
                  Expanded(child: _buildVideoArea()),
                  // Side panel (chat/participants/polls)
                  if (_chatOpen || _participantsOpen)
                    _buildSidePanel(),
                ],
              ),
            ),
            _buildBottomBar(),
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
            Text('${_remoteUids.length + 1}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ]),
          const SizedBox(width: 12),
          // Security icon
          const Icon(Icons.lock_rounded, color: Colors.white54, size: 18),
        ],
      ),
    );
  }

  Widget _buildVideoArea() {
    return Stack(
      children: [
        // Video grid
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
                color: Colors.orange.withOpacity(0.9),
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
          if (_cameraOn && !kIsWeb && _joined)
            AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: _engine!,
                canvas: const VideoCanvas(uid: 0),
              ),
            )
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
                  '${_currentUserName}${widget.isInstructor ? ' (Host)' : ''} (You)',
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
            AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _engine!,
                canvas: VideoCanvas(uid: uid),
                connection: RtcConnection(channelId: 'lms_${widget.sessionId}'),
              ),
            )
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
                    final isMe = msg['sender'] == _currentUserName;
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
    final total = _remoteUids.length + 1;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('$total participant(s)',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 8),
        // Self
        _participantTile(_currentUserName, isHost: widget.isInstructor, isYou: true),
        // Others
        ..._remoteUids.map((uid) =>
            _participantTile('Participant $uid', isHost: false, isYou: false)),
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
    final options = (poll['options'] as List<Map>?) ?? [];
    final totalVotes = options.fold<int>(0, (s, o) => s + ((o['votes'] as int?) ?? 0));
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
          ...options.map((opt) {
            final votes = (opt['votes'] as int?) ?? 0;
            final pct = totalVotes > 0 ? votes / totalVotes : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(opt['text'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation(AppColors.primaryColor),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${(pct * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ]),
              ]),
            );
          }).toList(),
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
            onPressed: () {
              Navigator.pop(ctx);
              if (questionCtrl.text.isNotEmpty) {
                this.setState(() {
                  _polls.add({
                    'question': questionCtrl.text,
                    'options': optionCtrls.where((c) => c.text.isNotEmpty)
                        .map((c) => {'text': c.text, 'votes': 0}).toList(),
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
    return Container(
      height: 70,
      color: const Color(0xFF252D3D),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mic
          _controlBtn(
            icon: _micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
            label: _micOn ? 'Mute' : 'Unmute',
            color: _micOn ? Colors.white : Colors.red,
            onTap: _toggleMic,
          ),
          const SizedBox(width: 8),
          // Camera
          _controlBtn(
            icon: _cameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
            label: _cameraOn ? 'Stop Video' : 'Start Video',
            color: _cameraOn ? Colors.white : Colors.red,
            onTap: _toggleCamera,
          ),
          const SizedBox(width: 8),
          // Raise hand (students only)
          if (!widget.isInstructor)
            _controlBtn(
              icon: Icons.back_hand_rounded,
              label: _handRaised ? 'Lower Hand' : 'Raise Hand',
              color: _handRaised ? Colors.amber : Colors.white,
              onTap: _toggleHand,
            ),
          if (!widget.isInstructor) const SizedBox(width: 8),
          // Chat
          _controlBtn(
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
          ),
          const SizedBox(width: 8),
          // Participants
          _controlBtn(
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
          ),
          const SizedBox(width: 8),
          // Polls (instructor)
          if (widget.isInstructor)
            _controlBtn(
              icon: Icons.poll_rounded,
              label: 'Polls',
              color: Colors.white,
              onTap: () {
                setState(() {
                  _chatOpen = true;
                  _participantsOpen = false;
                  _panelTab.animateTo(2);
                });
              },
            ),
          if (widget.isInstructor) const SizedBox(width: 8),
          const Spacer(),
          // End/Leave button
          GestureDetector(
            onTap: _endSession,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.isInstructor ? 'End Session' : 'Leave',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
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
          Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 10)),
        ]),
      ),
    );
  }
}
