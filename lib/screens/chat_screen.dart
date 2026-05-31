import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:intl/intl.dart';
import '../services/chat_service.dart';
import '../services/call_service.dart';
import '../utils/theme.dart';
import '../utils/shared_pref.dart';
import 'video_call.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class ChatScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String? userImage;

  const ChatScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.userImage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final CallService _callService = CallService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isTyping = false;
  String _currentUserId = '';
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _loadCurrentUser();
      await _loadChatHistory();
      _setupTypingListener();
      // Poll for new messages every 5 seconds
      _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _loadChatHistory(silent: true);
      });
    } catch (e) {
      debugPrint('❌ Initialization error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize chat: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  String _currentUserName = '';

  Future<void> _loadCurrentUser() async {
    try {
      final userData = await SharedPref().getUserData();
      if (mounted) {
        setState(() {
          _currentUserId = userData?.id ?? '';
          _currentUserName = userData?.name ?? '';
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading current user: $e');
      if (mounted) {
        setState(() {
          _currentUserId = '';
        });
      }
    }
  }

  Future<void> _startCall({required bool isAudioOnly}) async {
    debugPrint('🚀 CALL BUTTON CLICKED! isAudioOnly: $isAudioOnly');
    debugPrint('🚀 Current user ID: $_currentUserId');
    debugPrint('🚀 Current user name: $_currentUserName');
    debugPrint('🚀 Remote user ID: ${widget.userId}');

    final channelName = _buildChannelName();
    debugPrint('🚀 Channel name: $channelName');

    // Send signal to backend so the other party gets notified
    await _callService.initiateCall(
      receiverId: widget.userId,
      channelName: channelName,
      callerName: _currentUserName.isNotEmpty ? _currentUserName : 'Unknown',
      callType: isAudioOnly ? 'audio' : 'video',
    );
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoCall(
          channelName: channelName,
          remoteUserName: widget.userName,
          isAudioOnly: isAudioOnly,
          currentUserId: _currentUserId,
          currentUserName: _currentUserName,
        ),
      ),
    );
  }

  void _setupTypingListener() {
    _messageController.addListener(() {
      final isCurrentlyTyping = _messageController.text.isNotEmpty;
      if (isCurrentlyTyping != _isTyping) {
        setState(() => _isTyping = isCurrentlyTyping);
        _chatService.sendTypingIndicator(widget.userId, isCurrentlyTyping);
      }
    });
  }

  Future<void> _loadChatHistory({bool silent = false}) async {
    try {
      if (widget.userId.isEmpty) throw Exception('User ID is empty');

      final messages = await _chatService.getChatHistory(widget.userId);

      if (mounted) {
        final prevCount = _messages.length;
        setState(() {
          _messages = messages;
          if (!silent) _isLoading = false;
        });
        // Only scroll to bottom if new messages arrived
        if (messages.length > prevCount) {
          _scrollToBottom();
        }
        if (!silent) _isLoading = false;
        _chatService.markAsRead(widget.userId).catchError((_) {});
      }
    } catch (e) {
      debugPrint('❌ Error loading chat history: $e');
      if (mounted && !silent) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load messages: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();
    setState(() => _isSending = true);

    try {
      final result = await _chatService.sendMessage(
        receiverId: widget.userId,
        message: messageText,
      );

      setState(() {
        final newMsg = result['data'];
        if (newMsg != null) {
          _messages.add(newMsg);
        }
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: const Text('Unable to submit. Please try again.')));
      }
      // Restore message text on failure
      _messageController.text = messageText;
    }
  }

  Future<void> _pickAndSendMessage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);

      if (image == null) return;

      setState(() => _isSending = true);

      // 1. Read bytes for web compatibility
      final bytes = await image.readAsBytes();

      // 2. Upload the file
      final uploadResult = await _chatService.uploadFile(
        filePath: kIsWeb ? null : image.path,
        bytes: bytes,
        fileName: image.name,
      );

      if (uploadResult['success'] == true) {
        // 2. Send message with attachment
        final result = await _chatService.sendMessage(
          receiverId: widget.userId,
          message: "[Image]",
          attachments: [
            {
              'url': uploadResult['fileUrl'],
              'name': uploadResult['fileName'],
              'fileType': 'image',
            },
          ],
        );

        setState(() {
          final newMsg = result['data'];
          if (newMsg != null) {
            _messages.add(newMsg);
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: const Text('Unable to submit. Please try again.')));
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result == null || result.files.single.path == null) return;

      setState(() => _isSending = true);

      // 1. Read bytes for web compatibility
      List<int> bytes;
      if (kIsWeb) {
        bytes = result.files.single.bytes!;
      } else {
        bytes = await File(result.files.single.path!).readAsBytes();
      }

      // 2. Upload the file
      final uploadResult = await _chatService.uploadFile(
        filePath: kIsWeb ? null : result.files.single.path,
        bytes: bytes,
        fileName: result.files.single.name,
      );

      if (uploadResult['success'] == true) {
        // 2. Send message with attachment
        final sendResult = await _chatService.sendMessage(
          receiverId: widget.userId,
          message: "[Document: ${result.files.single.name}]",
          attachments: [
            {
              'url': uploadResult['fileUrl'],
              'name': uploadResult['fileName'],
              'fileType': 'document',
            },
          ],
        );

        setState(() {
          final newMsg = sendResult['data'];
          if (newMsg != null) {
            _messages.add(newMsg);
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: const Text('Unable to submit. Please try again.')));
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _openAttachment(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: const Text('Something went wrong. Please try again.')));
      }
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.camera_alt,
                color: AppColors.primaryColor,
              ),
              title: Text('Camera'.tr()),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendMessage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: AppColors.primaryColor,
              ),
              title: Text('Gallery'.tr()),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendMessage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.insert_drive_file,
                color: AppColors.primaryColor,
              ),
              title: Text('Document'.tr()),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshMessages() async {
    await _loadChatHistory();
  }

  // Creates a consistent channel name from both user IDs (sorted so both sides join same channel)
  String _buildChannelName() {
    final ids = [_currentUserId, widget.userId]..sort();
    return 'call_${ids[0]}_${ids[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
              backgroundImage: widget.userImage != null
                  ? NetworkImage(widget.userImage!)
                  : null,
              child: widget.userImage == null
                  ? Text(
                      widget.userName[0].toUpperCase(),
                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userName,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    'Online',
                    style: TextStyle(color: Colors.green, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.black),
            onPressed: () => _startCall(isAudioOnly: false),
          ),
          IconButton(
            icon: const Icon(Icons.call, color: Colors.black),
            onPressed: () => _startCall(isAudioOnly: true),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _refreshMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryColor,
                    ),
                  )
                : _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Start the conversation!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refreshMessages,
                    color: AppColors.primaryColor,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isMe = message['sender']['_id'] != widget.userId;

                        // Show date separator if needed
                        bool showDateSeparator = false;
                        if (index == 0) {
                          showDateSeparator = true;
                        } else {
                          final prevMessage = _messages[index - 1];
                          final prevDate = DateTime.parse(
                            prevMessage['createdAt'],
                          );
                          final currentDate = DateTime.parse(
                            message['createdAt'],
                          );
                          showDateSeparator = !_isSameDay(
                            prevDate,
                            currentDate,
                          );
                        }

                        return Column(
                          children: [
                            if (showDateSeparator)
                              _buildDateSeparator(
                                DateTime.parse(message['createdAt']),
                              ),
                            _buildMessageBubble(message, isMe),
                          ],
                        );
                      },
                    ),
                  ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    String dateText;

    if (_isSameDay(date, now)) {
      dateText = 'Today';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      dateText = 'Yesterday';
    } else {
      dateText = DateFormat('MMM dd, yyyy').format(date);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey[300])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              dateText,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey[300])),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe) {
    final timestamp = DateTime.parse(message['createdAt']);
    final timeStr = DateFormat('HH:mm').format(timestamp);
    final isRead = message['read'] ?? false;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
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
            if (message['attachments'] != null &&
                (message['attachments'] as List).isNotEmpty)
              ...(message['attachments'] as List).map((att) {
                if (att['fileType'] == 'image') {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: InkWell(
                      onTap: () => _openAttachment(att['url']),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          att['url'],
                          width: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: InkWell(
                      onTap: () => _openAttachment(att['url']),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.white24 : Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.insert_drive_file, size: 20),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                att['name'] ?? 'File',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isMe ? Colors.white : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
              }),
            Text(
              message['message'],
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.grey,
                    fontSize: 11,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: isRead ? Colors.blue[200] : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.add_circle_outline,
                color: AppColors.primaryColor,
                size: 28,
              ),
              onPressed: _showAttachmentOptions,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.image_outlined,
                color: AppColors.primaryColor,
                size: 28,
              ),
              onPressed: () => _pickAndSendMessage(ImageSource.gallery),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  focusNode: _messageFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Type a message...'.tr(),
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isSending ? null : _sendMessage,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _isSending ? Colors.grey : AppColors.primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _isSending
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }
}
