import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/services/security_service.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';

class LoginActivityScreen extends ConsumerStatefulWidget {
  const LoginActivityScreen({super.key});

  @override
  ConsumerState<LoginActivityScreen> createState() => _LoginActivityScreenState();
}

class _LoginActivityScreenState extends ConsumerState<LoginActivityScreen> {
  final SecurityService _securityService = SecurityService();
  List<dynamic> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    setState(() => _loading = true);
    final data = await _securityService.getLoginActivity();
    if (mounted) setState(() { _sessions = data; _loading = false; });
  }

  String _dateLabel(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final d = DateTime(dt.year, dt.month, dt.day);
      if (d == today) return 'Today';
      if (d == yesterday) return 'Yesterday';
      return DateFormat('MMMM d, yyyy').format(dt);
    } catch (_) {
      return 'Unknown Date';
    }
  }

  String _timeLabel(String dateStr) {
    try {
      return DateFormat('h:mm a').format(DateTime.parse(dateStr).toLocal());
    } catch (_) {
      return '';
    }
  }

  Map<String, List<dynamic>> _groupByDate() {
    final Map<String, List<dynamic>> grouped = {};
    for (final s in _sessions) {
      final dateStr = (s['createdAt'] ?? s['loginAt'] ?? s['timestamp'] ?? '').toString();
      final label = dateStr.isNotEmpty ? _dateLabel(dateStr) : 'Unknown Date';
      grouped.putIfAbsent(label, () => []).add(s);
    }
    return grouped;
  }

  IconData _deviceIcon(String device) {
    final d = device.toLowerCase();
    if (d.contains('mobile') || d.contains('android') || d.contains('iphone')) return Icons.smartphone_rounded;
    if (d.contains('tablet') || d.contains('ipad')) return Icons.tablet_rounded;
    return Icons.laptop_rounded;
  }

  bool _isLogout(dynamic session) {
    final action = (session['action'] ?? session['type'] ?? '').toString().toLowerCase();
    return action.contains('logout') || action.contains('log out') || action.contains('sign out');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final userName = auth.user?.name ?? 'You';
    final profilePic = auth.user?.profilePicture;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: const Text('Login Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1C1E21))),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Color(0xFF65676B)), onPressed: _loadActivity),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadActivity,
              child: _sessions.isEmpty
                  ? _buildEmpty()
                  : _buildList(userName, profilePic),
            ),
    );
  }

  Widget _buildList(String userName, String? profilePic) {
    final grouped = _groupByDate();
    final dateKeys = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: dateKeys.length,
      itemBuilder: (_, i) {
        final dateLabel = dateKeys[i];
        final entries = grouped[dateLabel]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(dateLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1C1E21))),
            ),
            Container(
              color: Colors.white,
              child: Column(
                children: List.generate(entries.length, (j) {
                  final session = entries[j];
                  final isLast = j == entries.length - 1;
                  return Column(
                    children: [
                      _buildRow(session, userName, profilePic),
                      if (!isLast) const Divider(height: 1, indent: 72, endIndent: 0, color: Color(0xFFE4E6EA)),
                    ],
                  );
                }),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRow(dynamic session, String userName, String? profilePic) {
    final device = (session['device'] ?? session['userAgent'] ?? session['browser'] ?? 'Unknown Device').toString();
    final ip = (session['ipAddress'] ?? session['ip'] ?? '').toString();
    final dateStr = (session['createdAt'] ?? session['loginAt'] ?? session['timestamp'] ?? '').toString();
    final timeStr = dateStr.isNotEmpty ? _timeLabel(dateStr) : '';
    final logout = _isLogout(session);
    final deviceIcon = _deviceIcon(device);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar with device badge
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF1877F2),
                  backgroundImage: (profilePic != null && profilePic.isNotEmpty)
                      ? NetworkImage(profilePic)
                      : null,
                  child: (profilePic == null || profilePic.isEmpty)
                      ? Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                        )
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Icon(deviceIcon, size: 12, color: const Color(0xFF65676B)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 14, color: Color(0xFF1C1E21), height: 1.4),
                    children: [
                      TextSpan(text: userName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(
                        text: logout ? ' logged out of iCare' : ' logged in to iCare',
                        style: const TextStyle(fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                if (ip.isNotEmpty)
                  Text('IP address $ip', style: const TextStyle(fontSize: 12, color: Color(0xFF65676B))),
                if (timeStr.isNotEmpty)
                  Text(timeStr, style: const TextStyle(fontSize: 12, color: Color(0xFF65676B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.devices_rounded, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        const Text('No login activity found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF65676B))),
        const SizedBox(height: 8),
        const Text('Your login sessions will appear here', style: TextStyle(fontSize: 13, color: Color(0xFF8A8D91))),
      ]),
    );
  }
}
