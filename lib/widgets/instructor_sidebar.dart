import 'package:flutter/material.dart';
import 'package:icare/screens/instructor_dashboard.dart';
import 'package:icare/screens/instructor_courses_management.dart';
import 'package:icare/screens/instructor_assign_course_screen.dart';
import 'package:icare/screens/instructor_create_course.dart';
import 'package:icare/screens/instructor_learners_screen.dart';
import 'package:icare/screens/instructor_analytics.dart';
import 'package:icare/screens/instructor_precautions_management.dart';
import 'package:icare/screens/instructor_profile_setup.dart';
import 'package:icare/screens/instructor_lms_dashboard.dart';
import 'package:icare/screens/instructor_lms_courses.dart';
import 'package:icare/screens/instructor_lms_create_course.dart';
import 'package:icare/utils/theme.dart';

class InstructorSidebar extends StatelessWidget {
  final String currentRoute;

  const InstructorSidebar({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildNavItem(
                    context,
                    'Dashboard',
                    Icons.dashboard_rounded,
                    'dashboard',
                    const InstructorDashboardScreen(),
                  ),
                  
                  // LMS SECTION
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'LEARNING MANAGEMENT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  _buildNavItem(
                    context,
                    'LMS Dashboard',
                    Icons.school_rounded,
                    'lms',
                    const InstructorLmsDashboard(),
                  ),
                  _buildNavItem(
                    context,
                    'My Courses',
                    Icons.menu_book_rounded,
                    'lms-courses',
                    const InstructorLmsCoursesScreen(),
                  ),
                  _buildNavItem(
                    context,
                    'Create Course',
                    Icons.add_circle_outline_rounded,
                    'lms-create',
                    const InstructorLmsCreateCourseScreen(),
                  ),
                  
                  const Divider(),
                  
                  // HEALTH PROGRAMS SECTION
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      'HEALTH PROGRAMS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  _buildNavItem(
                    context,
                    'Manage Programs',
                    Icons.health_and_safety_rounded,
                    'programs',
                    const InstructorCoursesManagementScreen(),
                  ),
                  _buildNavItem(
                    context,
                    'Create New Program',
                    Icons.add_circle_outline_rounded,
                    'create',
                    const InstructorCreateCourseScreen(),
                  ),
                  _buildNavItem(
                    context,
                    'Assign Programs',
                    Icons.assignment_ind_rounded,
                    'assign',
                    const InstructorAssignCourseScreen(),
                  ),
                  _buildNavItem(
                    context,
                    'Assigned Learners',
                    Icons.group_rounded,
                    'learners',
                    const InstructorLearnersScreen(),
                  ),
                  _buildNavItem(
                    context,
                    'Analytics',
                    Icons.analytics_rounded,
                    'analytics',
                    const InstructorAnalytics(),
                  ),
                  _buildNavItem(
                    context,
                    'Health Tips',
                    Icons.tips_and_updates_rounded,
                    'tips',
                    const InstructorPrecautionsManagementScreen(),
                  ),
                  const Divider(),
                  _buildNavItem(
                    context,
                    'Profile Settings',
                    Icons.settings_rounded,
                    'profile',
                    const InstructorProfileSetupScreen(),
                  ),
                ],
              ),
            ),
            // footer removed (no logout in drawer)
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
      color: Colors.white,
      child: Column(
        children: [
          Image.asset(
            'assets/Asset 1.png',
            height: 64,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.primaryColor,
                radius: 22,
                child: Icon(Icons.person_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructor Panel',
                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Program Manager',
                      style: TextStyle(color: AppColors.primaryColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    String title,
    IconData icon,
    String route,
    Widget screen,
  ) {
    final isSelected = currentRoute == route;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppColors.primaryColor : const Color(0xFF64748B),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppColors.primaryColor : const Color(0xFF0F172A),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: AppColors.primaryColor.withValues(alpha: 0.05),
      onTap: () {
        Navigator.pop(context); // Close drawer
        if (!isSelected) {
          Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => screen));
        }
      },
    );
  }

}
