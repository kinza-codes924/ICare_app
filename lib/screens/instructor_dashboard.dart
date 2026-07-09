import 'package:flutter/material.dart';
import 'package:icare/screens/instructor_analytics.dart';
import 'package:icare/screens/instructor_assign_course_screen.dart';
import 'package:icare/screens/instructor_courses_management.dart';
import 'package:icare/screens/instructor_learners_screen.dart';
import 'package:icare/screens/instructor_lms_screen.dart';
import 'package:icare/screens/instructor_precautions_management.dart';
import 'package:icare/screens/instructor_profile_setup.dart';
import 'package:icare/services/instructor_service.dart';
import 'package:icare/widgets/instructor_sidebar.dart';

class InstructorDashboardScreen extends StatefulWidget {
  const InstructorDashboardScreen({super.key});

  @override
  State<InstructorDashboardScreen> createState() =>
      _InstructorDashboardScreenState();
}

class _InstructorDashboardScreenState extends State<InstructorDashboardScreen> {
  final InstructorService _instructorService = InstructorService();
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _instructorService.getStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Color(0xFF0F172A)),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Program Manager Dashboard',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: Color(0xFF0F172A)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => const InstructorProfileSetupScreen(),
                ),
              );
            },
          ),
        ],
      ),
      drawer: const InstructorSidebar(currentRoute: 'dashboard'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(isDesktop ? 32 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats — horizontal row of compact cards
                    if (isDesktop)
                      Row(
                        children: [
                          _buildStatCard('Total Programs', '${_stats['totalCourses'] ?? 0}', Icons.menu_book_rounded, const Color(0xFF6366F1)),
                          const SizedBox(width: 16),
                          _buildStatCard('Active Patients', '${_stats['totalStudents'] ?? 0}', Icons.group_rounded, const Color(0xFF10B981)),
                          const SizedBox(width: 16),
                          _buildStatCard('Avg. Rating', '${_stats['avgRating'] ?? 0}★', Icons.star_rounded, const Color(0xFFF59E0B)),
                          const SizedBox(width: 16),
                          _buildStatCard('Health Tips', '${_stats['totalPrecautions'] ?? 0}', Icons.health_and_safety_rounded, const Color(0xFF3B82F6)),
                        ],
                      )
                    else
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.8,
                        children: [
                          _buildStatCard('Total Programs', '${_stats['totalCourses'] ?? 0}', Icons.menu_book_rounded, const Color(0xFF6366F1)),
                          _buildStatCard('Active Patients', '${_stats['totalStudents'] ?? 0}', Icons.group_rounded, const Color(0xFF10B981)),
                          _buildStatCard('Avg. Rating', '${_stats['avgRating'] ?? 0}★', Icons.star_rounded, const Color(0xFFF59E0B)),
                          _buildStatCard('Health Tips', '${_stats['totalPrecautions'] ?? 0}', Icons.health_and_safety_rounded, const Color(0xFF3B82F6)),
                        ],
                      ),

                    const SizedBox(height: 20),
                    // Quick Actions — list style with description + arrow
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildQuickActionList(context),
                    const SizedBox(height: 20),
                    // Navigation hint for mobile (sidebar is a drawer)
                    if (!isDesktop)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.menu_rounded, color: Color(0xFF3B82F6), size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Tap the menu icon (☰) at the top left to navigate to Programs, Learners, Analytics and more.',
                                style: TextStyle(color: Color(0xFF1E40AF), fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: isDesktop ? 26 : 20,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                label,
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
    );

    return isDesktop ? Expanded(child: card) : card;
  }

  Widget _buildQuickActionList(BuildContext context) {
    final actions = [
      _QAction('LMS Classroom', 'Open your courses — stream, assignments, grades', Icons.school_rounded, const Color(0xFF4F46E5), const InstructorLmsScreen()),
      _QAction('Manage Health Programs', 'Create, edit, and manage your health programs', Icons.health_and_safety_rounded, const Color(0xFF6366F1), const InstructorCoursesManagementScreen()),
      _QAction('Assign Programs', 'Assign professional development to doctors or patients', Icons.assignment_ind_rounded, const Color(0xFFF59E0B), const InstructorAssignCourseScreen()),
      _QAction('Assigned Learners', 'Monitor patient and doctor progress', Icons.group_rounded, const Color(0xFF3B82F6), const InstructorLearnersScreen()),
      _QAction('Educational Analytics', 'Track completions and learner engagement', Icons.analytics_rounded, const Color(0xFFEF4444), const InstructorAnalytics()),
      _QAction('Health Tips & Precautions', 'Share health tips with your patients', Icons.tips_and_updates_rounded, const Color(0xFF10B981), const InstructorPrecautionsManagementScreen()),
      _QAction('Profile Settings', 'Update your profile and availability', Icons.settings_rounded, const Color(0xFF64748B), const InstructorProfileSetupScreen()),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: actions.asMap().entries.map((entry) {
          final i = entry.key;
          final a = entry.value;
          return Column(
            children: [
              InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => a.screen),
                ),
                borderRadius: BorderRadius.vertical(
                  top: i == 0 ? const Radius.circular(16) : Radius.zero,
                  bottom: i == actions.length - 1 ? const Radius.circular(16) : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: a.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(a.icon, color: a.color, size: 22),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              a.subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 22),
                    ],
                  ),
                ),
              ),
              if (i < actions.length - 1)
                const Divider(height: 1, indent: 80, color: Color(0xFFF1F5F9)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    Widget screen,
  ) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (ctx) => screen),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _QAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget screen;
  const _QAction(this.title, this.subtitle, this.icon, this.color, this.screen);
}
