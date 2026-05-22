import 'dart:async';
import 'package:flutter/material.dart';
import 'package:icare/models/user.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/utils/shared_pref.dart';

/// Live Session Page with Chat, Raise Hand, Polls, Waiting Room
class LiveSessionPage extends StatefulWidget {
  final String sessionId;
  final String sessionTitle;
  final bool isInstructor;

  const LiveSessionPage({
    super.key,
    required this.sessionId,
    required this.sessionTitle,
    this.isInstructor = false,
  });

  @override
  State<LiveSessionPage> createState() => _LiveSessionPageState();
}

class _LiveSessionPageState extends State<LiveSessionPage> with SingleTickerProviderStateMixin {
  final LmsService _lms = LmsService();
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  late TabController _tabController;
  final List<dynamic> _chatMessages = [];
  final List<dynamic> _raisedHands = [];
  final List<dynamic> _waitingRoom = [];
  final List<dynamic> _polls = [];
  User? _currentUser;
  Timer? _pollTimer;
  bool _handRaised = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.isInstructor ? 4 : 3, vsync: this);
    _loadUser();
    _loadSessionData();
    _startPolling();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await SharedPref().getUserData();
    if (mounted) {
      setState(() => _currentUser = user);
    }
  }

  Future<void> _loadSessionData() async {
    try {
      // Load chat messages, raised hands, waiting room, polls
      // In real implementation, these would be separate API calls
      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _startPolling() {
    // Poll for updates every 3 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        _loadSessionData();
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    try {
      await _lms.sendLiveSessionChat(
        sessionId: widget.sessionId,
        message: text,
      );
      _chatController.clear();
      _loadSessionData();

      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_chatScrollController.hasClients) {
          _chatScrollController.animateTo(
            _chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleRaiseHand() async {
    try {
      await _lms.raiseHand(sessionId: widget.sessionId);
      setState(() => _handRaised = !_handRaised);
      _loadSessionData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _admitStudent(String studentId) async {
    try {
      await _lms.admitStudent(sessionId: widget.sessionId, studentId: studentId);
      _loadSessionData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student admitted'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        leading: const CustomBackButton(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.sessionTitle,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Live',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (!widget.isInstructor)
            IconButton(
              onPressed: _toggleRaiseHand,
              icon: Icon(
                _handRaised ? Icons.back_hand : Icons.back_hand_outlined,
                color: _handRaised ? Colors.amber : Colors.white,
              ),
              tooltip: 'Raise Hand',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: [
            const Tab(icon: Icon(Icons.videocam_rounded), text: 'Video'),
            const Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Chat'),
            const Tab(icon: Icon(Icons.poll_outlined), text: 'Polls'),
            if (widget.isInstructor)
              const Tab(icon: Icon(Icons.meeting_room_outlined), text: 'Waiting Room'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildVideoTab(),
                _buildChatTab(),
                _buildPollsTab(),
                if (widget.isInstructor) _buildWaitingRoomTab(),
              ],
            ),
    );
  }

  Widget _buildVideoTab() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off_rounded, size: 64, color: Colors.white54),
            SizedBox(height: 16),
            Text(
              'Video integration with Agora SDK',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              'Connect your Agora credentials to enable video',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTab() {
    return Column(
      children: [
        // Raised Hands Banner
        if (_raisedHands.isNotEmpty && widget.isInstructor)
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.amber.shade50,
            child: Row(
              children: [
                Icon(Icons.back_hand, color: Colors.amber.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_raisedHands.length} student(s) raised hand',
                    style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Show raised hands list
                  },
                  child: const Text('View'),
                ),
              ],
            ),
          ),

        // Chat Messages
        Expanded(
          child: _chatMessages.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 48, color: Color(0xFFCBD5E1)),
                      SizedBox(height: 12),
                      Text(
                        'No messages yet',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _chatMessages.length,
                  itemBuilder: (context, index) {
                    final msg = _chatMessages[index];
                    final isMe = msg['userId'] == _currentUser?.id;
                    return _buildChatMessage(msg, isMe);
                  },
                ),
        ),

        // Chat Input
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: AppColors.primaryColor,
                child: IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatMessage(Map<String, dynamic> msg, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
              child: Text(
                (msg['userName'] ?? 'U')[0].toUpperCase(),
                style: const TextStyle(color: AppColors.primaryColor, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Text(
                      msg['userName'] ?? 'User',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isMe ? Colors.white70 : const Color(0xFF64748B),
                      ),
                    ),
                  if (!isMe) const SizedBox(height: 4),
                  Text(
                    msg['message'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: isMe ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPollsTab() {
    return _polls.isEmpty
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.poll_outlined, size: 48, color: Color(0xFFCBD5E1)),
                SizedBox(height: 12),
                Text('No active polls', style: TextStyle(color: Color(0xFF94A3B8))),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _polls.length,
            itemBuilder: (context, index) {
              final poll = _polls[index];
              return _buildPollCard(poll);
            },
          );
  }

  Widget _buildPollCard(Map<String, dynamic> poll) {
    final options = (poll['options'] as List?) ?? [];
    final totalVotes = options.fold<int>(0, (sum, opt) => sum + ((opt['votes'] as int?) ?? 0));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.poll_rounded, color: AppColors.primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  poll['question'] ?? 'Poll',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...options.map((opt) {
            final votes = (opt['votes'] as int?) ?? 0;
            final percentage = totalVotes > 0 ? (votes / totalVotes * 100) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  // Vote on option
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              opt['text'] ?? '',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: percentage / 100,
                              backgroundColor: const Color(0xFFE2E8F0),
                              valueColor: const AlwaysStoppedAnimation(AppColors.primaryColor),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${percentage.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Text(
            '$totalVotes vote(s)',
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingRoomTab() {
    return _waitingRoom.isEmpty
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.meeting_room_outlined, size: 48, color: Color(0xFFCBD5E1)),
                SizedBox(height: 12),
                Text('No students waiting', style: TextStyle(color: Color(0xFF94A3B8))),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _waitingRoom.length,
            itemBuilder: (context, index) {
              final student = _waitingRoom[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                      child: Text(
                        (student['name'] ?? 'S')[0].toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student['name'] ?? 'Student',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Waiting to join',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _admitStudent(student['_id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Admit'),
                    ),
                  ],
                ),
              );
            },
          );
  }
}
