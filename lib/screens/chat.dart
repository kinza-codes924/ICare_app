import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/models/chat.dart';
import 'package:icare/screens/video_call.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/custom_text_input.dart';
import 'package:icare/widgets/svg_wrapper.dart';

class ChatScreen extends StatefulWidget {
  final String? title;
  const ChatScreen({super.key, this.title});

  @override
  BasicState createState() => BasicState();
}

class BasicState extends State<ChatScreen> {
  var textMessage = '';

  List<Chat> messages = [
    Chat(
      isMe: false,
      text:
          "Lorem ipsum dolor sit amet consectetur adipiscing elit maecenas porta fermentum, ",
      photo: ImagePaths.user1,
    ),
    Chat(
      isMe: false,
      text:
          "Lorem ipsum dolor sit amet consectetur adipiscing elit maecenas porta fermentum, ",
      photo: ImagePaths.user1,
    ),
    Chat(
      isMe: false,
      text:
          "Lorem ipsum dolor sit amet consectetur adipiscing elit maecenas porta fermentum, ",
      photo: ImagePaths.user1,
    ),
    Chat(
      isMe: true,
      text:
          "Lorem ipsum dolor sit amet consectetur adipiscing elit maecenas porta fermentum, ",
      photo: ImagePaths.user5,
    ),
    Chat(
      isMe: true,
      text:
          "Lorem ipsum dolor sit amet consectetur adipiscing elit maecenas porta fermentum, ",
      photo: ImagePaths.user5,
    ),
    Chat(
      isMe: true,
      text:
          "Lorem ipsum dolor sit amet consectetur adipiscing elit maecenas porta fermentum, ",
      photo: ImagePaths.user5,
    ),
    Chat(
      isMe: true,
      text:
          "Lorem ipsum dolor sit amet consectetur adipiscing elit maecenas porta fermentum, ",
      photo: ImagePaths.user5,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width > 900) {
      return _WebChatScreen(initialContactName: widget.title);
    }
    return Scaffold(
      appBar: AppBar(
        leading: CustomBackButton(),
        automaticallyImplyLeading: false,
        title: CustomText(
          text: widget.title ?? "Chat",
          fontSize: 16.78,
          fontFamily: "Gilroy-Bold",
          fontWeight: FontWeight.w400,
          color: AppColors.primary500,
        ),
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => VideoCall(
                    channelName: 'call_${widget.title ?? 'general'}',
                    remoteUserName: widget.title ?? 'User',
                    isAudioOnly: false,
                  ),
                ),
              );
            },
            child: SvgWrapper(assetPath: ImagePaths.video),
          ),
          SizedBox(width: ScallingConfig.scale(10)),
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => VideoCall(
                    channelName: 'call_${widget.title ?? 'general'}',
                    remoteUserName: widget.title ?? 'User',
                    isAudioOnly: true,
                  ),
                ),
              );
            },
            child: SvgWrapper(assetPath: ImagePaths.audio),
          ),
          SizedBox(width: ScallingConfig.scale(10)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              padding: EdgeInsets.symmetric(
                horizontal: ScallingConfig.scale(4),
              ),
              itemBuilder: (ctx, i) {
                return MessageBubble(
                  isMe: messages[i].isMe,
                  text: messages[i].text,
                  photo: messages[i].photo!,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: CustomInputField(
                    borderColor: AppColors.darkGreyColor.withAlpha(40),
                    borderWidth: 1,
                    onChanged: (value) {
                      setState(() {
                        textMessage = value;
                      });
                    },
                    hintText: "Write A Message",
                  ),
                ),
                SizedBox(width: ScallingConfig.scale(20)),
                InkWell(
                  onTap: () {
                    setState(() {
                      messages.add(
                        Chat(
                          text: textMessage,
                          isMe: true,
                          photo: ImagePaths.user5,
                        ),
                      );
                    });
                    textMessage = '';
                  },
                  child: CircleAvatar(
                    radius: 25,
                    backgroundColor: AppColors.primaryColor,
                    child: SvgWrapper(assetPath: ImagePaths.send),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PREMIUM WEB CHAT SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class _WebChatScreen extends StatefulWidget {
  final String? initialContactName;
  const _WebChatScreen({this.initialContactName});

  @override
  State<_WebChatScreen> createState() => _WebChatScreenState();
}

class _WebChatScreenState extends State<_WebChatScreen> {
  int _selectedContactIndex = 0;
  final TextEditingController _messageController = TextEditingController();

  static final List<Map<String, dynamic>> _contacts = [
    {
      "name": "Dr. Aron Smith",
      "specialty": "Cardiologist",
      "image": ImagePaths.user1,
      "lastMessage": "Your reports look normal. Keep it up!",
      "time": "10:30 AM",
      "unread": 2,
      "online": true,
    },
    {
      "name": "Emily Jordan",
      "specialty": "Patient",
      "image": ImagePaths.user10,
      "lastMessage": "Thank you doctor, I feel better now.",
      "time": "Yesterday",
      "unread": 0,
      "online": false,
    },
    {
      "name": "Dr. Sarah Chen",
      "specialty": "Dermatologist",
      "image": ImagePaths.user11,
      "lastMessage": "Please apply the cream twice daily.",
      "time": "2 days ago",
      "unread": 0,
      "online": true,
    },
    {
      "name": "James Wilson",
      "specialty": "Patient",
      "image": ImagePaths.user12,
      "lastMessage": "When can I expect my lab results?",
      "time": "Monday",
      "unread": 1,
      "online": false,
    },
    {
      "name": "Emma Thompson",
      "specialty": "Nurse",
      "image": ImagePaths.user13,
      "lastMessage": "The patient in Room 302 is stable.",
      "time": "5:15 PM",
      "unread": 0,
      "online": true,
    },
  ];

  final List<Chat> _activeMessages = [
    Chat(
      isMe: false,
      text: "Hello! How are you feeling today?",
      photo: ImagePaths.user1,
    ),
    Chat(
      isMe: true,
      text: "I'm feeling much better, thank you doctor.",
      photo: ImagePaths.user5,
    ),
    Chat(
      isMe: false,
      text: "That's great to hear. Any pain in the chest area?",
      photo: ImagePaths.user1,
    ),
    Chat(
      isMe: true,
      text: "No pain as of this morning.",
      photo: ImagePaths.user5,
    ),
    Chat(
      isMe: false,
      text:
          "Excellent. Your last blood test reports look very promising. We can reduce the medication dosage slowly.",
      photo: ImagePaths.user1,
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialContactName != null) {
      for (int i = 0; i < _contacts.length; i++) {
        if (_contacts[i]["name"].toString().toLowerCase().contains(
          widget.initialContactName!.toLowerCase(),
        )) {
          _selectedContactIndex = i;
          break;
        }
      }
    }
  }

  void _sendMessage() {
    if (_messageController.text.isNotEmpty) {
      setState(() {
        _activeMessages.add(
          Chat(
            text: _messageController.text,
            isMe: true,
            photo: ImagePaths.user5,
          ),
        );
        _messageController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Row(
        children: [
          // ── Left: Contacts Sidebar (400px) ──
          Container(
            width: 400,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                right: BorderSide(color: Color(0xFFF1F4F9), width: 1.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sidebar Header
                Padding(
                  padding: const EdgeInsets.only(
                    left: 32,
                    right: 32,
                    top: 40,
                    bottom: 24,
                  ),
                  child: Row(
                    children: [
                      const Text(
                        "Messages",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                          fontFamily: "Gilroy-Bold",
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.edit_note_rounded,
                          color: AppColors.primaryColor,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search contacts or messages...",
                      hintStyle: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF94A3B8),
                        size: 18,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Contact List
                Expanded(
                  child: ListView.builder(
                    itemCount: _contacts.length,
                    itemBuilder: (context, index) {
                      final contact = _contacts[index];
                      final isSelected = _selectedContactIndex == index;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () =>
                                setState(() => _selectedContactIndex = index),
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primaryColor.withValues(alpha: 0.05)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 28,
                                        backgroundImage: AssetImage(
                                          contact["image"],
                                        ),
                                      ),
                                      if (contact["online"])
                                        Positioned(
                                          right: 2,
                                          bottom: 2,
                                          child: Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF22C55E),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              contact["name"],
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: isSelected
                                                    ? FontWeight.w700
                                                    : FontWeight.w600,
                                                color: const Color(0xFF1E293B),
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              contact["time"],
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF94A3B8),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                contact["lastMessage"],
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: contact["unread"] > 0
                                                      ? const Color(0xFF1E293B)
                                                      : const Color(0xFF64748B),
                                                  fontWeight:
                                                      contact["unread"] > 0
                                                      ? FontWeight.w600
                                                      : FontWeight.w400,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (contact["unread"] > 0)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                  left: 8,
                                                ),
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryColor,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Text(
                                                  contact["unread"].toString(),
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── Right: Conversation Area ──
          Expanded(
            child: Container(
              color: const Color(0xFFF8FAFC),
              child: Column(
                children: [
                  // Conversation Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 24,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(
                          color: Color(0xFFF1F4F9),
                          width: 1.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: AssetImage(
                            _contacts[_selectedContactIndex]["image"],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _contacts[_selectedContactIndex]["name"],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color:
                                        _contacts[_selectedContactIndex]["online"]
                                        ? const Color(0xFF22C55E)
                                        : const Color(0xFFCBD5E1),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _contacts[_selectedContactIndex]["online"]
                                      ? "Online"
                                      : "Away",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        _buildHeaderIconButton(Icons.videocam_rounded),
                        const SizedBox(width: 12),
                        _buildHeaderIconButton(Icons.call_rounded),
                        const SizedBox(width: 12),
                        _buildHeaderIconButton(Icons.info_outline_rounded),
                      ],
                    ),
                  ),

                  // Messages Area
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(40),
                      itemCount: _activeMessages.length,
                      itemBuilder: (context, index) {
                        final msg = _activeMessages[index];
                        return _WebMessageBubble(message: msg);
                      },
                    ),
                  ),

                  // Input Area
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 32,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: Color(0xFFF1F4F9), width: 1.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildInputIconButton(Icons.add_circle_outline_rounded),
                        const SizedBox(width: 16),
                        _buildInputIconButton(Icons.image_outlined),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: TextField(
                              controller: _messageController,
                              onSubmitted: (_) => _sendMessage(),
                              decoration: const InputDecoration(
                                hintText: "Type a message...",
                                hintStyle: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 14,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Material(
                          color: AppColors.primaryColor,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: _sendMessage,
                            borderRadius: BorderRadius.circular(14),
                            child: const Padding(
                              padding: EdgeInsets.all(16),
                              child: Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildHeaderIconButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Icon(icon, color: const Color(0xFF64748B), size: 20),
    );
  }

  Widget _buildInputIconButton(IconData icon) {
    return Icon(icon, color: const Color(0xFF94A3B8), size: 24);
  }
}

class _WebMessageBubble extends StatelessWidget {
  final Chat message;
  const _WebMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final bool isMe = message.isMe;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 18,
              backgroundImage: AssetImage(message.photo!),
            ),
            const SizedBox(width: 12),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.primaryColor : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF000000).withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: isMe
                        ? null
                        : Border.all(color: const Color(0xFFF1F4F9), width: 1),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 15,
                      color: isMe ? Colors.white : const Color(0xFF1E293B),
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "10:45 AM",
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 18,
              backgroundImage: AssetImage(message.photo!),
            ),
          ],
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.photo,
    required this.text,
    this.isMe = false,
  });
  final bool isMe;
  final String text;
  final String photo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 10,
        vertical: ScallingConfig.verticalScale(5),
      ),
      child: Stack(
        children: [
          Positioned(
            top: ScallingConfig.scale(0),
            right: isMe ? ScallingConfig.scale(0) : null,
            child: CircleAvatar(
              maxRadius: 35,
              backgroundImage: AssetImage(photo),
            ),
          ),
          Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              SizedBox(width: ScallingConfig.scale(isMe ? 0 : 70)),
              Container(
                width: Utils.windowWidth(context) * 0.65,
                height: Utils.windowHeight(context) * 0.1,
                padding: const EdgeInsets.only(left: 6, top: 12, bottom: 12),
                decoration: BoxDecoration(
                  color: isMe
                      ? AppColors.secondaryColor
                      : AppColors.veryLightGrey,
                  borderRadius: isMe
                      ? const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        )
                      : BorderRadius.circular(20),
                ),
                child: CustomText(
                  text: text,
                  width: Utils.windowWidth(context) * 0.5,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  fontSize: 14,
                  maxLines: 5,
                  color: AppColors.primary500,
                ),
              ),
              SizedBox(width: ScallingConfig.scale(isMe ? 70 : 0)),
            ],
          ),
        ],
      ),
    );
  }
}
