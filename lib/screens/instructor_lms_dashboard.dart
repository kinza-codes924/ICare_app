import 'package:easy_localization/easy_localization.dart';
import 'package:icare/utils/app_time.dart';
import 'package:icare/widgets/drag_scroll.dart';
import 'package:icare/screens/lms_public_catalog.dart';
import 'package:icare/utils/utils.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icare/screens/classroom_course_view.dart';
import 'package:icare/screens/doctor_notifications.dart';
import 'package:icare/screens/instructor_lms_create_course.dart';
import 'package:icare/screens/instructor_lms_courses.dart';
import 'package:icare/screens/instructor_profile_setup.dart';
import 'package:icare/screens/instructor_course_content_screen.dart';
import 'package:icare/screens/instructor_student_progress_screen.dart';
import 'package:icare/screens/instructor_course_analytics_screen.dart';
import 'package:icare/screens/instructor_grading_screen.dart';
import 'package:icare/screens/instructor_feedback_screen.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/services/auth_service.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/models/user.dart' as app_user;
import 'package:icare/screens/tabs.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:intl/intl.dart';
import 'dart:math';

// ─────────────────────────────────────────────────────────────
// iCare Classroom — Instructor Shell (top-level, Google Classroom style)
// ─────────────────────────────────────────────────────────────

class InstructorLmsDashboard extends ConsumerStatefulWidget {
  const InstructorLmsDashboard({super.key});

  @override
  ConsumerState<InstructorLmsDashboard> createState() => _InstructorLmsDashboardState();
}

class _InstructorLmsDashboardState extends ConsumerState<InstructorLmsDashboard> {
  final LmsService _lms = LmsService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  List<dynamic> _courses = [];
  bool _isLoading = true;
  String _userName = '';
  String _userEmail = '';
  // The header avatar only ever drew the first letter, so an instructor who had
  // uploaded a photo still saw a plain "P" next to the bell.
  String? _userPhoto;
  _NavPage _activePage = _NavPage.home;
  bool _taughtExpanded = true;
  List<String> _availableRoles = [];
  List<dynamic> _pendingInvites = [];
  final Set<String> _respondingInviteIds = {};

  static const List<Color> _cardColors = [
    Color(0xFF1A73E8),
    Color(0xFF188038),
    Color(0xFF9334E6),
    Color(0xFFE37400),
    Color(0xFF1E7E34),
    Color(0xFFB3261E),
    Color(0xFF006064),
    Color(0xFF4527A0),
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadCourses();
    _loadAvailableRoles();
    _loadPendingInvites();
  }

  Future<void> _loadPendingInvites() async {
    final invites = await _lms.getMyPendingInvites();
    if (mounted) setState(() => _pendingInvites = invites);
  }

