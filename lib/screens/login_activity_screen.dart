import 'package:flutter/material.dart';
import 'package:icare/services/security_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';

class LoginActivityScreen extends StatefulWidget {
  const LoginActivityScreen({super.key});

  @override
  State<LoginActivityScreen> createState() => _LoginActivityScreenState();
}

class _LoginActivityScreenState extends State<LoginActivityScreen> {
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

  Future<void> _revoke(String sessionId) async {
    await _securityService.revokeSession(sessionId);
    if (mounted) {
      setState(() => _sessions.removeWhere((s) => (s['_id'] ?? s['id'] ?? '') == sessionId));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session revoked'), backgroundColor: Colors.orange));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: const Text('Login Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)), onPressed: _loadActivity),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadActivity,
              child: _sessions.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: EdgeInsets.all(isWide ? 32 : 16),
                      itemCount: _sessions.length,
                      itemBuilder: (_, i) => _buildSessionCard(_sessions[i], i == 0),
                    ),
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.devices_rounded, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        const Text('No login activity found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        const SizedBox(height: 8),
        const Text('Your login sessions will appear here', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
      ]),
    );
  }

  Widget _buildSessionCard(dynamic session, bool isCurrent) {
    final id = (session['_id'] ?? session['id'] ?? '').toString();
    final device = (session['device'] ?? session['userAgent'] ?? session['browser'] ?? 'Unknown Device').toString();
    final ip = (session['ipAddress'] ?? session['ip'] ?? 'Unknown IP').toString();
    final locationStr = [session['city'], session['country']].where((v) => v != null && v.toString().isNotEmpty).join(', ');
    final dateStr = session['createdAt'] ?? session['loginAt'] ?? session['timestamp'] ?? '';
    String formattedDate = '';
    try {
      if (dateStr.toString().isNotEmpty) {
        formattedDate = DateFormat('MMM d, yyyy • h:mm a').format(DateTime.parse(dateStr.toString()).toLocal());
      }
    } catch (_) {}

    final bool isActive = session['isActive'] == true || isCurrent;

    // Detect platform icon
    IconData icon = Icons.computer_rounded;
    final deviceLower = device.toLowerCase();
    if (deviceLower.contains('mobile') || deviceLower.contains('android') || deviceLower.contains('iphone')) {
      icon = Icons.smartphone_rounded;
    } else if (deviceLower.contains('tablet') || deviceLower.contains('ipad')) {
      icon = Icons.tablet_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isActive && isCurrent ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: isCurrent ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: isCurrent ? Colors.green : const Color(0xFF64748B), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(device, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(20)),
                    child: const Text('Current', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                  ),
              ]),
              const SizedBox(height: 4),
              if (ip.isNotEmpty && ip != 'Unknown IP')
                Text('IP: $ip', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              if (locationStr.isNotEmpty)
                Text(locationStr, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              if (formattedDate.isNotEmpty)
                Text(formattedDate, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ]),
          ),
          if (!isCurrent && id.isNotEmpty)
            TextButton(
              onPressed: () => _confirmRevoke(id),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
              child: const Text('Revoke', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  void _confirmRevoke(String sessionId) {
    showDialog(context: context, builder: (dc) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Revoke Session?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      content: const Text('This device will be signed out immediately.', style: TextStyle(fontSize: 14, color: Color(0xFF475569))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () { Navigator.pop(dc); _revoke(sessionId); },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('Revoke'),
        ),
      ],
    ));
  }
}
