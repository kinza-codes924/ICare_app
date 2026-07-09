import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icare/utils/demo_users.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

/// Demo Users Information Screen
///
/// Displays all available demo accounts for testing the system.
/// Users can view credentials and copy them to clipboard.
class DemoUsersScreen extends StatefulWidget {
  const DemoUsersScreen({super.key});

  @override
  State<DemoUsersScreen> createState() => _DemoUsersScreenState();
}

class _DemoUsersScreenState extends State<DemoUsersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _roles = [
    'Patient',
    'Doctor',
    'Laboratory',
    'Pharmacy',
    'Instructor',
    'Student',
    'Admin',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _roles.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Demo User Accounts',
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Gilroy-Bold',
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFF0EA5E9),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Test Accounts Available',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                  fontFamily: 'Gilroy-Bold',
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'All accounts use password: ${DemoUsers.demoPassword}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                  fontFamily: 'Gilroy-Medium',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFF1F5F9)),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: const Color(0xFF0B2D6E),
                  labelColor: const Color(0xFF0B2D6E),
                  unselectedLabelColor: const Color(0xFF64748B),
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.5,
                    fontFamily: 'Gilroy-Bold',
                  ),
                  tabs: _roles.map((role) {
                    final count = DemoUsers.getUsersByRole(role).length;
                    return Tab(text: '$role ($count)');
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 1200 : double.infinity,
          ),
          child: TabBarView(
            controller: _tabController,
            children: _roles.map((role) => _buildUserList(role)).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildUserList(String role) {
    final users = DemoUsers.getUsersByRole(role);

    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No demo users for this role',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontFamily: 'Gilroy-Medium',
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: users.length,
      itemBuilder: (context, index) => _buildUserCard(users[index]),
    );
  }

  Widget _buildUserCard(Map<String, String> user) {
    final role = user['role'] ?? '';
    final color = _getRoleColor(role);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getRoleIcon(role),
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['name'] ?? 'User',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          fontFamily: 'Gilroy-Bold',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user['email'] ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          fontFamily: 'Gilroy-Medium',
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontFamily: 'Gilroy-Bold',
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(Icons.phone_outlined, user['phone'] ?? 'N/A'),
            if (user['specialty'] != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.medical_services_outlined, user['specialty']!),
            ],
            if (user['labName'] != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.science_outlined, user['labName']!),
            ],
            if (user['pharmacyName'] != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.local_pharmacy_outlined, user['pharmacyName']!),
            ],
            if (user['city'] != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.location_on_outlined, user['city']!),
            ],
            if (user['program'] != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.school_outlined, user['program']!),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyEmail(user['email'] ?? ''),
                    icon: const Icon(Icons.email_outlined, size: 16),
                    label: const Text('Copy Email'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: color.withValues(alpha: 0.3)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _copyPassword(),
                    icon: const Icon(Icons.lock_outlined, size: 16),
                    label: const Text('Copy Password'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1E293B),
              fontFamily: 'Gilroy-Medium',
            ),
          ),
        ),
      ],
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'patient':
        return const Color(0xFF0EA5E9);
      case 'doctor':
        return const Color(0xFF10B981);
      case 'laboratory':
        return const Color(0xFF8B5CF6);
      case 'pharmacy':
        return const Color(0xFFF59E0B);
      case 'instructor':
        return const Color(0xFF3B82F6);
      case 'student':
        return const Color(0xFFEC4899);
      case 'admin':
      case 'super admin':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'patient':
        return Icons.person_outline_rounded;
      case 'doctor':
        return Icons.medical_services_outlined;
      case 'laboratory':
        return Icons.science_outlined;
      case 'pharmacy':
        return Icons.local_pharmacy_outlined;
      case 'instructor':
        return Icons.school_outlined;
      case 'student':
        return Icons.menu_book_outlined;
      case 'admin':
      case 'super admin':
        return Icons.admin_panel_settings_outlined;
      default:
        return Icons.person_outline_rounded;
    }
  }

  void _copyEmail(String email) {
    Clipboard.setData(ClipboardData(text: email));
    SmartDialog.showToast('Email copied to clipboard');
  }

  void _copyPassword() {
    Clipboard.setData(ClipboardData(text: DemoUsers.demoPassword));
    SmartDialog.showToast('Password copied to clipboard');
  }
}