  Future<void> _respondToInvite(String courseId, bool accept) async {
    setState(() => _respondingInviteIds.add(courseId));
    final result = accept
        ? await _lms.acceptCoTeacherInvite(courseId)
        : await _lms.rejectCoTeacherInvite(courseId);
    if (!mounted) return;
    setState(() {
      _respondingInviteIds.remove(courseId);
      if (result['success'] == true) {
        _pendingInvites.removeWhere((i) => i['courseId']?.toString() == courseId);
      }
    });
    if (accept && result['success'] == true) _loadCourses();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result['success'] == true
          ? (accept ? 'Invitation accepted — course added to your classes' : 'Invitation declined')
          : (result['message'] ?? 'Failed')),
      backgroundColor: result['success'] == true ? const Color(0xFF188038) : const Color(0xFFB3261E),
    ));
  }

  Widget _buildInviteBanner(dynamic inv) {
    final courseId = inv['courseId']?.toString() ?? '';
    final isResponding = _respondingInviteIds.contains(courseId);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1A73E8).withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.mail_outline_rounded, color: Color(0xFF1A73E8)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${inv['inviterName'] ?? 'An instructor'} invited you as ${inv['role'] ?? 'Co-Instructor'} for "${inv['courseTitle'] ?? 'a course'}"',
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Color(0xFF202124)),
                ),
                const SizedBox(height: 12),
                isResponding
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Row(
                        children: [
                          OutlinedButton(
                            onPressed: () => _respondToInvite(courseId, false),
                            child: const Text('Reject'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () => _respondToInvite(courseId, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white,
                            ),
                            child: const Text('Accept'),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ],
      ),
    );
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

  static const _roleDisplayNames = {
    'doctor': 'Doctor',
    'student': 'Student',
    'instructor': 'Instructor',
    'patient': 'Patient',
    'lab': 'Laboratory',
    'pharmacy': 'Pharmacy',
  };

  static const _roleIcons = {
    'doctor': Icons.medical_services_rounded,
    'student': Icons.school_rounded,
    'instructor': Icons.cast_for_education_rounded,
    'patient': Icons.person_rounded,
    'lab': Icons.biotech_rounded,
    'pharmacy': Icons.local_pharmacy_rounded,
  };

  Future<void> _switchRole(String role) async {
    final result = await AuthService().switchRole(role);
    if (!mounted) return;
    if (result['success'] == true) {
      final inner = result['data'];
      await ref.read(authProvider.notifier).setUserToken(inner['token'].toString());
      final currentUser = ref.read(authProvider).user;
      final user = app_user.User.fromJson(Map<String, dynamic>.from(inner['user'] as Map)).copyWith(
        isEmailVerified: currentUser?.isEmailVerified ?? true,
        isPhoneVerified: currentUser?.isPhoneVerified ?? true,
      );
      await ref.read(authProvider.notifier).setUser(user);
      if (!mounted) return;
      context.go('/dashboard');
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Role switch failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSwitchRoleDialog() {
    const activeKey = 'instructor';
    showDialog(
      context: context,
      builder: (dc) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        title: const Row(children: [
          Icon(Icons.swap_horiz_rounded, color: Color(0xFF1A73E8), size: 22),
          SizedBox(width: 8),
          Text('Switch Role', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ]),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select a role to switch to its dashboard.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
              const SizedBox(height: 16),
              ..._availableRoles.map((r) {
                final key = r.toLowerCase();
                final isActive = key == activeKey;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: isActive ? null : () {
                      Navigator.pop(dc);
                      _switchRole(key);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFF1A73E8).withValues(alpha: 0.06) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive ? const Color(0xFF1A73E8) : const Color(0xFFE2E8F0),
                          width: isActive ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A73E8).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_roleIcons[key] ?? Icons.person_rounded,
                                color: const Color(0xFF1A73E8), size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _roleDisplayNames[key] ?? r,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            ),
                          ),
                          if (isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A73E8),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dc),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUser() async {
    final user = await SharedPref().getUserData();
    if (mounted && user != null) {
      setState(() {
        _userName = user.name.isNotEmpty ? user.name : user.email.split('@').first;
        _userEmail = user.email;
        _userPhoto = user.profilePicture;
      });
    }
  }

  Future<void> _loadCourses() async {
    setState(() => _isLoading = true);
    try {
      final res = await _lms.getInstructorCourses();
      if (mounted) setState(() { _courses = (res['courses'] ?? []) as List; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _cardColor(int i) => _cardColors[i % _cardColors.length];

  void _openCourse(dynamic course) => _openCourseAtTab(course, 0);

  void _openCourseAtTab(dynamic course, int tab) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ClassroomCourseView(
        course: Map<String, dynamic>.from(course is Map ? course : {}),
        isInstructor: true,
        initialTab: tab,
      ),
    )).then((_) => _loadCourses());
  }

  void _createClass() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const InstructorLmsCreateCourseScreen(),
    )).then((_) => _loadCourses());
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      // Clear auth provider state — GoRouter redirect will navigate to /home
      await ref.read(authProvider.notifier).setUserLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 840;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF1F3F4),
      drawer: isWide ? null : _buildSidebar(isDrawer: true),
      body: Row(
        children: [
          if (isWide) _buildSidebar(isDrawer: false),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(isWide),
                Expanded(child: _buildBody(isWide)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════
  // TOP BAR
  // ════════════════════════════════════════════════

  Widget _buildTopBar(bool isWide) {
    final titles = {
      _NavPage.home: 'iCare Academy',
      _NavPage.calendar: 'Calendar',
      _NavPage.todo: 'To do',
      _NavPage.settings: 'Settings',
    };
    return Container(
      height: 64,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          if (!isWide)
            IconButton(
              icon: const Icon(Icons.menu_rounded, color: Color(0xFF444746)),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              tooltip: 'Menu',
            ),
          // On a phone, greet the instructor by name the way every other role
          // is greeted -- "Hello, <name>" with "Instructor Account" beneath it.
          // This bar showed only the page title, so the instructor was the one
          // account that never saw who it was signed in as. The wide layout
          // keeps the plain title: it has its own sidebar identity.
          //
          // The logo is dropped on a phone: with four icons on the right there
          // was not enough width left, so the name truncated to "Hello, Pr..."
          // and the role wrapped onto two lines. The menu button and the header
          // already identify the app.
          if (!isWide)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, ${_userName.isNotEmpty ? _userName.split(' ').first : 'there'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF202124),
                    ),
                  ),
                  const Text(
                    'Instructor Account',
                    // One line, always: it wrapped to "Instructor" / "Account"
                    // when the row ran short of width.
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A73E8),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Image.asset('assets/Asset 1.png', height: 28, fit: BoxFit.contain),
            const SizedBox(width: 6),
            Text(
              titles[_activePage] ?? 'iCare Academy',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w400, color: Color(0xFF202124)),
            ),
            const Spacer(),
          ],
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Color(0xFF444746), size: 22),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InstructorLmsCoursesScreen())),
            tooltip: 'Search courses',
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Color(0xFF444746), size: 22),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DoctorNotifications())),
            tooltip: 'Notifications',
          ),
          // Create class button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Tooltip(
              message: 'Create new class',
              child: InkWell(
                onTap: _createClass,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300, width: 1.5),
                  ),
                  child: const Icon(Icons.add_rounded, size: 20, color: Color(0xFF444746)),
                ),
              ),
            ),
          ),
          // User avatar with popup
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PopupMenuButton<String>(
              offset: const Offset(0, 48),
              child: Builder(
                builder: (_) {
                  // buildProfileImageProvider handles both shapes the API
                  // returns: a base64 data: URI and a server-relative path.
                  final img = buildProfileImageProvider(_userPhoto);
                  return CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF1A73E8),
                    backgroundImage: img,
                    // Keep the initial as the fallback for anyone who has not
                    // uploaded a photo yet.
                    child: img == null
                        ? Text(
                            _userName.isNotEmpty
                                ? _userName[0].toUpperCase()
                                : 'I',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600),
                          )
                        : null,
                  );
                },
              ),
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: false,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_userName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF202124))),
                    Text(_userEmail, style: const TextStyle(fontSize: 12, color: Color(0xFF5F6368))),
                  ]),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'profile',
                  child: Row(children: const [
                    Icon(Icons.manage_accounts_outlined, size: 18, color: Color(0xFF444746)),
                    SizedBox(width: 10),
                    Text('Profile settings'),
                  ]),
                ),
                if (_availableRoles.length > 1)
                  PopupMenuItem(
                    value: 'switch_role',
                    child: Row(children: const [
                      Icon(Icons.swap_horiz_rounded, size: 18, color: Color(0xFF1A73E8)),
                      SizedBox(width: 10),
                      Text('Switch Role', style: TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.w600)),
                    ]),
                  ),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(children: const [
                    Icon(Icons.logout_rounded, size: 18, color: Color(0xFF444746)),
                    SizedBox(width: 10),
                    Text('Sign out'),
                  ]),
                ),
              ],
              onSelected: (val) {
                if (val == 'logout') _logout();
                if (val == 'profile') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const InstructorProfileSetupScreen()));
                }
                if (val == 'switch_role') _showSwitchRoleDialog();
              },
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════
  // SIDEBAR
  // ════════════════════════════════════════════════

  Widget _buildSidebar({required bool isDrawer}) {
    final content = Container(
      width: 256,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── iCare Logo (fixed at top) ──────────────
          if (isDrawer)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Image.asset('assets/Asset 1.png', height: 36, fit: BoxFit.contain),
                    const SizedBox(width: 10),
                    const Text('iCare Academy', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w400, color: Color(0xFF202124))),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Row(
                children: [
                  Image.asset('assets/Asset 1.png', height: 40, fit: BoxFit.contain),
                  const SizedBox(width: 10),
                  const Text('iCare Academy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400, color: Color(0xFF202124))),
                ],
              ),
            ),

          // ── Scrollable nav + courses ─────────────
          Expanded(
            // Same fix as the main sidebar: a Scrollbar with no controller on
            // it or on the scroll view gets no drag recognisers, so the bar
            // was decorative only.
            child: DragScroll(
              builder: (context, lmsSidebarCtrl) => SingleChildScrollView(
                controller: lmsSidebarCtrl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _navItem(Icons.home_rounded, 'Home', _NavPage.home),
                    _navItem(Icons.calendar_today_rounded, 'Calendar', _NavPage.calendar),
                    _navItem(Icons.check_circle_outline_rounded, 'To do', _NavPage.todo),
                    // "All Courses" opened the instructor's OWN course list,
                    // which is what the Taught section below already shows.
                    // The client wanted the whole academy here - every
                    // instructor's courses - so a teacher can find a course and
                    // ask to join it as a co-instructor. Renamed to match.
                    // The instructor's own course list - the only place that
                    // shows their DRAFTS - was replaced by Browse Courses and
                    // went missing. Both belong here: one is their own work,
                    // the other is the whole academy.
                    _navItemExternal(Icons.menu_book_rounded, 'My Courses', () {
                      if (isDrawer) Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const InstructorLmsCoursesScreen()))
                          .then((_) => _loadCourses());
                    }),
                    _navItemExternal(Icons.explore_outlined, 'Browse Courses', () {
                      if (isDrawer) Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const LmsPublicCatalog()))
                          .then((_) => _loadCourses());
                    }),
                    _navItemExternal(Icons.rate_review_outlined, 'Student Feedback', () {
                      if (isDrawer) Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const InstructorFeedbackScreen()));
                    }),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      child: Divider(color: Colors.grey.shade200, height: 1),
                    ),
                    // Taught courses
                    InkWell(
                      onTap: () => setState(() => _taughtExpanded = !_taughtExpanded),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        child: Row(
                          children: [
                            const Text('Taught', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF444746))),
                            const SizedBox(width: 4),
                            Icon(_taughtExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                size: 18, color: const Color(0xFF444746)),
                          ],
                        ),
                      ),
                    ),
                    if (_taughtExpanded)
                      ..._courses.asMap().entries.map((e) {
                        final color = _cardColor(e.key);
                        final title = (e.value['title'] ?? e.value['name'] ?? 'Course').toString();
                        final initial = title.isNotEmpty ? title[0].toUpperCase() : '?';
                        return InkWell(
                          onTap: () {
                            if (isDrawer) Navigator.pop(context);
                            _openCourse(e.value);
                          },
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: Row(
                              children: [
                                CircleAvatar(radius: 14, backgroundColor: color,
                                    child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
                                const SizedBox(width: 12),
                                Expanded(child: Text(title,
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF202124)),
                                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
                        );
                      }),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Divider(color: Colors.grey.shade200, height: 1),
                    ),
                    _navItem(Icons.settings_outlined, 'Settings', _NavPage.settings),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),

          // ── Create class button (fixed at bottom) ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  if (isDrawer) Navigator.pop(context);
                  _createClass();
                },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Create course'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1A73E8),
                  side: const BorderSide(color: Color(0xFF1A73E8)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (isDrawer) {
      return Drawer(width: 256, elevation: 4, child: content);
    }
    return Container(
      decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade200))),
      child: content,
    );
  }

  Widget _navItem(IconData icon, String label, _NavPage page) {
    final isActive = _activePage == page;
    return InkWell(
      onTap: () => setState(() => _activePage = page),
      child: Container(
        margin: const EdgeInsets.only(right: 16, top: 1, bottom: 1),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1A73E8).withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(24), bottomRight: Radius.circular(24),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20,
                color: isActive ? const Color(0xFF1A73E8) : const Color(0xFF444746)),
            const SizedBox(width: 16),
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive ? const Color(0xFF1A73E8) : const Color(0xFF202124))),
          ],
        ),
      ),
    );
  }

  /// Sidebar entry for a destination outside the LMS shell.
  ///
  /// This used to show a trailing "open in new window" arrow, which was a lie:
  /// the target opens in the same tab like every other sidebar item. The client
  /// tried it and nothing new opened — "jab click karti hoon to 'Open New
  /// Window' mein to hota nahi hai, to aise hi open ho rahe hain" — so the
  /// arrow is gone and these rows now look like the rest of the sidebar.
  Widget _navItemExternal(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 16, top: 1, bottom: 1),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF444746)),
            const SizedBox(width: 16),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Color(0xFF202124))),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════
  // BODY ROUTER
  // ════════════════════════════════════════════════

  Widget _buildBody(bool isWide) {
    switch (_activePage) {
      case _NavPage.home:     return _buildHomePage(isWide);
      case _NavPage.calendar: return _CalendarPage(courses: _courses, lms: _lms);
      case _NavPage.todo:     return _TodoPage(courses: _courses, lms: _lms);
      case _NavPage.settings:
        return _SettingsPage(
          userName: _userName, userEmail: _userEmail,
          userPhoto: _userPhoto, onLogout: _logout,
          onManageCourses: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const InstructorLmsCoursesScreen()))
              .then((_) => _loadCourses()),
          onCreateCourse: _createClass,
        );
    }
  }

  // ════════════════════════════════════════════════
  // HOME — course card grid
  // ════════════════════════════════════════════════

  Widget _buildHomePage(bool isWide) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));

    final crossCount = isWide
        ? (MediaQuery.of(context).size.width > 1200 ? 4 : 3)
        : (MediaQuery.of(context).size.width > 560 ? 2 : 1);

    return RefreshIndicator(
      onRefresh: () async {
        await _loadCourses();
        await _loadPendingInvites();
      },
      child: ListView(
        children: [
          ..._pendingInvites.map((inv) => _buildInviteBanner(inv)),
          if (_courses.isEmpty)
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: _buildEmptyHome(),
            )
          else
            GridView.builder(
              padding: const EdgeInsets.all(20),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossCount,
                crossAxisSpacing: 18, mainAxisSpacing: 18,
                childAspectRatio: 1.35,
              ),
              itemCount: _courses.length,
              itemBuilder: (ctx, i) => _buildCourseCard(_courses[i], i),
            ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(dynamic course, int index) {
    final color = _cardColor(index);
    final title = (course['title'] ?? course['name'] ?? 'Untitled').toString();
    final section = (course['category'] ?? course['section'] ?? '').toString();
    final enrolledCount = ((course['enrolledCount'] ?? 0) as num).toInt();
    final isPublished = course['isPublished'] == true || course['visibility'] == 'public';

    return GestureDetector(
      onTap: () => _openCourse(course),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDADCE0)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            // ── Colored header ──
            Expanded(
              flex: 6,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                            child: CustomPaint(painter: _DiagonalPatternPainter(Colors.white.withValues(alpha: 0.12))),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 58, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500, height: 1.3),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              if (section.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(section, style: const TextStyle(color: Colors.white70, fontSize: 11),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                              const SizedBox(height: 4),
                              Text(_userName, style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Instructor avatar overlapping
                  Positioned(
                    right: 12, bottom: -20,
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: _avatarColor(index),
                      child: Text(
                        _userName.isNotEmpty ? _userName[0].toUpperCase() : 'I',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── White bottom ──
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Published badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isPublished ? const Color(0xFFE6F4EA) : const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isPublished ? 'Published' : 'Draft',
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: isPublished ? const Color(0xFF188038) : const Color(0xFFE37400),
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Students count — opens directly to the People tab
                    _cardIconButton(Icons.people_outlined, enrolledCount > 0 ? '$enrolledCount' : null,
                        () => _openCourseAtTab(course, 2)),
                    // More menu (settings) — only button kept
                    _cardMoreButton(course),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _avatarColor(int i) {
    const c = [Color(0xFF1558D6), Color(0xFF137333), Color(0xFF7B1FA2), Color(0xFFBF360C),
                Color(0xFF00695C), Color(0xFF880E4F), Color(0xFF004D40), Color(0xFF311B92)];
    return c[i % c.length];
  }

  Widget _cardIconButton(IconData icon, String? badge, VoidCallback onTap) {
    return Stack(
      children: [
        IconButton(
          icon: Icon(icon, size: 20, color: const Color(0xFF444746)),
          onPressed: onTap,
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        if (badge != null && badge != '0')
          Positioned(
            top: 2, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: const Color(0xFF1A73E8), borderRadius: BorderRadius.circular(10)),
              child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }

  Widget _cardMoreButton(dynamic course) {
    final courseId = course['_id']?.toString() ?? '';
    final title = course['title']?.toString() ?? 'Course';
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFF444746)),
      iconSize: 20,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'open',
            child: _PopupItem(Icons.open_in_new_rounded, 'Open class')),
        const PopupMenuItem(value: 'students',
            child: _PopupItem(Icons.people_outlined, 'View students')),
        const PopupMenuItem(value: 'analytics',
            child: _PopupItem(Icons.analytics_outlined, 'Analytics')),
        const PopupMenuItem(value: 'edit',
            child: _PopupItem(Icons.edit_outlined, 'Edit Course')),
      ],
      onSelected: (val) {
        if (val == 'open') _openCourse(course);
        if (val == 'students' && courseId.isNotEmpty) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => InstructorStudentProgressScreen(courseId: courseId, courseTitle: title),
          ));
        }
        if (val == 'analytics' && courseId.isNotEmpty) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => InstructorCourseAnalyticsScreen(courseId: courseId, courseTitle: title),
          ));
        }
        if (val == 'edit' && courseId.isNotEmpty) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => InstructorCourseContentScreen(courseId: courseId),
          )).then((_) => _loadCourses());
        }
      },
    );
  }

  Widget _buildEmptyHome() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120, height: 120,
            decoration: const BoxDecoration(color: Color(0xFFE8F0FE), shape: BoxShape.circle),
            child: const Icon(Icons.class_outlined, size: 56, color: Color(0xFF1A73E8)),
          ),
          const SizedBox(height: 24),
          const Text('Add a class to get started',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w400, color: Color(0xFF202124))),
          const SizedBox(height: 12),
          const Text('Create your first class to start teaching.',
              style: TextStyle(fontSize: 14, color: Color(0xFF5F6368))),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _createClass,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create course'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Diagonal pattern painter for card headers
