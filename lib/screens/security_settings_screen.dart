import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icare/models/auth_security.dart';
import 'package:icare/utils/theme.dart';
import 'package:intl/intl.dart';

/// Security Settings Screen
///
/// Allows users to manage authentication and security preferences
/// including 2FA, email verification, sessions, and security alerts
class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends ConsumerState<SecuritySettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  SecuritySettings? _securitySettings;
  List<UserSession> _activeSessions = [];
  List<LoginAttempt> _recentLogins = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSecurityData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSecurityData() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));

    // Sample data
    setState(() {
      _securitySettings = SecuritySettings(
        userId: 'current_user',
        twoFactorEnabled: false,
        emailVerified: true,
        loginNotificationsEnabled: true,
        suspiciousActivityAlertsEnabled: true,
        trustedDevices: ['device_001', 'device_002'],
        lastPasswordChange: DateTime.now().subtract(const Duration(days: 45)),
        failedLoginAttempts: 0,
      );
      _activeSessions = _getSampleSessions();
      _recentLogins = _getSampleLoginAttempts();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Security Settings',
              style: TextStyle(
                fontSize: 20,
                fontFamily: 'Gilroy-Bold',
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Manage your account security',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primaryColor,
              labelColor: AppColors.primaryColor,
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, fontFamily: 'Gilroy-Bold'),
              tabs: const [
                Tab(text: 'SECURITY'),
                Tab(text: 'SESSIONS'),
                Tab(text: 'ACTIVITY'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSecurityTab(),
                _buildSessionsTab(),
                _buildActivityTab(),
              ],
            ),
    );
  }

  Widget _buildSecurityTab() {
    if (_securitySettings == null) return const SizedBox();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSecurityStatusCard(),
        const SizedBox(height: 24),
        const Text(
          'Authentication',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            fontFamily: 'Gilroy-Bold',
          ),
        ),
        const SizedBox(height: 16),
        _buildEmailVerificationCard(),
        _buildTwoFactorAuthCard(),
        _buildPasswordCard(),
        const SizedBox(height: 24),
        const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            fontFamily: 'Gilroy-Bold',
          ),
        ),
        const SizedBox(height: 16),
        _buildNotificationSettingCard(
          'Login Notifications',
          'Get notified when someone logs into your account',
          _securitySettings!.loginNotificationsEnabled,
          (value) => _toggleLoginNotifications(value),
        ),
        _buildNotificationSettingCard(
          'Suspicious Activity Alerts',
          'Get alerts for unusual account activity',
          _securitySettings!.suspiciousActivityAlertsEnabled,
          (value) => _toggleSuspiciousActivityAlerts(value),
        ),
      ],
    );
  }

  Widget _buildSessionsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF166534)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${_activeSessions.length} active session${_activeSessions.length != 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF166534),
                    fontFamily: 'Gilroy-Medium',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Active Sessions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            fontFamily: 'Gilroy-Bold',
          ),
        ),
        const SizedBox(height: 16),
        ..._activeSessions.map((session) => _buildSessionCard(session)),
      ],
    );
  }

  Widget _buildActivityTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Recent Login Activity',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            fontFamily: 'Gilroy-Bold',
          ),
        ),
        const SizedBox(height: 16),
        ..._recentLogins.map((attempt) => _buildLoginAttemptCard(attempt)),
      ],
    );
  }

  Widget _buildSecurityStatusCard() {
    if (_securitySettings == null) return const SizedBox();

    final securityScore = _calculateSecurityScore();
    final Color scoreColor = securityScore >= 80
        ? const Color(0xFF10B981)
        : securityScore >= 50
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scoreColor, scoreColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Security Score',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
              fontFamily: 'Gilroy-Medium',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$securityScore',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  fontFamily: 'Gilroy-Bold',
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 12, left: 4),
                child: Text(
                  '/100',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _getSecurityScoreLabel(securityScore),
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailVerificationCard() {
    if (_securitySettings == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _securitySettings!.emailVerified ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _securitySettings!.emailVerified
                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _securitySettings!.emailVerified ? Icons.verified : Icons.warning,
              color: _securitySettings!.emailVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Email Verification',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _securitySettings!.emailVerified ? 'Email verified' : 'Email not verified',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          if (!_securitySettings!.emailVerified)
            TextButton(
              onPressed: _verifyEmail,
              child: const Text('Verify'),
            ),
        ],
      ),
    );
  }

  Widget _buildTwoFactorAuthCard() {
    if (_securitySettings == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _securitySettings!.twoFactorEnabled
                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.security,
              color: _securitySettings!.twoFactorEnabled ? const Color(0xFF10B981) : const Color(0xFF64748B),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Two-Factor Authentication',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _securitySettings!.twoFactorEnabled ? 'Enabled' : 'Not enabled',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _setup2FA,
            child: Text(_securitySettings!.twoFactorEnabled ? 'Manage' : 'Enable'),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordCard() {
    if (_securitySettings == null) return const SizedBox();

    final daysSinceChange = _securitySettings!.lastPasswordChange != null
        ? DateTime.now().difference(_securitySettings!.lastPasswordChange!).inDays
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lock, color: Color(0xFF3B82F6), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  daysSinceChange != null ? 'Changed $daysSinceChange days ago' : 'Never changed',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _changePassword,
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSettingCard(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(UserSession session) {
    IconData deviceIcon;
    switch (session.deviceType) {
      case 'mobile':
        deviceIcon = Icons.phone_android;
        break;
      case 'tablet':
        deviceIcon = Icons.tablet;
        break;
      default:
        deviceIcon = Icons.computer;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: session.isCurrentSession ? AppColors.primaryColor.withValues(alpha: 0.3) : const Color(0xFFF1F5F9),
          width: session.isCurrentSession ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(deviceIcon, color: AppColors.primaryColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          session.deviceName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (session.isCurrentSession) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Current',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      session.ipAddress,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              if (!session.isCurrentSession)
                IconButton(
                  onPressed: () => _revokeSession(session),
                  icon: const Icon(Icons.close, size: 20),
                  color: const Color(0xFFEF4444),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                'Last active ${DateFormat('MMM dd, yyyy • hh:mm a').format(session.lastActivityAt)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoginAttemptCard(LoginAttempt attempt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: attempt.successful ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            attempt.successful ? Icons.check_circle : Icons.error,
            color: attempt.successful ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attempt.successful ? 'Successful login' : 'Failed login attempt',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${attempt.ipAddress} • ${attempt.deviceType}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                if (!attempt.successful && attempt.failureReason != null)
                  Text(
                    attempt.failureReason!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFEF4444),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            DateFormat('MMM dd\nhh:mm a').format(attempt.attemptedAt),
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  int _calculateSecurityScore() {
    if (_securitySettings == null) return 0;

    int score = 0;

    // Email verified: 30 points
    if (_securitySettings!.emailVerified) score += 30;

    // 2FA enabled: 40 points
    if (_securitySettings!.twoFactorEnabled) score += 40;

    // Recent password change: 20 points
    if (_securitySettings!.lastPasswordChange != null) {
      final daysSinceChange = DateTime.now().difference(_securitySettings!.lastPasswordChange!).inDays;
      if (daysSinceChange < 90) score += 20;
    }

    // Notifications enabled: 10 points
    if (_securitySettings!.loginNotificationsEnabled && _securitySettings!.suspiciousActivityAlertsEnabled) {
      score += 10;
    }

    return score;
  }

  String _getSecurityScoreLabel(int score) {
    if (score >= 80) return 'Excellent security';
    if (score >= 50) return 'Good security';
    return 'Needs improvement';
  }

  List<UserSession> _getSampleSessions() {
    return [
      UserSession(
        id: 'session_001',
        userId: 'current_user',
        deviceName: 'Windows PC',
        deviceType: 'desktop',
        ipAddress: '192.168.1.100',
        userAgent: 'Mozilla/5.0...',
        status: SessionStatus.active,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        lastActivityAt: DateTime.now(),
      ),
      UserSession(
        id: 'session_002',
        userId: 'current_user',
        deviceName: 'iPhone 13',
        deviceType: 'mobile',
        ipAddress: '192.168.1.101',
        userAgent: 'Mobile Safari...',
        status: SessionStatus.active,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        lastActivityAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
    ];
  }

  List<LoginAttempt> _getSampleLoginAttempts() {
    return [
      LoginAttempt(
        id: 'attempt_001',
        userId: 'current_user',
        email: 'user@email.com',
        successful: true,
        ipAddress: '192.168.1.100',
        deviceType: 'desktop',
        userAgent: 'Mozilla/5.0...',
        attemptedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      LoginAttempt(
        id: 'attempt_002',
        email: 'user@email.com',
        successful: false,
        ipAddress: '203.0.113.45',
        deviceType: 'mobile',
        userAgent: 'Unknown',
        failureReason: 'Invalid password',
        attemptedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      LoginAttempt(
        id: 'attempt_003',
        userId: 'current_user',
        email: 'user@email.com',
        successful: true,
        ipAddress: '192.168.1.101',
        deviceType: 'mobile',
        userAgent: 'Mobile Safari...',
        attemptedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
  }

  void _verifyEmail() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verification email sent')),
    );
  }

  void _setup2FA() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('2FA setup dialog')),
    );
  }

  void _changePassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Change password dialog')),
    );
  }

  void _toggleLoginNotifications(bool value) {
    setState(() {
      _securitySettings = SecuritySettings(
        userId: _securitySettings!.userId,
        twoFactorEnabled: _securitySettings!.twoFactorEnabled,
        twoFactorMethod: _securitySettings!.twoFactorMethod,
        emailVerified: _securitySettings!.emailVerified,
        loginNotificationsEnabled: value,
        suspiciousActivityAlertsEnabled: _securitySettings!.suspiciousActivityAlertsEnabled,
        trustedDevices: _securitySettings!.trustedDevices,
        lastPasswordChange: _securitySettings!.lastPasswordChange,
        failedLoginAttempts: _securitySettings!.failedLoginAttempts,
        accountLockedUntil: _securitySettings!.accountLockedUntil,
      );
    });
  }

  void _toggleSuspiciousActivityAlerts(bool value) {
    setState(() {
      _securitySettings = SecuritySettings(
        userId: _securitySettings!.userId,
        twoFactorEnabled: _securitySettings!.twoFactorEnabled,
        twoFactorMethod: _securitySettings!.twoFactorMethod,
        emailVerified: _securitySettings!.emailVerified,
        loginNotificationsEnabled: _securitySettings!.loginNotificationsEnabled,
        suspiciousActivityAlertsEnabled: value,
        trustedDevices: _securitySettings!.trustedDevices,
        lastPasswordChange: _securitySettings!.lastPasswordChange,
        failedLoginAttempts: _securitySettings!.failedLoginAttempts,
        accountLockedUntil: _securitySettings!.accountLockedUntil,
      );
    });
  }

  void _revokeSession(UserSession session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke Session'),
        content: Text('Are you sure you want to revoke the session on ${session.deviceName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _activeSessions.removeWhere((s) => s.id == session.id);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Session revoked'),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
  }
}
