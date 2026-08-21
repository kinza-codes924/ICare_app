import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icare/models/user.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/services/auth_service.dart';
import 'package:icare/screens/doctor_profile_setup.dart';
import 'package:icare/screens/login.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/custom_text.dart';

class CustomDrawer extends ConsumerStatefulWidget {
  const CustomDrawer({super.key});

  @override
  ConsumerState<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends ConsumerState<CustomDrawer> {
  final _scrollController = ScrollController();
  List<String> _availableRoles = [];

  static const _roleDisplayNames = {
    'doctor': 'Doctor',
    'student': 'Student',
    'instructor': 'Instructor',
    'patient': 'Patient',
    'lab': 'Laboratory',
    'laboratory': 'Laboratory',
    'pharmacy': 'Pharmacy',
    'receptionist': 'Receptionist',
  };

  static const _roleIcons = {
    'doctor': Icons.medical_services_rounded,
    'student': Icons.school_rounded,
    'instructor': Icons.cast_for_education_rounded,
    'patient': Icons.person_rounded,
    'lab': Icons.biotech_rounded,
    'laboratory': Icons.biotech_rounded,
    'pharmacy': Icons.local_pharmacy_rounded,
    'receptionist': Icons.support_agent_rounded,
  };

  @override
  void initState() {
    super.initState();
    _loadAvailableRoles();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableRoles() async {
    try {
      final res = await ApiService().get('/auth/profile');
      final roles = (res.data['user']?['roles'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      if (mounted) setState(() => _availableRoles = roles);
    } catch (_) {}
  }

  Future<void> _switchRole(String role) async {
    final result = await AuthService().switchRole(role);
    if (!mounted) return;
    if (result['success'] == true) {
      final inner = result['data'];
      await ref.read(authProvider.notifier).setUserToken(inner['token'].toString());
      final currentUser = ref.read(authProvider).user;
      final user = User.fromJson(Map<String, dynamic>.from(inner['user'] as Map)).copyWith(
        isEmailVerified: currentUser?.isEmailVerified ?? true,
        isPhoneVerified: currentUser?.isPhoneVerified ?? true,
      );
      await ref.read(authProvider.notifier).setUser(user);
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      context.go('/dashboard');
    } else {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Role switch failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSwitchRoleSheet(BuildContext context) {
    final currentRole = ref.read(authProvider).userRole.toLowerCase();
    final activeKey = currentRole == 'laboratory' ? 'lab' : currentRole;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.swap_horiz_rounded, color: Color(0xFF0036BC), size: 22),
              const SizedBox(width: 8),
              const Text('Switch Role', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 6),
            const Text('Select a role to switch to its dashboard.', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
            const SizedBox(height: 16),
            ..._availableRoles.map((r) {
              final key = r.toLowerCase();
              final isActive = key == activeKey;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: isActive ? null : () async {
                    Navigator.pop(sheetCtx);
                    await _switchRole(key);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primaryColor.withValues(alpha: 0.06) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive ? AppColors.primaryColor : const Color(0xFFE2E8F0),
                        width: isActive ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_roleIcons[key] ?? Icons.person_rounded, color: AppColors.primaryColor, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _roleDisplayNames[key] ?? r,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                        ),
                        if (isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_rounded, color: Colors.white, size: 12),
                                SizedBox(width: 3),
                                Text('Current', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          )
                        else
                          const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedRole = ref.watch(authProvider).userRole;

    debugPrint('🗂️ DRAWER OPENED — Role: $selectedRole');

    var drawerItems = [
      _drawerItem('Tasks', Icons.task_alt_outlined, () {
        context.push('/tasks');
      }),
      _drawerItem('Booking History', Icons.history_outlined, () {
        context.push('/bookings');
      }),
      _drawerItem('Reminders', Icons.alarm_outlined, () {
        context.go('/reminders');
      }),
      _drawerItem('Help & Support', Icons.help_outline_rounded, () {
        context.go('/help');
      }),
      _drawerItem('Wallet', Icons.account_balance_wallet_outlined, () {
        context.push('/wallet');
      }),
      _drawerItem('Health Programs', Icons.health_and_safety_outlined, () {
        context.push('/courses');
      }),
    ];

    if (selectedRole == "Laboratory") {
      drawerItems = [
        _drawerItem('Dashboard', Icons.dashboard_outlined, () {
          context.go('/lab/dashboard');
        }),
        _drawerItem('New Requests', Icons.pending_actions_outlined, () {
          context.go('/lab/bookings?title=New%20Requests&filter=pending');
        }),
        _drawerItem('Records', Icons.folder_copy_outlined, () {
          context.go('/lab/reports');
        }),
        _drawerItem('Orders', Icons.list_alt_outlined, () {
          context.go('/lab/bookings');
        }),
        _drawerItem('Test Catalog', Icons.science_outlined, () {
          context.go('/lab/tests');
        }),
        _drawerItem('Invoices', Icons.receipt_long_outlined, () {
          context.push('/payment-invoices');
        }),
        _drawerItem('Analytics', Icons.analytics_outlined, () {
          context.go('/lab/analytics');
        }),
        _drawerItem('Settings', Icons.settings_outlined, () {
          context.go('/settings');
        }),
        _drawerItem('iCare Lab Support', Icons.headset_mic_rounded, () {
          context.go('/help');
        }),
      ];
    } else if (selectedRole == "Patient") {
      drawerItems = [
        _drawerItem('My Appointments', Icons.calendar_month_outlined, () {
          context.go('/patient/bookings-history');
        }),
        _drawerItem('iCare Clinics', Icons.storefront_outlined, () {
          context.go('/patient/icare-clinics');
        }),
        _drawerItem('My Prescriptions', Icons.medication_liquid_outlined, () {
          context.go('/patient/prescriptions');
        }),
        _drawerItem('Order Medicines', Icons.medication_outlined, () {
          context.go('/patient/pharmacies');
        }),
        _drawerItem('Book a Lab Test', Icons.science_outlined, () {
          context.go('/patient/book-lab');
        }),
        _drawerItem('Health Journey', Icons.history_outlined, () {
          context.go('/patient/health-journey');
        }),
        _drawerItem('Health Tracker', Icons.monitor_heart_outlined, () {
          context.go('/patient/health-tracker');
        }),
        _drawerItem('Lab Results/Reports', Icons.biotech_outlined, () {
          context.go('/lab/reports');
        }),
        _drawerItem('Reminders', Icons.alarm_outlined, () {
          context.go('/reminders');
        }),
        _drawerItem('Health Community', Icons.people_outline_rounded, () {
          context.go('/community');
        }),
        _drawerItem('Achievements & Rewards', Icons.emoji_events_outlined, () {
          context.go('/rewards');
        }),
        _drawerItem('Settings', Icons.settings_outlined, () {
          context.go('/settings');
        }),
      ];
    } else if (selectedRole == "Doctor") {
      drawerItems = [
        _drawerItem('My Appointments', Icons.calendar_month_outlined, () {
          context.go('/doctor/appointments');
        }),
        _drawerItem('Patient Records', Icons.folder_shared_outlined, () {
          context.go('/patient/records');
        }),
        _drawerItem('My Schedule', Icons.schedule_outlined, () {
          context.go('/doctor/schedule');
        }),
        _drawerItem('Analytics', Icons.analytics_outlined, () {
          context.go('/doctor/analytics');
        }),
        _drawerItem('Health Community', Icons.people_outline_rounded, () {
          context.go('/community');
        }),
        _drawerItem('Availability', Icons.event_available_outlined, () {
          context.go('/doctor/availability');
        }),
        _drawerItem('Notifications', Icons.notifications_outlined, () {
          context.go('/doctor/notifications');
        }),
        _drawerItem('Help & Support', Icons.help_outline_rounded, () {
          context.go('/help');
        }),
        _drawerItem('Settings', Icons.settings_outlined, () {
          context.go('/settings');
        }),
      ];
    } else if (selectedRole == "Pharmacy") {
      drawerItems = [
        _drawerItem('Dashboard', Icons.dashboard_outlined, () {
          context.go('/pharmacy/dashboard');
        }),
        _drawerItem('Awaiting Fulfillment', Icons.pending_actions_outlined, () {
          context.go('/pharmacy/orders');
        }),
        _drawerItem('Orders', Icons.receipt_long_outlined, () {
          context.go('/pharmacy/orders');
        }),
        _drawerItem('Inventory', Icons.inventory_outlined, () {
          context.go('/pharmacy/inventory');
        }),
        _drawerItem('Payment Invoices', Icons.receipt_long_outlined, () {
          context.push('/payment-invoices');
        }),
        _drawerItem('Analytics', Icons.analytics_outlined, () {
          context.go('/pharmacy/analytics');
        }),
        _drawerItem('Settings', Icons.settings_outlined, () {
          context.go('/settings');
        }),
        _drawerItem('iCare Pharmacist Support', Icons.headset_mic_rounded, () {
          context.go('/help');
        }),
      ];
    } else if (selectedRole == "Instructor") {
      drawerItems = [
        _drawerItem('Dashboard', Icons.dashboard_outlined, () {
          context.go('/instructor/dashboard');
        }),
        _drawerItem('iCare Classroom', Icons.class_rounded, () {
          context.go('/instructor/lms');
        }),
        _drawerItem('Manage Courses', Icons.library_books_outlined, () {
          context.go('/instructor/manage-courses');
        }),
        _drawerItem('Assigned Learners', Icons.group_outlined, () {
          context.go('/instructor/learners');
        }),
        _drawerItem('Student Feedback', Icons.rate_review_outlined, () {
          context.go('/instructor/lms/feedback');
        }),
        _drawerItem('Health Precautions', Icons.health_and_safety_outlined, () {
          context.go('/instructor/precautions');
        }),
        _drawerItem('Educational Analytics', Icons.analytics_outlined, () {
          context.go('/instructor/analytics');
        }),
        _drawerItem('Profile Setup', Icons.person_outlined, () {
          context.go('/instructor/profile-setup');
        }),
        _drawerItem('Help & Support', Icons.help_outline_rounded, () {
          context.go('/help');
        }),
        _drawerItem('Settings', Icons.settings_outlined, () {
          context.go('/settings');
        }),
      ];
    } else if (selectedRole == "Student") {
      drawerItems = [
        _drawerItem('Learning Dashboard', Icons.dashboard_outlined, () {
          context.go('/student/dashboard');
        }),
        _drawerItem('My Courses', Icons.school_outlined, () {
          context.push('/courses');
        }),
        _drawerItem('Open Classroom', Icons.class_outlined, () {
          context.go('/student/classroom');
        }),
        _drawerItem('Browse Courses', Icons.travel_explore_outlined, () {
          context.push('/lms/catalog');
        }),
        _drawerItem('My Certificates', Icons.workspace_premium_outlined, () {
          context.go('/student/certificates');
        }),
        _drawerItem('Assessments', Icons.task_alt_outlined, () {
          context.go('/student/assessments');
        }),
        _drawerItem('Help & Support', Icons.help_outline_rounded, () {
          context.go('/help');
        }),
        _drawerItem('Settings', Icons.settings_outlined, () {
          context.go('/settings');
        }),
      ];
    } else if (selectedRole == 'Admin') {
      drawerItems = []; // Clear other items for Admin
    } else if (selectedRole == 'Receptionist') {
      drawerItems = [
        _drawerItem('Front Desk', Icons.dashboard_outlined, () {
          context.go('/reception/dashboard');
        }),
        _drawerItem('Records', Icons.receipt_long_outlined, () {
          context.go('/reception/records');
        }),
        _drawerItem('Help & Support', Icons.help_outline_rounded, () {
          context.go('/help');
        }),
        _drawerItem('Settings', Icons.settings_outlined, () {
          context.go('/settings');
        }),
      ];
    }

    return ClipRRect(
      borderRadius: const BorderRadius.only(topRight: Radius.circular(40)),
      child: Drawer(
        width: MediaQuery.of(context).size.width * 0.75,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        child: SizedBox.expand(
          child: ColoredBox(
          color: Colors.white,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              // Header with user info
              _buildHeader(),

              // Menu list (exact items)
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: ListView(
                  controller: _scrollController,
                  padding: EdgeInsets.zero,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (selectedRole != 'Admin') ...[
                      _drawerItem('Home', Icons.home_outlined, () {
                        context.go('/dashboard');
                      }, isActive: true),

                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        child: Divider(color: Color(0xFFF1F5F9), height: 1),
                      ),

                      // Role-specific quick actions
                      if (selectedRole == 'Patient') ...[
                        _drawerActionItem(
                          context,
                          'Book Appointment',
                          const Color(0xFF6366F1),
                          Icons.calendar_month_outlined,
                          () {},
                        ),
                        _drawerActionItem(
                          context,
                          'View Lab Reports',
                          const Color(0xFF0EA5E9),
                          Icons.science_outlined,
                          () {},
                        ),
                      ] else if (selectedRole == 'Laboratory') ...[
                        _drawerActionItem(
                          context,
                          'New Requests',
                          const Color(0xFF6366F1),
                          Icons.pending_actions_outlined,
                          () => context.go('/lab/bookings?title=New%20Requests&filter=pending'),
                        ),
                        _drawerActionItem(
                          context,
                          'Records',
                          const Color(0xFF0EA5E9),
                          Icons.folder_copy_outlined,
                          () => context.go('/lab/reports'),
                        ),
                      ] else if (selectedRole == 'Instructor') ...[
                        _drawerActionItem(
                          context,
                          'Manage Courses',
                          const Color(0xFF8B5CF6),
                          Icons.school_outlined,
                          () {},
                        ),
                        _drawerActionItem(
                          context,
                          'My Learners',
                          const Color(0xFF0EA5E9),
                          Icons.people_outlined,
                          () {},
                        ),
                      ],

                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        child: Divider(color: Color(0xFFF1F5F9), height: 1),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: CustomText(
                          text: "MY ACCOUNT",
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryColor,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],

                    if (selectedRole == 'Admin') ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: CustomText(
                          text: "ADMIN MANAGEMENT",
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryColor,
                          letterSpacing: 1.5,
                        ),
                      ),
                      _drawerActionItem(
                        context,
                        'Verify Applications',
                        const Color(0xFFF59E0B),
                        Icons.verified_user_outlined,
                        () => context.go('/dashboard?adminTab=Pending'),
                      ),
                      _drawerActionItem(
                        context,
                        'Manage Doctors',
                        const Color(0xFF3B82F6),
                        Icons.medical_services_outlined,
                        () => context.go('/dashboard?adminTab=Doctor'),
                      ),
                      _drawerActionItem(
                        context,
                        'Manage Students',
                        const Color(0xFF6366F1),
                        Icons.school_outlined,
                        () => context.go('/dashboard?adminTab=Student'),
                      ),
                      _drawerActionItem(
                        context,
                        'Manage Pharmacies',
                        const Color(0xFF10B981),
                        Icons.local_pharmacy_outlined,
                        () => context.go('/dashboard?adminTab=Pharmacy'),
                      ),
                      _drawerActionItem(
                        context,
                        'Manage Laboratories',
                        const Color(0xFF0EA5E9),
                        Icons.biotech_outlined,
                        () => context.go('/dashboard?adminTab=Laboratory'),
                      ),
                      _drawerActionItem(
                        context,
                        'Manage Instructors',
                        const Color(0xFF8B5CF6),
                        Icons.person_add_outlined,
                        () => context.go('/dashboard?adminTab=Instructor'),
                      ),

                      _drawerActionItem(
                        context,
                        'Manage Receptionists',
                        const Color(0xFF14B8A6),
                        Icons.support_agent_outlined,
                        () => context.go('/admin/receptionists'),
                      ),

                      _drawerActionItem(
                        context,
                        'iCare Clinics',
                        const Color(0xFFEC4899),
                        Icons.storefront_outlined,
                        () => context.go('/admin/clinics'),
                      ),

                      _drawerActionItem(
                        context,
                        'LMS Payments',
                        const Color(0xFF10B981),
                        Icons.receipt_long_outlined,
                        () => context.push('/admin/lms-payments'),
                      ),

                      _drawerActionItem(
                        context,
                        'Payments & Revenue',
                        const Color(0xFF0036BC),
                        Icons.payments_outlined,
                        () => context.push('/admin/payments'),
                      ),

                      _drawerActionItem(
                        context,
                        'Settings',
                        const Color(0xFF64748B),
                        Icons.settings_outlined,
                        () => context.go('/settings'),
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        child: Divider(color: Color(0xFFF1F5F9), height: 1),
                      ),
                    ],

                    // _drawerItem('Reports/Lab Results', () {}),
                    if (selectedRole != 'Admin') ...drawerItems,

                    // Switch Role — shown when user has multiple roles
                    if (_availableRoles.length > 1) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Divider(color: Color(0xFFF1F5F9), height: 1),
                      ),
                      _drawerItem('Switch Role', Icons.swap_horiz_rounded, () => _showSwitchRoleSheet(context)),
                    ],
                  ],
                ),
                ),
              ),

            ],
          ),
        ),
        ),
      ),
    ),
  );
  }

  Widget _buildHeader() {
    final selectedRole = ref.watch(authProvider).userRole;
    final userName = ref.watch(authProvider).user?.name ?? 'User';
    
    String roleDisplay = selectedRole == 'Laboratory'
        ? 'Lab Technician'
        : selectedRole == 'Pharmacy'
        ? 'Pharmacist'
        : selectedRole.isNotEmpty
        ? selectedRole[0].toUpperCase() + selectedRole.substring(1)
        : 'User';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE8ECF5), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // iCare logo only
          Image.asset(
            'assets/Asset 1.png',
            height: 56,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _drawerItem(
    String title,
    IconData icon,
    VoidCallback onTap, {
    bool isActive = false,
    int badgeCount = 0,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tileColor: isActive
            ? AppColors.primaryColor.withValues(alpha: 0.10)
            : null,
        dense: true,
        leading: Icon(
          icon,
          size: 20,
          color: isActive ? AppColors.primaryColor : const Color(0xFF64748B),
        ),
        title: CustomText(
          text: title,
          fontFamily: "Gilroy-Bold",
          fontSize: 14,
          fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
          color: isActive ? AppColors.primaryColor : const Color(0xFF64748B),
        ),
        trailing: badgeCount > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'New ${badgeCount.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Gilroy-Bold',
                  ),
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _drawerProfileDropdown(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: PopupMenuButton<String>(
        offset: const Offset(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        color: Colors.white,
        elevation: 4,
        onSelected: (value) {
          if (value == 'edit') {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (ctx) => const DoctorProfileSetup()),
            );
          } else if (value == 'logout') {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (ctx) => LoginScreen()),
              (route) => false,
            );
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
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          dense: true,
          leading: const Icon(Icons.person_outlined, size: 20, color: Color(0xFF64748B)),
          title: const Text(
            'Edit Profile',
            style: TextStyle(fontFamily: 'Gilroy-Bold', fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          ),
          trailing: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF94A3B8)),
        ),
      ),
    );
  }

  Widget _drawerActionItem(
    BuildContext context,
    String title,
    Color color,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomText(
                  text: title,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