// ─────────────────────────────────────────────────────────────

class _DiagonalPatternPainter extends CustomPainter {
  final Color color;
  _DiagonalPatternPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke;
    for (double i = -size.height; i < size.width + size.height; i += 18) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), p);
    }
  }
  @override
  bool shouldRepaint(_DiagonalPatternPainter o) => o.color != color;
}

enum _NavPage { home, calendar, todo, settings }

// ─────────────────────────────────────────────────────────────
// CALENDAR PAGE — shows real assignment due dates
// ─────────────────────────────────────────────────────────────

class _CalendarPage extends StatefulWidget {
  final List<dynamic> courses;
  final LmsService lms;
  const _CalendarPage({required this.courses, required this.lms});
  @override
  State<_CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<_CalendarPage> {
  DateTime _weekStart = _mondayOf(DateTime.now());
  // Map of date string (yyyy-MM-dd) → list of items
  Map<String, List<Map<String, dynamic>>> _events = {};
  bool _loading = true;
  String _selectedCourse = 'All classes';
  List<String> _courseNames = ['All classes'];

  static DateTime _mondayOf(DateTime d) {
    return DateTime(d.year, d.month, d.day - (d.weekday - 1));
  }

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    final events = <String, List<Map<String, dynamic>>>{};
    final names = <String>['All classes'];

    for (final course in widget.courses) {
      final id = course['_id']?.toString() ?? '';
      final name = (course['title'] ?? course['name'] ?? '').toString();
      if (id.isEmpty) continue;
      names.add(name);

      try {
        final assignments = await widget.lms.getCourseAssignments(id);
        for (final a in assignments) {
          final dueStr = a['dueDate']?.toString() ?? '';
          if (dueStr.isEmpty) continue;
          try {
            final dt = parseServerTimeOr(dueStr, DateTime.now());
            final key = DateFormat('yyyy-MM-dd').format(dt);
            events.putIfAbsent(key, () => []).add({
              'title': a['title'] ?? 'Assignment',
              'course': name,
              'type': 'assignment',
              'color': const Color(0xFF1A73E8),
            });
          } catch (_) {}
        }
      } catch (_) {}

      try {
        final sessions = await widget.lms.getCourseSessions(id);
        for (final s in sessions) {
          final dateStr = s['scheduledAt']?.toString() ?? s['date']?.toString() ?? '';
          if (dateStr.isEmpty) continue;
          try {
            final dt = parseServerTimeOr(dateStr, DateTime.now());
            final key = DateFormat('yyyy-MM-dd').format(dt);
            events.putIfAbsent(key, () => []).add({
              'title': s['title'] ?? 'Live Session',
              'course': name,
              // "kis course ka hai, KAB hai, kiska hai" - a live session has a
              // real start time, so show it. Assignments only carry a due date.
              'time': DateFormat('h:mm a').format(dt),
              'type': 'session',
              'color': const Color(0xFF188038),
            });
          } catch (_) {}
        }
      } catch (_) {}
    }

    if (mounted) setState(() { _events = events; _courseNames = names; _loading = false; });
  }

