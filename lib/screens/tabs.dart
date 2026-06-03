import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:icare/widgets/whatsapp_button.dart';
import 'package:icare/screens/admin_dashboard.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/navigators/bottom_tab_bar.dart';
import 'package:icare/navigators/bottom_tabs.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/screens/bookings_history.dart';
import 'package:icare/screens/chat_list_screen.dart';
import 'package:icare/screens/home.dart';
import 'package:icare/screens/notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:icare/screens/profile.dart';
import 'package:icare/screens/profile_edit.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart' show buildProfileImageProvider;
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/navigators/drawer.dart';
import 'package:icare/widgets/svg_wrapper.dart';
import 'package:icare/screens/courses.dart';
import 'package:icare/screens/doctor_appointments.dart';
import 'package:icare/screens/doctor_dashboard.dart';
import 'package:icare/screens/doctor_schedule_calendar.dart';
import 'package:icare/screens/doctor_analytics.dart';
import 'package:icare/screens/doctor_availability.dart';
import 'package:icare/screens/pharmacist_dashboard.dart';
import 'package:icare/screens/laboratory_dashboard.dart';
import 'package:icare/screens/lab_bookings_management.dart';
import 'package:icare/screens/lab_tests_management.dart';
import 'package:icare/screens/lab_analytics.dart';
import 'package:icare/screens/lab_profile_setup.dart';
import 'package:icare/screens/lab_settings_screen.dart';
import 'package:icare/screens/pharmacy_inventory.dart';
import 'package:icare/screens/pharmacy_orders.dart';
import 'package:icare/screens/pharmacy_analytics.dart';
import 'package:icare/screens/pharmacy_profile_setup.dart';
import 'package:icare/screens/doctor_notifications.dart';
import 'package:icare/screens/doctor_profile_setup.dart';
import 'package:icare/screens/help_and_support.dart';
import 'package:icare/screens/analytics_dashboard_screen.dart';
import 'package:icare/screens/health_journey_screen.dart';
import 'package:icare/screens/lifestyle_tracker_screen.dart';
import 'package:icare/screens/emergency_contacts_screen.dart';
import 'package:icare/screens/security_audit_log_screen.dart';
import 'package:icare/screens/certificates_screen.dart';
import 'package:icare/screens/resource_library_screen.dart';
import 'package:icare/screens/tasks.dart';
import 'package:icare/screens/health_community.dart';
import 'package:icare/screens/settings.dart';
import 'package:icare/screens/patient_book_lab_flow.dart';
import 'package:icare/screens/lab_reports_screen.dart';
import 'package:icare/screens/payment_invoices.dart';
import 'package:icare/screens/pharmacies.dart';
import 'package:icare/screens/patient_prescriptions.dart';
import 'package:icare/screens/reminder_list.dart';
import 'package:icare/screens/student_dashboard.dart';
import 'package:icare/screens/student_profile_setup.dart';
import 'package:icare/screens/instructor_dashboard.dart';
import 'package:icare/screens/instructor_courses_management.dart';
import 'package:icare/screens/instructor_learners_screen.dart';
import 'package:icare/screens/instructor_precautions_management.dart';
import 'package:icare/screens/instructor_analytics.dart';
import 'package:icare/screens/instructor_profile_setup.dart';
import 'package:icare/screens/instructor_lms_dashboard.dart';
import 'package:icare/screens/my_learning.dart';

class TabsScreen extends ConsumerStatefulWidget {
  final String? initialAdminTab;
  const TabsScreen({super.key, this.initialAdminTab});
  @override
  ConsumerState<TabsScreen> createState() => _TabsScreenState();
}

class _TabsScreenState extends ConsumerState<TabsScreen> {
  var currentIndex = 0;
  void _selectPage(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).userRole;

