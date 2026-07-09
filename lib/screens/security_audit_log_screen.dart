import 'package:flutter/material.dart';
import 'package:icare/services/security_service.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';

class SecurityAuditLogScreen extends StatefulWidget {
  const SecurityAuditLogScreen({super.key});

  @override
  State<SecurityAuditLogScreen> createState() => _SecurityAuditLogScreenState();
}

class _SecurityAuditLogScreenState extends State<SecurityAuditLogScreen> {
  final SecurityService _securityService = SecurityService();
  bool _isLoading = true;
  List<dynamic> _logs = [];

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await _securityService.getSecurityLogs();
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: const Text('Unable to load data. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: const Text(
          'Security Audit Logs',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
          ? _buildEmptyState()
          : _buildLogsList(),
    );
  }

  Widget _buildEmptyState() {
    return const Center(child: Text('No security events recorded yet.'));
  }

  Widget _buildLogsList() {
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _logs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final log = _logs[index];
        final timestamp = DateTime.parse(
          log['timestamp'] ?? DateTime.now().toIso8601String(),
        );

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLogIcon(log['type']),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log['message'] ?? 'Security Event',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'User: ${log['userName']} (${log['role']})',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'IP: ${log['ipAddress']}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                DateFormat('HH:mm').format(timestamp),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogIcon(String? type) {
    IconData icon;
    Color color;
    switch (type) {
      case 'login':
        icon = Icons.login_rounded;
        color = Colors.blue;
        break;
      case 'failed_login':
        icon = Icons.error_outline_rounded;
        color = Colors.red;
        break;
      case 'data_access':
        icon = Icons.health_and_safety_rounded;
        color = Colors.green;
        break;
      case 'password_change':
        icon = Icons.lock_reset_rounded;
        color = Colors.orange;
        break;
      default:
        icon = Icons.info_outline_rounded;
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