  String _formatRange() {
    final end = _weekStart.add(const Duration(days: 6));
    if (_weekStart.month == end.month) {
      return '${DateFormat('MMM d').format(_weekStart)} – ${DateFormat('d, yyyy').format(end)}';
    }
    return '${DateFormat('MMM d').format(_weekStart)} – ${DateFormat('MMM d, yyyy').format(end)}';
  }

  List<Map<String, dynamic>> _eventsForDay(DateTime day) {
    final key = DateFormat('yyyy-MM-dd').format(day);
    final all = _events[key] ?? [];
    if (_selectedCourse == 'All classes') return all;
    return all.where((e) => e['course'] == _selectedCourse).toList();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(7, (i) => _weekStart.add(Duration(days: i)));
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(
      children: [
        // Controls
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              // Course filter
              Flexible(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedCourse,
                  underline: Container(height: 1, color: const Color(0xFFDADCE0)),
                  style: const TextStyle(fontSize: 14, color: Color(0xFF202124)),
                  items: _courseNames.map((n) => DropdownMenuItem(value: n, child: Text(n, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setState(() => _selectedCourse = v!),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _weekStart = _mondayOf(DateTime.now())),
                child: const Text('Today', style: TextStyle(fontSize: 13, color: Color(0xFF1A73E8))),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF444746)),
                onPressed: () => setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7))),
              ),
              Text(_formatRange(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF202124))),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF444746)),
                onPressed: () => setState(() => _weekStart = _weekStart.add(const Duration(days: 7))),
              ),
            ],
          ),
        ),
        // Day headers
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200), bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: List.generate(7, (i) {
              final day = days[i];
              final isToday = day.day == today.day && day.month == today.month && day.year == today.year;
              return Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(border: Border(right: BorderSide(color: i < 6 ? Colors.grey.shade200 : Colors.transparent))),
                  child: Column(
                    children: [
                      Text(labels[i], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF70757A), letterSpacing: 0.3)),
                      const SizedBox(height: 4),
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: isToday ? const Color(0xFF1A73E8) : Colors.transparent, shape: BoxShape.circle),
                        child: Center(child: Text('${day.day}',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: isToday ? Colors.white : const Color(0xFF202124)))),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        // Events body
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(7, (i) {
                    final dayEvents = _eventsForDay(days[i]);
                    return Expanded(
                      child: Container(
                        decoration: BoxDecoration(border: Border(right: BorderSide(color: i < 6 ? Colors.grey.shade100 : Colors.transparent))),
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: dayEvents.map((e) => Container(
                            margin: const EdgeInsets.only(bottom: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: (e['color'] as Color).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                              border: Border(left: BorderSide(color: e['color'] as Color, width: 3)),
                            ),
                            // The course name was already carried on every
                            // event but never rendered, so a week of entries
                            // gave no clue which course they belonged to -
                            // "iska NAAM hona chahiye na - COURSE ka naam.
                            // Kis course ka hai, kab hai, kiska hai?"
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(e['title'] as String,
                                    style: TextStyle(fontSize: 11, color: e['color'] as Color, fontWeight: FontWeight.w600),
                                    maxLines: 2, overflow: TextOverflow.ellipsis),
                                if ((e['course'] as String?)?.trim().isNotEmpty ?? false) ...[
                                  const SizedBox(height: 1),
                                  Text(e['course'] as String,
                                      style: TextStyle(
                                          fontSize: 9.5,
                                          color: (e['color'] as Color).withValues(alpha: 0.8),
                                          fontWeight: FontWeight.w400),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                                if ((e['time'] as String?)?.trim().isNotEmpty ?? false)
                                  Text(e['time'] as String,
                                      style: TextStyle(
                                          fontSize: 9.5,
                                          color: (e['color'] as Color).withValues(alpha: 0.7)),
                                      maxLines: 1),
                              ],
                            ),
                          )).toList(),
                        ),
                      ),
                    );
                  }),
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TO-DO PAGE — real pending assignments to grade
// ─────────────────────────────────────────────────────────────