    // Instructor gets the full Google Classroom LMS as their main interface
    if (role == 'Instructor') {
      return const InstructorLmsDashboard();
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final bool isWeb = screenWidth > 600;
    final double maxWidth = 430;

    Widget activePage = const HomeScreen();
    if (role == "Pharmacy") {
      if (currentIndex == 0) {
        activePage = const PharmacistDashboard();
      } else if (currentIndex == 1) {
        activePage = const PharmacyOrders();
      } else if (currentIndex == 2) {
        activePage = const PharmacyInventory();
      } else if (currentIndex == 3) {
        activePage = const PharmacyProfileSetup();
      }
    } else if (role == "Laboratory") {
      if (currentIndex == 0) {
        activePage = const LaboratoryDashboard();
      } else if (currentIndex == 1) {
        activePage = const LabBookingsManagement();
      } else if (currentIndex == 2) {
        activePage = const LabReportsScreen();
      }
    } else if (role == "Doctor") {
      if (currentIndex == 0) {
        activePage = const DoctorDashboard();
      } else if (currentIndex == 1) {
        activePage = const DoctorAppointmentsScreen();
      }
    } else if (role == "Instructor") {
      if (currentIndex == 0) {
        activePage = const InstructorDashboardScreen();
      } else if (currentIndex == 1) {
        activePage = InstructorCoursesManagementScreen();
      }
    } else if (role == "Student") {
      if (currentIndex == 0) {
        activePage = StudentDashboard();
      } else if (currentIndex == 1) {
        activePage = Courses();
      } else if (currentIndex == 2) {
        activePage = ChatListScreen();
      }
    } else if (role == "Admin") {
      if (currentIndex == 0) {
        activePage = AdminDashboard(
          initialTab: widget.initialAdminTab ?? 'Pending',
        );
      } else if (currentIndex == 2) {
        activePage = ChatListScreen();
      } else if (currentIndex == 3) {
        activePage = ProfileScreen();
      } else {
        activePage = AdminDashboard(
          initialTab: widget.initialAdminTab ?? 'Pending',
        );
      }
    } else {
      // Default to Patient dashboard
      if (currentIndex == 0) {
        activePage = const HomeScreen();
      } else if (currentIndex == 1) {
        activePage = const MyLearningScreen();
      } else if (currentIndex == 2) {
        // On web show the web profile overview; on mobile show the edit profile form
        activePage = isWeb ? ProfileScreen() : const ProfileEditScreen();
      } else if (currentIndex == 4) {
        activePage = const MyLearningScreen();
      }
    }

    final tabs = buildTabs(
      role: role,
      context: context,
      currentIndex: currentIndex,
      onSelect: _selectPage,
    );

    // ── Mobile: original layout, zero changes ──────────────────────────────
    if (!isWeb) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: Builder(
            builder: (context) {
              return Padding(
                padding: EdgeInsets.only(left: ScallingConfig.scale(28.0)),
                child: GestureDetector(
                  onTap: () {
                    Scaffold.of(context).openDrawer();
                  },
                  child: CircleAvatar(
                    backgroundColor: AppColors.white,
                    child: SvgWrapper(assetPath: ImagePaths.menu),
                  ),
                ),
              );
            },
          ),
          centerTitle: false,
          title: Builder(builder: (_) {
            final userName = ref.watch(authProvider).user?.name ?? 'User';
            final firstName = userName.split(' ').first;
            final roleLabel = role == 'Doctor' ? 'Doctor Account'
                : role == 'Pharmacy' ? 'Pharmacy Account'
                : role == 'Laboratory' ? 'Laboratory Account'
                : role == 'Instructor' ? 'Instructor Account'
                : role == 'Student' ? 'Student Account'
                : role == 'Admin' ? 'Admin Account'
                : 'Patient Account';
            return Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(
                  text: 'Hello, $firstName',
                  fontSize: 14,
                  color: AppColors.darkGreyColor,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Gilroy-Bold',
                ),
                CustomText(
                  text: roleLabel,
                  fontSize: 11,
                  color: AppColors.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Gilroy-SemiBold',
                ),
              ],
            );
          }),
          actions: [
            Padding(
              padding: EdgeInsets.only(right: ScallingConfig.scale(10)),
              child: GestureDetector(
                onTap: () {
                  if (role == 'Doctor') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => const DoctorNotifications(),
                      ),
                    );
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => NotificationScreen()),
                    );
                  }
                },
                child: CircleAvatar(
                  backgroundColor: AppColors.white,
                  child: SvgWrapper(assetPath: ImagePaths.notification),
                ),
              ),
            ),
          ],
        ),
        drawer: CustomDrawer(),
        body: Stack(
          children: [
            activePage,
            WhatsAppFloatingButton(
              bottomOffset: (role == 'Pharmacy' && currentIndex == 1) ? 90 : 20,
            ),
          ],
        ),
        bottomNavigationBar: BottomTabBar(
          tabs: buildTabs(
            role: role,
            context: context,
            currentIndex: currentIndex,
            onSelect: _selectPage,
          ),
          onSelect: (value) {},
        ),
      );
    }

    // ── Web: full dashboard layout ─────────────────────────────────────────
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: Stack(
        children: [
          Row(
            children: [
              // ── Left Sidebar ────────────────────────────────────────────────
              _WebSidebar(
                currentIndex: currentIndex,
                role: role,
                onSelect: _selectPage,
              ),
              // ── Main content area ─────────────────────────────────────────
              Expanded(
                child: Column(
                  children: [
                    // Premium top navbar
                    _WebTopBar(role: role),
                    // Content fills remaining space.
                    // ClipRect prevents overflow zebra-stripe warnings from
                    // ScallingConfig scaling elements slightly too large on web.
                    Expanded(
                      child: ClipRect(
                        child: LayoutBuilder(
                          builder: (outerCtx, constraints) {
                            return MediaQuery(
                              // Override size so Utils.windowWidth/Height return
                              // the actual content-pane dimensions.
                              data: MediaQuery.of(outerCtx).copyWith(
                                size: Size(
                                  constraints.maxWidth,
                                  constraints.maxHeight,
                                ),
                                // Zero out view padding so content isn't pushed
                                // up for a bottom-nav bar that doesn't exist on web.
                                viewPadding: EdgeInsets.zero,
                                viewInsets: EdgeInsets.zero,
                              ),
                              child: Builder(
                                builder: (innerCtx) {
                                  // Re-init ScallingConfig with the constrained
                                  // content-pane width so scale() / moderateScale()
                                  // don't use the full browser viewport width.
                                  ScallingConfig().init(innerCtx);
                                  return activePage;
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          WhatsAppFloatingButton(
            bottomOffset: (role == 'Pharmacy' && currentIndex == 1) ? 90 : 20,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Web Sidebar
// ═══════════════════════════════════════════════════════════════════════════
class _WebSidebar extends ConsumerStatefulWidget {
  const _WebSidebar({
    required this.currentIndex,
    required this.role,
    required this.onSelect,
  });
  final int currentIndex;
  final String role;
  final void Function(int) onSelect;

  @override
  ConsumerState<_WebSidebar> createState() => _WebSidebarState();
}

class _WebSidebarState extends ConsumerState<_WebSidebar> {
  @override
  Widget build(BuildContext context) {
    final role = widget.role;
    final currentIndex = widget.currentIndex;
    final onSelect = widget.onSelect;
    final List<_SidebarItem> items;
    if (role == 'Admin') {
      items = <_SidebarItem>[];
    } else if (role == 'Instructor') {
      items = [
        _SidebarItem(icon: Icons.dashboard_outlined, label: 'Dashboard', index: 0),
        _SidebarItem(icon: Icons.school_outlined, label: 'Courses', index: 1),
      ];
    } else if (role == 'Patient') {
      items = [
        _SidebarItem(icon: Icons.home_outlined, label: 'Home', index: 0),
      ];
    } else if (role == 'Doctor') {
      items = [
        _SidebarItem(
          icon: Icons.home_outlined,
          label: 'Dashboard',
          index: 0,
        ),
        _SidebarItem(
          icon: Icons.calendar_month_outlined,
          label: 'Appointments',
          index: 1,
        ),
      ];
    } else {
      items = [
        _SidebarItem(
          icon: Icons.home_outlined,
          label: role == 'Student' ? 'Learning Dashboard' : 'Home',
          index: 0,
        ),
        _SidebarItem(
          icon: role == 'Pharmacy'
              ? Icons.shopping_cart_outlined
              : (role == 'Laboratory'
                    ? Icons.assignment_ind_outlined
                    : (role == 'Student'
                          ? Icons.school_outlined
                          : Icons.calendar_month_outlined)),
          label: role == 'Pharmacy'
              ? 'Orders'
              : (role == 'Laboratory'
                    ? 'New Requests'
                    : (role == 'Student' ? 'My Programs' : 'Appointments')),
          index: 1,
        ),
        if (role != 'Student')
          _SidebarItem(
            icon: role == 'Pharmacy'
                ? Icons.inventory_2_outlined
                : (role == 'Laboratory'
                      ? Icons.upload_file_outlined
                      : Icons.chat_bubble_outline),
            label: role == 'Pharmacy'
                ? 'Inventory'
                : (role == 'Laboratory' ? 'Records' : 'Messages'),
            index: 2,
          ),
      ];
    }

    List<_SidebarAction> actions = [];
    if (role == 'Student') {
      actions = [
        _SidebarAction(
          'My Certificates',
          Icons.workspace_premium_outlined,
          () => Navigator.of(context).push(
            MaterialPageRoute(builder: (ctx) => const CertificatesScreen()),
          ),
        ),
        _SidebarAction(
          'Resource Library',
          Icons.library_books_outlined,
          () => Navigator.of(context).push(
            MaterialPageRoute(builder: (ctx) => const ResourceLibraryScreen()),
          ),
        ),
      ];
    }

    return Container(
      width: 260,
      height: double.infinity,
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 30),
          // ── Brand logo ─────────────────────────────────────────────────
          Image.asset(
            'assets/Asset 1.png',
            height: 64,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),

          const SizedBox(height: 28),

          // ── Profile card (hidden for Patient, Doctor, Pharmacy, Laboratory, Student, Instructor) ───────────────
          if (role != 'Patient' && role != 'Doctor' && role != 'Pharmacy' && role != 'Laboratory' && role != 'Student' && role != 'Instructor')
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const ProfileEditScreen()),
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryColor.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryColor, width: 2),
                    ),
                    child: Consumer(
                      builder: (context, ref, child) {
                        final user = ref.watch(authProvider).user;
                        final imgProvider = buildProfileImageProvider(user?.profilePicture);
                        final initial = (user?.name ?? 'U').isNotEmpty ? (user!.name[0].toUpperCase()) : 'U';
                        return CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                          child: ClipOval(
                            child: imgProvider != null
                              ? Image(image: imgProvider, width: 48, height: 48, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Text(initial, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryColor)))
                              : Text(initial, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryColor)),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Consumer(
                          builder: (context, ref, child) {
                            final userName =
                                ref.watch(authProvider).user?.name ?? 'User';
                            return Text(
                              userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.primaryColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            role.isNotEmpty
                                ? role == 'Laboratory'
                                      ? 'Lab Technician'
                                      : role == 'Pharmacy'
                                      ? 'Pharmacist'
                                      : role[0].toUpperCase() +
                                            role.substring(1)
                                : role,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primaryColor,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),



          // ── Section label ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'MY ACCOUNT',
                style: TextStyle(
                  color: AppColors.primaryColor.withValues(alpha: 0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),

          // ── Nav items ──────────────────────────────────────────────────
          Expanded(
            child: Scrollbar(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  ...items.map((item) {
                    final isSelected = currentIndex == item.index;
                    return GestureDetector(
                      onTap: () => onSelect(item.index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryColor.withValues(alpha: 0.10)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: isSelected
                            ? Border.all(
                                color: AppColors.primaryColor.withValues(alpha: 0.20),
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: Icon(
                              item.icon,
                              size: 22,
                              color: isSelected
                                  ? AppColors.primaryColor
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? AppColors.primaryColor
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          if (isSelected)
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),

                // ── Role-specific extra nav items ──────────────────────────
                if (role == 'Patient') ...[
                  const SizedBox(height: 8),
                  _buildExtraNavItem(
                    context,
                    Icons.calendar_month_outlined,
                    'My Appointments',
                    () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BookingsHistoryScreen())),
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.medication_liquid_outlined,
                    'My Prescriptions',
                    () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PatientPrescriptions())),
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.medication_outlined,
                    'Order Medicines',
                    () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PharmaciesScreen())),
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.science_outlined,
                    'Book a Lab Test',
                    () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PatientBookLabFlow())),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Divider(
                      color: const Color(0xFFE8ECF5),
                      height: 1,
                    ),
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.history_outlined,
                    'Health Journey',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const HealthJourneyScreen(),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.monitor_heart_outlined,
                    'Health Tracker',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const LifestyleTrackerScreen(),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.school_outlined,
                    'My Learning',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const MyLearningScreen(),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.contact_emergency_outlined,
                    'Emergency Contacts',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const EmergencyContactsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.biotech_outlined,
                    'Lab Results/Reports',
                    () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LabReportsScreen())),
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.alarm_outlined,
                    'Reminders',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const ReminderList(),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.people_outline_rounded,
                    'Health Community',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const HealthCommunityScreen(),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.settings_outlined,
                    'Settings',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],

                if (role == 'Doctor') ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Divider(
                      color: const Color(0xFFE8ECF5),
                      height: 1,
                    ),
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.schedule_outlined,
                    'My Schedule',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const DoctorScheduleCalendar(),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.analytics_outlined,
                    'Analytics',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const DoctorAnalytics(),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.people_outline_rounded,
                    'Health Community',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const HealthCommunityScreen(),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.event_available_outlined,
                    'Availability',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const DoctorAvailability(),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.notifications_outlined,
                    'Notifications',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const DoctorNotifications(),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.help_outline_rounded,
                    'Help & Support',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const HelpAndSupport(),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.settings_outlined,
                    'Settings',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],

                if (role == 'Instructor') ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Divider(
                      color: const Color(0xFFE8ECF5),
                      height: 1,
                    ),
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.library_books_outlined,
                    'Manage Courses',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => InstructorCoursesManagementScreen(),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.group_outlined,
                    'Assigned Learners',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => InstructorLearnersScreen(),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.health_and_safety_outlined,
                    'Health Precautions',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) =>
                              InstructorPrecautionsManagementScreen(),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.analytics_outlined,
                    'Educational Analytics',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => InstructorAnalytics(),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.settings_outlined,
                    'Settings',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],

                if (role == 'Laboratory') ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Divider(
                      color: const Color(0xFFE8ECF5),
                      height: 1,
                    ),
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.list_alt_outlined,
                    'Orders',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const LabBookingsManagement(),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.science_outlined,
                    'Test Catalog',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const LabTestsManagement(),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.receipt_long_outlined,
                    'Invoices',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const PaymentInvoices(),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.analytics_outlined,
                    'Analytics',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const LabAnalytics(),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.support_agent_outlined,
                    'iCare Lab Support',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const HelpAndSupport(),
                        ),
                      );
                    },
                  ),
                ],

                if (role == 'Pharmacy') ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Divider(
                      color: const Color(0xFFE8ECF5),
                      height: 1,
                    ),
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.hourglass_empty_outlined,
                    'Awaiting Fulfillment',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const PharmacyOrders(),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.receipt_long_outlined,
                    'Invoices',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const PaymentInvoices(isPharmacy: true),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.analytics_outlined,
                    'Analytics',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const PharmacyAnalytics(),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.settings_outlined,
                    'Settings',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.support_agent_outlined,
                    'iCare Pharmacist Support',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const HelpAndSupport(),
                        ),
                      );
                    },
                  ),
                ],

                if (role == 'Student') ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Divider(
                      color: const Color(0xFFE8ECF5),
                      height: 1,
                    ),
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.school_outlined,
                    role == 'Student' ? 'My Courses' : 'Manage Courses',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const Courses(myPurchased: true),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.workspace_premium_outlined,
                    role == 'Student' ? 'My Certificates' : 'Certifications',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const CertificatesScreen(),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.library_books_outlined,
                    'Resource Library',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const ResourceLibraryScreen(),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.task_alt_outlined,
                    'Assessments',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (ctx) => const TaskScreen()),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.settings_outlined,
                    'Settings',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],

                if (role == 'Admin') ...[
                  const SizedBox(height: 8),
                  _buildExtraNavItem(
                    context,
                    Icons.verified_user_outlined,
                    'Verify Applications',
                    () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (ctx) =>
                              const TabsScreen(initialAdminTab: 'Pending'),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.medical_services_outlined,
                    'Manage Doctors',
                    () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (ctx) =>
                              const TabsScreen(initialAdminTab: 'Doctor'),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.school_outlined,
                    'Manage Students',
                    () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (ctx) =>
                              const TabsScreen(initialAdminTab: 'Student'),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.local_pharmacy_outlined,
                    'Manage Pharmacies',
                    () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (ctx) =>
                              const TabsScreen(initialAdminTab: 'Pharmacy'),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.biotech_outlined,
                    'Manage Laboratories',
                    () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (ctx) =>
                              const TabsScreen(initialAdminTab: 'Laboratory'),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.person_add_outlined,
                    'Manage Instructors',
                    () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (ctx) =>
                              const TabsScreen(initialAdminTab: 'Instructor'),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.analytics_outlined,
                    'Platform Analytics',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const AnalyticsDashboardScreen(),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.security_outlined,
                    'Security Audit Logs',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const SecurityAuditLogScreen(),
                        ),
                      );
                    },
                  ),
                  _buildExtraNavItem(
                    context,
                    Icons.settings_outlined,
                    'Settings',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildExtraNavItem(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    int badgeCount = 0,
    String? svgPath,
  }) {
    return _HoverableNavItem(
      icon: icon,
      label: label,
      onTap: onTap,
      badgeCount: badgeCount,
      svgPath: svgPath,
    );
  }
}

