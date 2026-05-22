import 'dart:async';
import 'package:flutter/material.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/services/consultation_service.dart';
import 'package:icare/models/consultation_message.dart';
import 'package:icare/screens/video_call.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

class ConsultationChatScreen extends StatefulWidget {
  final String consultationId;
  final String doctorName;
  final String patientName;
  final bool isDoctor;

  const ConsultationChatScreen({
    super.key,
    required this.consultationId,
    required this.doctorName,
    required this.patientName,
    required this.isDoctor,
  });

  @override
  State<ConsultationChatScreen> createState() => _ConsultationChatScreenState();
}

class _ConsultationChatScreenState extends State<ConsultationChatScreen> {
  final ConsultationService _consultationService = ConsultationService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ConsultationMessage> _messages = [];
  bool _isLoading = true;
  Timer? _timer;
  Duration _consultationDuration = Duration.zero;
  final Duration _minDuration = const Duration(minutes: 10);
  final Duration _maxDuration = const Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _startTimer();
    _sendConsentMessage();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _consultationDuration += const Duration(seconds: 1);

        // Auto-end after 30 minutes
        if (_consultationDuration >= _maxDuration) {
          _showAutoEndDialog();
          timer.cancel();
        }
      });
    });
  }

  void _showAutoEndDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Consultation Time Limit Reached'),
        content: const Text('The maximum consultation duration of 30 minutes has been reached. The consultation will now end.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _endConsultation();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendConsentMessage() async {
    if (widget.isDoctor) {
      // Auto-send consent message from doctor
      final consentMessage = 'Hi, I am Dr. ${widget.doctorName}. I confirm that telehealth has limitations and some emergencies require in-person visits.';
      await _consultationService.sendMessage(
        consultationId: widget.consultationId,
        message: consentMessage,
      );
      _loadMessages();
    }
  }

  Future<void> _loadMessages() async {
    final result = await _consultationService.getMessages(widget.consultationId);
    if (result['success'] && mounted) {
      setState(() {
        _messages = (result['messages'] as List)
            .map((m) => ConsultationMessage.fromJson(m))
            .toList();
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();

    final result = await _consultationService.sendMessage(
      consultationId: widget.consultationId,
      message: message,
    );

    if (result['success']) {
      _loadMessages();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${result['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final uploadResult = await _consultationService.uploadAttachment(
        result.files.single.path!,
      );

      if (uploadResult['success']) {
        await _consultationService.sendMessage(
          consultationId: widget.consultationId,
          message: 'Sent an attachment',
          attachmentUrl: uploadResult['url'],
        );
        _loadMessages();
      }
    }
  }

  void _startVideoCall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => VideoCall(
          channelName: widget.consultationId,
          remoteUserName: widget.isDoctor ? widget.patientName : widget.doctorName,
          consultationId: widget.consultationId,
          onCallEnded: () {
            // Return to chat after video ends
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  void _startVoiceCall() {
    // TODO: Implement voice call functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Voice call feature coming soon')),
    );
  }

  Future<void> _endConsultation() async {
    // Check minimum duration
    if (_consultationDuration < _minDuration && widget.isDoctor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Consultation must be at least 10 minutes long'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Consultation'),
        content: const Text('Are you sure you want to end this consultation? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('End Consultation'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await _consultationService.endConsultation(widget.consultationId);
      if (result['success'] && mounted) {
        Navigator.pop(context);
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isDoctor ? widget.patientName : 'Dr. ${widget.doctorName}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              'Consultation - ${_formatDuration(_consultationDuration)}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_rounded, color: AppColors.primaryColor),
            onPressed: _startVoiceCall,
            tooltip: 'Voice Call',
          ),
          IconButton(
            icon: const Icon(Icons.videocam_rounded, color: AppColors.primaryColor),
            onPressed: _startVideoCall,
            tooltip: 'Video Call',
          ),
          if (widget.isDoctor)
            IconButton(
              icon: const Icon(Icons.description_rounded, color: AppColors.primaryColor),
              onPressed: () {
                // TODO: Open prescription form
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Prescription feature coming soon')),
                );
              },
              tooltip: 'Prescription',
            ),
          IconButton(
            icon: const Icon(Icons.call_end_rounded, color: Colors.red),
            onPressed: _endConsultation,
            tooltip: 'End Consultation',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) => _buildMessageBubble(_messages[i]),
                  ),
                ),
                _buildMessageInput(),
              ],
            ),
    );
  }

  Widget _buildMessageBubble(ConsultationMessage message) {
    final isMe = widget.isDoctor
        ? message.senderRole == 'doctor'
        : message.senderRole == 'patient';

    if (message.isSystemMessage) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.message,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.attachmentUrl != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: const Icon(Icons.attach_file_rounded, size: 20),
              ),
            Text(
              message.message,
              style: TextStyle(
                color: isMe ? Colors.white : const Color(0xFF0F172A),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(message.timestamp),
              style: TextStyle(
                color: isMe ? Colors.white70 : const Color(0xFF94A3B8),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file_rounded, color: Color(0xFF64748B)),
            onPressed: _pickAndSendFile,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.primaryColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