class _TodoPage extends StatefulWidget {
  final List<dynamic> courses;
  final LmsService lms;
  const _TodoPage({required this.courses, required this.lms});
  @override
  State<_TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<_TodoPage> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _toReview = []; // assignments with submissions to grade
  List<Map<String, dynamic>> _upcoming = []; // upcoming due dates
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadItems();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    final toReview = <Map<String, dynamic>>[];
    final upcoming = <Map<String, dynamic>>[];
    final now = DateTime.now();

    for (final course in widget.courses) {
      final id = course['_id']?.toString() ?? '';
      final name = (course['title'] ?? course['name'] ?? '').toString();
      if (id.isEmpty) continue;
      try {
        final assignments = await widget.lms.getCourseAssignments(id);
        for (final a in assignments) {
          final submissionCount = ((a['submissionCount'] ?? 0) as num).toInt();
          final gradedCount = ((a['gradedCount'] ?? 0) as num).toInt();
          final pending = submissionCount - gradedCount;
          if (pending > 0) {
            toReview.add({...Map<String, dynamic>.from(a), '_courseName': name, '_pendingGrading': pending});
          }
          // Upcoming due
          final dueStr = a['dueDate']?.toString() ?? '';
          if (dueStr.isNotEmpty) {
            try {
              final dt = parseServerTimeOr(dueStr, DateTime.now());
              if (dt.isAfter(now)) {
                upcoming.add({...Map<String, dynamic>.from(a), '_courseName': name});
              }
            } catch (_) {}
          }
        }
      } catch (_) {}
    }