class _HoverableNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;
  final String? svgPath;

  const _HoverableNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
    this.svgPath,
  });

  @override
  State<_HoverableNavItem> createState() => _HoverableNavItemState();
}

class _HoverableNavItemState extends State<_HoverableNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _isHovered
                ? AppColors.primaryColor.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: _isHovered
                ? Border.all(
                    color: AppColors.primaryColor.withValues(alpha: 0.20),
                  )
                : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: widget.svgPath != null
                    ? SvgPicture.asset(
                        widget.svgPath!,
                        width: 22,
                        height: 22,
                        colorFilter: ColorFilter.mode(
                          _isHovered ? AppColors.primaryColor : const Color(0xFF64748B),
                          BlendMode.srcIn,
                        ),
                      )
                    : Icon(
                        widget.icon,
                        size: 22,
                        color: _isHovered
                            ? AppColors.primaryColor
                            : const Color(0xFF64748B),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: _isHovered ? FontWeight.w600 : FontWeight.w500,
                    color: _isHovered
                        ? AppColors.primaryColor
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
              if (widget.badgeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'New ${widget.badgeCount.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Gilroy-Bold',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Web Top Navbar
// ═══════════════════════════════════════════════════════════════════════════
class _WebTopBar extends ConsumerWidget {
  const _WebTopBar({required this.role});
  final String role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          // Page title
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0B2D6E),
                ),
              ),
              Text(
                'Welcome back! Here\'s your overview.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Notification bell
          GestureDetector(
            onTap: () {
              if (role == 'Doctor') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const DoctorNotifications(),
                  ),
                );
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (ctx) => NotificationScreen()),
                );
              }
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.notifications_outlined,
                    color: Color(0xFF0B2D6E),
                    size: 20,
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Avatar + greeting (with dropdown for Patient)
          PopupMenuButton<String>(
              offset: const Offset(0, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              color: Colors.white,
              elevation: 4,
              onSelected: (value) {
                if (value == 'edit') {
                  // Navigate to role-specific profile edit page
                  if (role == 'Doctor') {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => const DoctorProfileSetup()),
                    );
                  } else if (role == 'Pharmacy') {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => const PharmacyProfileSetup()),
                    );
                  } else if (role == 'Laboratory') {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => const LabProfileSetup()),
                    );
                  } else if (role == 'Student') {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => const StudentProfileSetup()),
                    );
                  } else if (role == 'Instructor') {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => InstructorProfileSetupScreen()),
                    );
                  } else {
                    // Patient or other roles - use generic profile edit
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => const ProfileEditScreen()),
                    );
                  }
                } else if (value == 'logout') {
                  ref.read(authProvider.notifier).setUserLogout();
                  context.go('/login');
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: const [
                      Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                      SizedBox(width: 10),
                      Text('Edit Profile', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: const [
                      Icon(Icons.logout_rounded, size: 18, color: Colors.redAccent),
                      SizedBox(width: 10),
                      Text('Logout', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.redAccent)),
                    ],
                  ),
                ),
              ],
              child: Row(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Consumer(
                        builder: (context, ref, child) {
                          final userName =
                              ref.watch(authProvider).user?.name ?? 'User';
                          return Text(
                            userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF1A1A2E),
                            ),
                          );
                        },
                      ),
                      Text(
                        role.isNotEmpty
                            ? role == 'Laboratory'
                                  ? 'Lab Technician'
                                  : role == 'Pharmacy'
                                  ? 'Pharmacist'
                                  : role[0].toUpperCase() + role.substring(1)
                            : role,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF888888),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Consumer(
                    builder: (context, ref, child) {
                      final user = ref.watch(authProvider).user;
                      final imgProvider = buildProfileImageProvider(user?.profilePicture);
                      final initial = (user?.name ?? 'U').isNotEmpty ? user!.name[0].toUpperCase() : 'U';
                      return CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                        child: ClipOval(
                          child: imgProvider != null
                            ? Image(image: imgProvider, width: 40, height: 40, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Text(initial, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryColor)))
                            : Text(initial, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryColor)),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SidebarItem {
  final IconData icon;
  final String label;
  final int index;
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.index,
  });
}

class _SidebarAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _SidebarAction(this.label, this.icon, this.onTap);
}