    upcoming.sort((a, b) {
      final ad = _d(a['dueDate']?.toString() ?? '');
      final bd = _d(b['dueDate']?.toString() ?? '');
      if (ad == null || bd == null) return 0;
      return ad.compareTo(bd);
    });

    if (mounted) setState(() { _toReview = toReview; _upcoming = upcoming; _loading = false; });
  }

  DateTime? _d(String s) { try { return parseServerTimeOr(s, DateTime.now()); } catch (_) { return null; } }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabs,
            isScrollable: false,
            labelColor: const Color(0xFF1A73E8),
            unselectedLabelColor: const Color(0xFF444746),
            indicatorColor: const Color(0xFF1A73E8),
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
            tabs: [
              Tab(text: _toReview.isEmpty ? 'To Review' : 'To Review (${_toReview.length})'),
              Tab(text: 'Upcoming Deadlines'),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _buildToReviewList(),
                    _buildUpcomingList(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildToReviewList() {
    if (_toReview.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('All caught up!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400, color: Color(0xFF202124))),
          const SizedBox(height: 8),
          const Text('No submissions waiting to be graded.', style: TextStyle(fontSize: 14, color: Color(0xFF5F6368))),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _toReview.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F3F4)),
      itemBuilder: (ctx, i) {
        final item = _toReview[i];
        final pending = item['_pendingGrading'] as int;
        final id = item['_id']?.toString() ?? '';
        final title = item['title']?.toString() ?? 'Assignment';
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          leading: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: const Color(0xFF1A73E8).withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.assignment_outlined, color: Color(0xFF1A73E8), size: 20),
          ),
          title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF202124))),
          subtitle: Text('${item['_courseName']}  ·  $pending submission${pending > 1 ? 's' : ''} to grade',
              style: const TextStyle(fontSize: 12, color: Color(0xFF5F6368))),
          trailing: id.isNotEmpty
              ? ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => InstructorGradingScreen(assignmentId: id, assignmentTitle: title),
                  )),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    elevation: 0, textStyle: const TextStyle(fontSize: 13),
                  ),
                  child: const Text('Grade'),
                )
              : null,
        );
      },
    );
  }

  Widget _buildUpcomingList() {
    if (_upcoming.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.event_note_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No upcoming deadlines', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Color(0xFF5F6368))),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _upcoming.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F3F4)),
      itemBuilder: (ctx, i) {
        final item = _upcoming[i];
        final due = _d(item['dueDate']?.toString() ?? '');
        final dueLabel = due != null ? DateFormat('EEE, MMM d').format(due) : '';
        final daysLeft = due != null ? due.difference(DateTime.now()).inDays : 0;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          leading: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: daysLeft <= 2 ? const Color(0xFFF44336).withValues(alpha: 0.1) : const Color(0xFF1A73E8).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.assignment_outlined,
                color: daysLeft <= 2 ? const Color(0xFFF44336) : const Color(0xFF1A73E8), size: 20),
          ),
          title: Text(item['title']?.toString() ?? 'Assignment',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF202124))),
          subtitle: Text('${item['_courseName']}', style: const TextStyle(fontSize: 12, color: Color(0xFF5F6368))),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(dueLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF202124))),
              Text(daysLeft == 0 ? 'Due today' : daysLeft == 1 ? 'Tomorrow' : '$daysLeft days left',
                  style: TextStyle(fontSize: 11, color: daysLeft <= 2 ? const Color(0xFFF44336) : const Color(0xFF5F6368))),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SETTINGS PAGE
// ─────────────────────────────────────────────────────────────

class _SettingsPage extends StatefulWidget {
  final String userName;
  final String userEmail;
  // The header avatar shows the instructor's photo; this page was still
  // drawing an initial because the photo was never passed down to it.
  final String? userPhoto;
  final VoidCallback onLogout;
  final VoidCallback onManageCourses;
  final VoidCallback onCreateCourse;
  const _SettingsPage({required this.userName, required this.userEmail,
      this.userPhoto, required this.onLogout,
      required this.onManageCourses, required this.onCreateCourse});
  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  bool _emailNotifs = true;
  bool _commentNotifs = true;
  bool _workNotifs = true;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const Text('Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w400, color: Color(0xFF202124))),
        const SizedBox(height: 20),
        Row(
          children: [
            Builder(builder: (_) {
              final img = buildProfileImageProvider(widget.userPhoto);
              return CircleAvatar(
                radius: 32,
                backgroundColor: const Color(0xFF1A73E8),
                backgroundImage: img,
                child: img == null
                    ? Text(
                        widget.userName.isNotEmpty
                            ? widget.userName[0].toUpperCase()
                            : 'I',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w400))
                    : null,
              );
            }),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.userName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF202124))),
                Text(widget.userEmail, style: const TextStyle(fontSize: 13, color: Color(0xFF5F6368))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InstructorProfileSetupScreen())),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFDADCE0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Edit profile', style: TextStyle(fontSize: 13, color: Color(0xFF1A73E8))),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: widget.onLogout,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFDADCE0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Sign out', style: TextStyle(fontSize: 13, color: Color(0xFF5F6368))),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 32),
        Divider(color: Colors.grey.shade200),
        const SizedBox(height: 20),
        const Text('Notifications', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w400, color: Color(0xFF202124))),
        const SizedBox(height: 16),
        _settingToggle('Allow email notifications', 'Receive class updates via email', _emailNotifs,
            (v) => setState(() => _emailNotifs = v)),
        _settingToggle('Comments', 'Notify me when students comment on my posts', _commentNotifs,
            (v) => setState(() => _commentNotifs = v)),
        _settingToggle('Assignment submissions', 'Notify me when students submit work', _workNotifs,
            (v) => setState(() => _workNotifs = v)),
        const SizedBox(height: 32),
        Divider(color: Colors.grey.shade200),
        const SizedBox(height: 20),
        const Text('Class settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w400, color: Color(0xFF202124))),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.add_box_outlined, color: Color(0xFF1A73E8)),
          title: const Text('Create a new class', style: TextStyle(fontSize: 14, color: Color(0xFF1A73E8))),
          onTap: widget.onCreateCourse,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.list_alt_outlined, color: Color(0xFF444746)),
          title: const Text('Manage all courses', style: TextStyle(fontSize: 14, color: Color(0xFF202124))),
          onTap: widget.onManageCourses,
        ),

        const SizedBox(height: 32),
        Divider(color: Colors.grey.shade200),
        const SizedBox(height: 20),
        const Text('Discount Vouchers', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w400, color: Color(0xFF202124))),
        const SizedBox(height: 8),
        const Text('One-time codes: money off, or installments for a single student', style: TextStyle(fontSize: 13, color: Color(0xFF5F6368))),
        const SizedBox(height: 16),
        VoucherManagerWidget(),
      ],
    );
  }

  Widget _settingToggle(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, color: Color(0xFF202124))),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF5F6368))),
              ],
            ),
          ),
          Switch(value: value, activeThumbColor: const Color(0xFF1A73E8), onChanged: onChanged),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Voucher Manager
// ─────────────────────────────────────────────────────────────

class VoucherManagerWidget extends StatefulWidget {
  const VoucherManagerWidget({super.key});
  @override
  State<VoucherManagerWidget> createState() => _VoucherManagerState();
}

class _VoucherManagerState extends State<VoucherManagerWidget> {
  final LmsService _lms = LmsService();
  List<dynamic> _vouchers = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final v = await _lms.getVouchers();
    if (mounted) setState(() { _vouchers = v; _loading = false; });
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Future<void> _createVoucher() async {
    int selectedPercent = 20;
    // 'discount' | 'installment'. An installment code has to name its course:
    // the schedule lives on the course, so "any course" cannot mean anything.
    String kind = 'discount';
    String? selectedCourseId;
    List<dynamic> courses = [];
    try {
      final res = await _lms.getInstructorCourses();
      courses = res['courses'] ?? [];
    } catch (_) {}
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.local_offer_rounded, color: Color(0xFF1A73E8)),
          SizedBox(width: 10),
          Text('Create Voucher', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'discount', label: Text('Discount')),
              ButtonSegment(value: 'installment', label: Text('Installments')),
            ],
            selected: {kind},
            onSelectionChanged: (v) => setLocal(() => kind = v.first),
          ),
          const SizedBox(height: 16),
          if (kind == 'installment') ...[
            const Text('Which course is this for?', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedCourseId,
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
              hint: const Text('Select a course'),
              items: courses
                  .map((c) => DropdownMenuItem<String>(
                        value: c['_id']?.toString(),
                        child: Text(c['title']?.toString() ?? 'Untitled',
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setLocal(() => selectedCourseId = v),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text(
                'The student who redeems this code can pay this course in the '
                'installments you set up on it, instead of all at once.',
                style: TextStyle(fontSize: 11, color: Colors.indigo.shade900),
              ),
            ),
          ] else ...[
          const Text('Select discount percentage for this one-time voucher:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [10,20,30,40,50,60,70,80,90,100].map((p) => GestureDetector(
              onTap: () => setLocal(() => selectedPercent = p),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selectedPercent == p ? const Color(0xFF1A73E8) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: selectedPercent == p ? const Color(0xFF1A73E8) : Colors.grey.shade300),
                ),
                child: Text('$p%', style: TextStyle(
                  color: selectedPercent == p ? Colors.white : const Color(0xFF444746),
                  fontWeight: FontWeight.w700, fontSize: 13,
                )),
              ),
            )).toList(),
          ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.info_outline, color: Color(0xFF1A73E8), size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('One-time use only — code is deactivated after first use.',
                style: TextStyle(fontSize: 11, color: Colors.blue.shade800))),
            ]),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white),
            onPressed: () async {
              if (kind == 'installment' && selectedCourseId == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Pick the course this installment code is for'),
                  backgroundColor: Colors.red,
                ));
                return;
              }
              Navigator.pop(ctx);
              final code = _generateCode();
              final result = await _lms.createVoucher(
                code: code,
                discount: selectedPercent,
                kind: kind,
                courseId: kind == 'installment' ? selectedCourseId : null,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(result['success'] == true
                      ? (kind == 'installment'
                          ? 'Installment voucher created: $code'
                          : 'Voucher created: $code ($selectedPercent% off)')
                      : result['message'] ?? 'Failed'),
                  backgroundColor: result['success'] == true ? Colors.green : Colors.red,
                  duration: const Duration(seconds: 4),
                ));
                if (result['success'] == true) _load();
              }
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Generate'),
          ),
        ],
      )),
    );
  }

  Future<void> _deleteVoucher(String id, String code) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Voucher'),
        content: Text('Delete voucher "$code"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final result = await _lms.deleteVoucher(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['success'] == true ? 'Voucher deleted.' : result['message'] ?? 'Failed'),
        backgroundColor: result['success'] == true ? Colors.green : Colors.red,
      ));
      if (result['success'] == true) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ElevatedButton.icon(
        onPressed: _createVoucher,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Create New Discount Voucher'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      if (_vouchers.isEmpty) ...[
        const SizedBox(height: 24),
        const Center(child: Text('No vouchers yet.', style: TextStyle(color: Color(0xFF94A3B8)))),
      ] else ...[
        const SizedBox(height: 16),
        ..._vouchers.map((v) {
          final isUsed = v['usedBy'] != null;
          final id = v['_id']?.toString() ?? '';
          final code = v['code']?.toString() ?? '';
          final discount = v['discount'] ?? 0;
          final createdAt = v['createdAt'] != null
              ? DateFormat('MMM d, yyyy').format(parseServerTime(v['createdAt'].toString()) ?? DateTime.now())
              : '';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isUsed ? Colors.grey.shade100 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isUsed ? Colors.grey.shade200 : Colors.green.shade200),
            ),
            child: Row(children: [
              Icon(Icons.local_offer_rounded, size: 18, color: isUsed ? Colors.grey : Colors.green.shade700),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(code, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1A73E8))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF1A73E8), borderRadius: BorderRadius.circular(10)),
                    child: Text('$discount% OFF', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ]),
                Text('$createdAt · ${isUsed ? 'Used' : 'Active — one-time use'}',
                    style: TextStyle(fontSize: 11, color: isUsed ? Colors.grey : Colors.green.shade700)),
              ])),
              if (!isUsed)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                  tooltip: 'Delete',
                  onPressed: () => _deleteVoucher(id, code),
                ),
            ]),
          );
        }),
      ],
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// Helper widget
// ─────────────────────────────────────────────────────────────

class _PopupItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PopupItem(this.icon, this.label);
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF444746)),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF202124))),
      ],
    );
  }
}

