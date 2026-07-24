import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icare/screens/assignment_submit_screen.dart';
import 'package:icare/screens/quiz_take_screen.dart';
import 'package:icare/screens/instructor_create_assignment_screen.dart';
import 'package:icare/screens/instructor_create_quiz_screen.dart';
import 'package:icare/screens/instructor_schedule_session_screen.dart';
import 'package:icare/screens/instructor_grading_screen.dart';
import 'package:icare/screens/instructor_course_content_screen.dart';
import 'package:icare/screens/lesson_detail_page.dart';
import 'package:icare/screens/doctor_notifications.dart';
import 'package:icare/screens/instructor_assignments_list_screen.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/screens/lms_live_session_screen.dart';
import 'package:icare/screens/installment_schedule_screen.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────
// Google Classroom-style inside-course view
// Works for students and instructors
// ─────────────────────────────────────────────────────────────

class ClassroomCourseView extends StatefulWidget {
  final Map<String, dynamic> course;
  final String? enrollmentId;
  final bool isInstructor;
  final int initialTab;

  const ClassroomCourseView({
    super.key,
    required this.course,
    this.enrollmentId,
    this.isInstructor = false,
    this.initialTab = 0,
  });

  @override
  State<ClassroomCourseView> createState() => _ClassroomCourseViewState();
}

class _ClassroomCourseViewState extends State<ClassroomCourseView>
    with TickerProviderStateMixin {
  late TabController _tabs;
  final LmsService _lms = LmsService();

  List<dynamic> _announcements = [];
  bool _loadingStream = true;
  final TextEditingController _postCtrl = TextEditingController();

  List<dynamic> _assignments = [];
  List<dynamic> _quizzes = [];
  List<dynamic> _sessions = [];
  bool _loadingClasswork = true;

  // Course modules (for Course Content tab)
  List<dynamic> _modules = [];
  bool _loadingModules = true;
  String _courseType = 'self-paced';
  String? _lockReason;
  bool _installmentPlanEnabled = false;
  List<dynamic> _installments = [];

  // Key to reach embedded course content screen's add-module action
  final _embeddedContentKey = GlobalKey<_EmbeddedCourseContentState>();

  List<dynamic> _students = [];
  bool _loadingPeople = true;

  // Student grades & attendance
  List<dynamic> _myGrades = [];
  List<dynamic> _myQuizAttempts = [];
  Map<String, dynamic>? _myAttendance;
  bool _loadingGrades = true;

  // Instructor attendance report
  Map<String, dynamic> _attendanceReport = {};
  bool _loadingAttendanceReport = false;

  // Live session detection
  bool _isSessionLive = false;
  Timer? _livePoller;
  // Suppresses the "instructor just went LIVE" SnackBar on the very first
  // poll — that check just reflects whatever the session's state already
  // was when this screen opened, not a fresh "just went live" event. The
  // FAB + Stream-tab banner already make an already-live session visible
  // without an extra transient alert stacked on top of them.
  bool _firstLiveCheck = true;

  String get _courseId => widget.course['_id']?.toString() ?? '';
  String get _courseTitle =>
      widget.course['title'] ?? widget.course['name'] ?? 'Course';
  String get _section =>
      widget.course['category'] ?? widget.course['section'] ?? '';

  // Same color set as the card colors in the dashboard
  static const List<Color> _bannerColors = [
    Color(0xFF1A73E8),
    Color(0xFF188038),
    Color(0xFF9334E6),
    Color(0xFFE37400),
    Color(0xFF1E7E34),
    Color(0xFFB3261E),
    Color(0xFF006064),
    Color(0xFF4527A0),
  ];

  Color get _bannerColor {
    final t = _courseTitle;
    final idx = t.isNotEmpty ? t.codeUnitAt(0) % _bannerColors.length : 0;
    return _bannerColors[idx];
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
    _tabs.addListener(() => setState(() {}));
    _loadStream();
    _loadClasswork();
    _loadPeople();
    _loadModules();
    // Poll for live session every 10s (students only)
    if (!widget.isInstructor) {
      _startLivePolling();
      _loadStudentGrades();
    } else {
      _loadAttendanceReport();
    }
  }

  void _startLivePolling() {
    _checkLiveSession();
    _livePoller = Timer.periodic(const Duration(seconds: 5), (_) => _checkLiveSession());
  }

  Future<void> _checkLiveSession() async {
    if (_courseId.isEmpty || !mounted) return;
    try {
      final result = await _lms.checkActiveLiveSession(_courseId);
      final wasFirstCheck = _firstLiveCheck;
      _firstLiveCheck = false;
      if (mounted && result['isLive'] != _isSessionLive) {
        setState(() => _isSessionLive = result['isLive'] == true);
        // Show the "just went live" alert only when this is a real
        // transition witnessed while the screen was already open — not on
        // the first poll, which just reports whatever state the session
        // was already in (avoids stacking a SnackBar on top of the FAB and
        // Stream-tab banner that already show an already-live session).
        if (_isSessionLive && !wasFirstCheck) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Row(children: [
              Icon(Icons.live_tv_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text('🔴 Your instructor just went LIVE! Tap to join.', style: TextStyle(fontWeight: FontWeight.w700)),
            ]),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'JOIN NOW',
              textColor: Colors.white,
              onPressed: _joinLiveClass,
            ),
          ));
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabs.dispose();
    _postCtrl.dispose();
    _livePoller?.cancel();
    super.dispose();
  }

  Future<void> _loadStream() async {
    if (_courseId.isEmpty) { setState(() => _loadingStream = false); return; }
    setState(() => _loadingStream = true);
    try {
      final data = await _lms.getCourseAnnouncements(_courseId);
      if (mounted) setState(() { _announcements = data; _loadingStream = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingStream = false);
    }
  }

  Future<void> _loadClasswork() async {
    if (_courseId.isEmpty) { setState(() => _loadingClasswork = false); return; }
    setState(() => _loadingClasswork = true);
    try {
      final a = await _lms.getCourseAssignments(_courseId);
      final q = await _lms.getCourseQuizzes(_courseId);
      final s = await _lms.getCourseSessions(_courseId);
      if (mounted) {
        setState(() {
          _assignments = a; _quizzes = q; _sessions = s;
          _loadingClasswork = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingClasswork = false);
    }
  }

  Future<void> _loadPeople() async {
    if (_courseId.isEmpty) { setState(() => _loadingPeople = false); return; }
    setState(() => _loadingPeople = true);
    try {
      final data = await _lms.getEnrolledStudents(_courseId);
      if (mounted) setState(() { _students = data; _loadingPeople = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingPeople = false);
    }
  }

  Future<void> _loadModules() async {
    if (_courseId.isEmpty) { setState(() => _loadingModules = false); return; }
    setState(() => _loadingModules = true);
    try {
      final results = await Future.wait([
        _lms.getCourseDetails(_courseId),
        _lms.getCourseAssignments(_courseId).catchError((_) => <dynamic>[]),
        _lms.getCourseQuizzes(_courseId).catchError((_) => <dynamic>[]),
        _lms.getCourseSessions(_courseId).catchError((_) => <dynamic>[]),
      ]);
      dynamic parsed = results[0];
      if (parsed is String && parsed.isNotEmpty) {
        try { parsed = jsonDecode(parsed); } catch (_) {}
      }
      final course = parsed is Map ? (parsed['course'] ?? parsed) : {};
      final mods = (course is Map ? course['modules'] : null) ?? [];
      if (mounted) setState(() {
        _modules = List<dynamic>.from(mods);
        _courseType = (course is Map ? course['courseType']?.toString() : null) ?? 'self-paced';
        _lockReason = course is Map ? course['lockReason']?.toString() : null;
        _installmentPlanEnabled = (course is Map ? course['installmentPlanEnabled'] as bool? : null) ?? false;
        _installments = (course is Map ? course['installments'] as List? : null) ?? [];
        // Also update assignments/quizzes/sessions for Course Content tab
        if (results[1] is List) _assignments = results[1] as List;
        if (results[2] is List) _quizzes = results[2] as List;
        if (results[3] is List) _sessions = results[3] as List;
        _loadingModules = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingModules = false);
    }
  }

  Future<void> _loadStudentGrades() async {
    if (_courseId.isEmpty) { setState(() => _loadingGrades = false); return; }
    setState(() => _loadingGrades = true);
    try {
      final grades = await _lms.getMyGrades(_courseId);
      final attendance = await _lms.getMyAttendance(_courseId);
      // Fetch the latest attempt for each quiz in this course
      final quizList = await _lms.getCourseQuizzes(_courseId);
      final attempts = <dynamic>[];
      for (final q in quizList) {
        final qId = q['_id']?.toString() ?? '';
        if (qId.isEmpty) continue;
        final qAttempts = await _lms.getMyQuizAttempts(qId);
        if (qAttempts.isNotEmpty) {
          // Add the most recent attempt, tagged with quiz title
          final latest = Map<String, dynamic>.from(qAttempts.first is Map ? qAttempts.first : {});
          latest['quizTitle'] = q['title']?.toString() ?? 'Quiz';
          attempts.add(latest);
        }
      }
      if (mounted) {
        setState(() {
          _myGrades = grades;
          _myQuizAttempts = attempts;
          _myAttendance = (attendance['total'] as num? ?? 0) > 0 ? attendance : null;
          _loadingGrades = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingGrades = false);
    }
  }

  Future<void> _postAnnouncement() async {
    final text = _postCtrl.text.trim();
    if (text.isEmpty || _courseId.isEmpty) return;
    try {
      final result = await _lms.postAnnouncement(_courseId, text);
      if (result['success'] == false) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${result['message'] ?? 'Unknown error'}'), backgroundColor: Colors.red),
        );
        }
        return;
      }
      _postCtrl.clear();
      await _loadStream();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Announcement posted!'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
      );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post: $e'), backgroundColor: Colors.red),
      );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 840;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      floatingActionButton: !widget.isInstructor && _isSessionLive
          ? FloatingActionButton.extended(
              onPressed: _joinLiveClass,
              backgroundColor: Colors.red,
              icon: const Icon(Icons.live_tv_rounded, color: Colors.white),
              label: const Text(
                'Join Live Session',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            )
          : widget.isInstructor
              ? FloatingActionButton.extended(
                  onPressed: _showCreateMenu,
                  backgroundColor: const Color(0xFF1A73E8),
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  label: const Text('Create',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                )
              : null,
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildStreamTab(isWide),
          _buildCourseContentTab(isWide),
          widget.isInstructor ? _buildPeopleTab(isWide) : _buildStudentGradesTab(),
          widget.isInstructor ? _buildGradesTab() : _buildPeopleTab(isWide),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════
  // APPBAR — breadcrumb style like Google Classroom
  // ════════════════════════════════════════════════

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.grey.shade200,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF444746)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Text(
              'Classroom',
              style: TextStyle(
                fontSize: 18,
                color: Color(0xFF444746),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.chevron_right_rounded,
                size: 18, color: Color(0xFF9AA0A6)),
          ),
          Flexible(
            child: Text(
              _courseTitle,
              style: const TextStyle(
                fontSize: 18,
                color: Color(0xFF202124),
                fontWeight: FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        if (widget.isInstructor)
          IconButton(
            icon: const Icon(Icons.notifications_outlined,
                color: Color(0xFF444746), size: 20),
            tooltip: 'Notifications',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const DoctorNotifications(),
            )),
          ),
        // Settings only (Edit Course content)
        if (widget.isInstructor)
          IconButton(
            icon: const Icon(Icons.settings_outlined,
                color: Color(0xFF444746), size: 20),
            tooltip: 'Course Settings',
            onPressed: () {
              if (_courseId.isNotEmpty) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => InstructorCourseContentScreen(courseId: _courseId),
                ));
              }
            },
          ),
      ],
      bottom: TabBar(
        controller: _tabs,
        labelColor: const Color(0xFF1A73E8),
        unselectedLabelColor: const Color(0xFF444746),
        indicatorColor: const Color(0xFF1A73E8),
        indicatorWeight: 3,
        labelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        unselectedLabelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        tabs: [
          const Tab(text: 'Announcement'),
          const Tab(text: 'Course Content'),
          Tab(text: widget.isInstructor ? 'People' : 'Grades'),
          Tab(text: widget.isInstructor ? 'Grades' : 'People'),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════
  // STREAM TAB — banner + upcoming + feed
  // ════════════════════════════════════════════════

  Future<void> _joinLiveClass() async {
    if (!mounted) return;
    // ScaffoldMessenger is shared app-wide by default (MaterialApp provides
    // one), so a "just went LIVE" SnackBar queued here would otherwise
    // still be showing — overlapping its own text — once we've navigated
    // into LmsLiveSessionScreen a moment later.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final courseId = widget.course['_id']?.toString() ?? '';
    if (courseId.isEmpty) return;

    String sessionId = '';
    bool isLive = false;

    // First check: get live session from backend
    try {
      final result = await _lms.checkActiveLiveSession(courseId);
      isLive = result['isLive'] == true;
      final sid = result['session']?['_id']?.toString() ?? '';
      if (sid.isNotEmpty && sid != courseId) sessionId = sid;
    } catch (_) {}

    if (!mounted) return;
    if (!isLive) {
      // Update local state so FAB hides immediately
      if (_isSessionLive) setState(() => _isSessionLive = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No live session right now. Check back when your instructor goes live.'),
        backgroundColor: Color(0xFF64748B),
        duration: Duration(seconds: 3),
      ));
      return;
    }

    // If session ID is still missing, retry once after a short delay (instructor may be mid-setup)
    if (sessionId.isEmpty) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      try {
        final retry = await _lms.checkActiveLiveSession(courseId);
        final sid = retry['session']?['_id']?.toString() ?? '';
        if (sid.isNotEmpty && sid != courseId) sessionId = sid;
        // If still no real session doc, abort with a message
        if (sessionId.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Session is starting — please try again in a moment.'),
            backgroundColor: Color(0xFF64748B),
            duration: Duration(seconds: 3),
          ));
          return;
        }
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not connect. Please try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ));
        return;
      }
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LmsLiveSessionScreen(
          sessionId: sessionId,
          courseId: courseId,
          sessionTitle: widget.course['title']?.toString() ?? 'Live Session',
          isInstructor: false,
        ),
      ),
    );
  }

  Widget _buildStreamTab(bool isWide) {
    return RefreshIndicator(
      onRefresh: _loadStream,
      child: ListView(
        children: [
          // ── Large banner ──────────────────────────────────
          _buildBanner(),

          // ── Live Session Banner (students only) ──────────
          if (!widget.isInstructor && _isSessionLive)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: GestureDetector(
                onTap: _joinLiveClass,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFB91C1C), Color(0xFFEF4444)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Row(children: [
                    const Icon(Icons.live_tv_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('🔴 LIVE NOW — Your instructor is live!',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                      SizedBox(height: 2),
                      Text('Tap anywhere to join the live session',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                      child: const Text('JOIN NOW', style: TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w900, fontSize: 13)),
                    ),
                  ]),
                ),
              ),
            ),

          const SizedBox(height: 16),

          // ── Two-column or single column ───────────────────
          if (isWide)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Upcoming widget (220px)
                  SizedBox(width: 220, child: _buildUpcomingWidget()),
                  const SizedBox(width: 16),
                  // Right: announcement button + feed
                  Expanded(
                    child: Column(
                      children: [
                        if (widget.isInstructor) _buildAnnouncementInput(),
                        if (widget.isInstructor) const SizedBox(height: 12),
                        _buildAnnouncementFeed(),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildUpcomingWidget(),
                  const SizedBox(height: 16),
                  if (widget.isInstructor) _buildAnnouncementInput(),
                  if (widget.isInstructor) const SizedBox(height: 12),
                  _buildAnnouncementFeed(),
                ],
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    final color = _bannerColor;

    return Container(
      height: 220,
      margin: const EdgeInsets.symmetric(horizontal: 0),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color,
                  color.withValues(alpha: 0.75),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Diagonal pattern
          Positioned.fill(
            child: CustomPaint(
              painter: _BannerPatternPainter(Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          // Decorative circles (like GC illustrations)
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            right: 60,
            bottom: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          // Course title at bottom-left
          Positioned(
            left: 24,
            right: 80,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _courseTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_section.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _section,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingWidget() {
    final upcoming = _assignments
        .where((a) {
          final d = a['dueDate']?.toString() ?? '';
          if (d.isEmpty) return false;
          try {
            return DateTime.parse(d).isAfter(DateTime.now());
          } catch (_) {
            return false;
          }
        })
        .take(3)
        .toList();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFDADCE0)),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upcoming',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF202124),
            ),
          ),
          const SizedBox(height: 8),
          if (upcoming.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Woohoo, no work due soon!',
                style: TextStyle(fontSize: 13, color: Color(0xFF5F6368)),
              ),
            )
          else
            ...upcoming.map((a) {
              final title = a['title']?.toString() ?? 'Assignment';
              final dueStr = a['dueDate']?.toString() ?? '';
              String dueLabel = '';
              if (dueStr.isNotEmpty) {
                try {
                  dueLabel = DateFormat('MMM d').format(DateTime.parse(dueStr));
                } catch (_) {}
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.assignment_outlined,
                        size: 16, color: Color(0xFF1A73E8)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF202124)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (dueLabel.isNotEmpty)
                      Text(dueLabel,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF70757A))),
                  ],
                ),
              );
            }),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () {
              if (widget.isInstructor) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => InstructorAssignmentsListScreen(
                    courseId: _courseId,
                    courseTitle: _courseTitle,
                  ),
                ));
              } else {
                _tabs.animateTo(1);
              }
            },
            child: const Text(
              'View all',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF1A73E8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementInput() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFDADCE0)),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          // Avatar
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFF1A73E8),
            child: Icon(Icons.person_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: GestureDetector(
              onTap: _showAnnouncementDialog,
              child: Container(
                height: 40,
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFDADCE0)),
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: const Text(
                  'Announce something to your class...',
                  style: TextStyle(
                      fontSize: 14, color: Color(0xFF9AA0A6)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAnnouncementDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New announcement',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                color: Color(0xFF202124))),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: _postCtrl,
            autofocus: true,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Share something with your class...',
              hintStyle:
                  TextStyle(fontSize: 14, color: Color(0xFF9AA0A6)),
              border: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFDADCE0))),
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFDADCE0))),
              focusedBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: Color(0xFF1A73E8), width: 2)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _postCtrl.clear();
              Navigator.pop(ctx);
            },
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF444746))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _postAnnouncement();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A73E8),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Post'),
          ),
        ],
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildAnnouncementFeed() {
    if (_loadingStream) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(strokeWidth: 2)));
    }

    // Build a combined feed: announcements + recent assignments
    final feedItems = <_FeedItem>[];

    // Announcements
    for (final a in _announcements) {
      feedItems.add(_FeedItem(
        type: _FeedItemType.announcement,
        data: a,
        date: _parseDate(a['createdAt']?.toString() ?? ''),
      ));
    }

    // Recent assignment posts
    for (final a in _assignments) {
      feedItems.add(_FeedItem(
        type: _FeedItemType.assignment,
        data: a,
        date: _parseDate(a['createdAt']?.toString() ?? ''),
      ));
    }

    // Sort by date descending
    feedItems.sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return b.date!.compareTo(a.date!);
    });

    if (feedItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.campaign_outlined,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text(
              'This is where you can talk to your class',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF202124)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Use the stream to share announcements, post assignments, and reply to student comments.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: Color(0xFF5F6368), height: 1.5),
            ),
          ],
        ),
      );
    }

    return Column(
      children: feedItems.map((item) => _buildFeedCard(item)).toList(),
    );
  }

  Widget _buildFeedCard(_FeedItem item) {
    final isAnnouncement = item.type == _FeedItemType.announcement;
    String authorName = '';
    String content = '';
    String title = '';
    String dateLabel = '';

    if (item.date != null) {
      try {
        dateLabel = DateFormat('d MMM yyyy').format(item.date!);
      } catch (_) {}
    }

    if (isAnnouncement) {
      authorName = (item.data['author'] as Map?)?['name']?.toString() ??
          item.data['authorName']?.toString() ??
          'Instructor';
      content = item.data['content']?.toString() ??
          item.data['message']?.toString() ??
          '';
    } else {
      final instructor = widget.course['instructor'] as Map?;
      authorName = instructor?['name']?.toString() ?? 'Instructor';
      title = item.data['title']?.toString() ?? 'Assignment';
      content = '$authorName posted a new assignment: $title';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDADCE0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row — clickable: opens the related classwork item
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _openFeedItem(item, content),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(
                children: [
                  // Icon/avatar
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isAnnouncement
                          ? const Color(0xFF1A73E8)
                          : const Color(0xFF1E7E34),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isAnnouncement
                          ? Icons.campaign_rounded
                          : Icons.assignment_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          content,
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xFF202124)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateLabel,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF70757A)),
                        ),
                      ],
                    ),
                  ),
                  // Three-dot menu — instructor only, announcements only
                  if (widget.isInstructor && isAnnouncement)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded,
                          size: 18, color: Color(0xFF70757A)),
                      padding: EdgeInsets.zero,
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit', style: TextStyle(fontSize: 14))),
                        const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete', style: TextStyle(fontSize: 14))),
                      ],
                      onSelected: (val) {
                        final postId = item.data['_id']?.toString() ?? '';
                        if (val == 'edit') _editAnnouncement(postId, content);
                        if (val == 'delete') _deleteAnnouncement(postId);
                      },
                    ),
                ],
              ),
            ),
          ),
          // Comments section
          if (isAnnouncement) _buildCommentSection(item),
        ],
      ),
    );
  }

  /// Open the classwork item a feed card refers to.
  /// Assignment feed cards open directly; announcement cards that mention a
  /// posted assignment/quiz are matched by title and opened.
  void _openFeedItem(_FeedItem item, String content) {
    if (item.type == _FeedItemType.assignment) {
      _openItem('assignment', item.data);
      return;
    }
    // Announcement: try to match "posted a new assignment/quiz: <title>"
    final lower = content.toLowerCase();
    final match = RegExp(r'(assignment|quiz|session)\s*:\s*(.+)$', caseSensitive: false)
        .firstMatch(content);
    if (match != null) {
      final kind = match.group(1)!.toLowerCase();
      final title = match.group(2)!.trim().toLowerCase();
      if (kind == 'assignment') {
        final found = _assignments.where((a) =>
            (a['title']?.toString().trim().toLowerCase() ?? '') == title).toList();
        if (found.isNotEmpty) {
          _openItem('assignment', found.first);
          return;
        }
      } else if (kind == 'quiz') {
        final found = _quizzes.where((q) =>
            (q['title']?.toString().trim().toLowerCase() ?? '') == title).toList();
        if (found.isNotEmpty) {
          _openItem('quiz', found.first);
          return;
        }
      } else if (kind == 'session') {
        final found = _sessions.where((s) =>
            (s['title']?.toString().trim().toLowerCase() ?? '') == title).toList();
        if (found.isNotEmpty) {
          _openItem('session', found.first);
          return;
        }
      }
    }
    // Fallback: partial title match against all classwork
    for (final a in _assignments) {
      final t = a['title']?.toString().trim().toLowerCase() ?? '';
      if (t.isNotEmpty && lower.contains(t)) {
        _openItem('assignment', a);
        return;
      }
    }
    for (final q in _quizzes) {
      final t = q['title']?.toString().trim().toLowerCase() ?? '';
      if (t.isNotEmpty && lower.contains(t)) {
        _openItem('quiz', q);
        return;
      }
    }
  }

  void _editAnnouncement(String postId, String currentContent) {
    final ctrl = TextEditingController(text: currentContent);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Announcement', style: TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(controller: ctrl, maxLines: 4, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _lms.updateAnnouncement(postId, ctrl.text.trim());
                await _loadStream();
              } catch (_) {}
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteAnnouncement(String postId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Announcement?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('This will permanently remove the announcement.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _lms.deleteAnnouncement(postId);
                await _loadStream();
              } catch (_) {}
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentSection(dynamic item) {
    final comments = (item.data['comments'] as List?) ?? [];
    final ctrl = TextEditingController();
    final postId = item.data['_id']?.toString() ?? '';

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFDADCE0))),
        color: Color(0xFFF8FAFC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Existing comments
          ...comments.take(3).map((c) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              CircleAvatar(radius: 12, backgroundColor: const Color(0xFF1A73E8),
                  child: Text((c['authorName'] ?? 'U')[0].toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white))),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c['authorName'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                Text(c['text'] ?? '', style: const TextStyle(fontSize: 13)),
              ])),
            ]),
          )),
          // Add comment input
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Row(children: [
              CircleAvatar(radius: 14, backgroundColor: const Color(0xFFE8F0FE),
                  child: const Icon(Icons.person_rounded, size: 16, color: Color(0xFF1A73E8))),
              const SizedBox(width: 8),
              Expanded(child: TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  hintText: 'Add class comment...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF70757A)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFDADCE0))),
                  filled: true, fillColor: Colors.white,
                ),
                onSubmitted: (text) async {
                  if (text.trim().isEmpty || postId.isEmpty) return;
                  try {
                    await _lms.addComment(postId, text.trim());
                    ctrl.clear();
                    await _loadStream();
                  } catch (_) {}
                },
              )),
            ]),
          ),
        ],
      ),
    );
  }

  DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    try { return DateTime.parse(s); } catch (_) { return null; }
  }

  // ════════════════════════════════════════════════
  // COURSE CONTENT TAB — modules + lessons + sessions
  // ════════════════════════════════════════════════

  Widget _buildCourseContentTab(bool isWide) {
    // Instructor: embed the full course content management screen inline
    if (widget.isInstructor) {
      return _EmbeddedCourseContent(key: _embeddedContentKey, courseId: _courseId);
    }

    // Student: read-only modules view
    if (_loadingModules) return const Center(child: CircularProgressIndicator(strokeWidth: 2));

    // Check if any session is currently live — only used here for the
    // banner's displayed title; whether the banner shows at all, and what
    // happens on tap, is driven solely by _isSessionLive (kept in sync by
    // the 5s poller in _checkLiveSession) so this tab can never show a
    // stale "JOIN" affordance after the instructor has ended the session.
    final liveSession = _sessions.where((s) => s['status']?.toString() == 'live').firstOrNull;

    final standaloneAssignments = _assignments;
    final standaloneQuizzes = _quizzes;
    final standaloneSessions = _sessions.where((s) => s['status']?.toString() != 'live').toList();

    return RefreshIndicator(
      onRefresh: _loadModules,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          // Installment lock / status banner — shown above everything else so
          // a locked student immediately understands why content is hidden.
          if (_lockReason == 'installment_overdue') ...[
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => InstallmentScheduleScreen(courseId: _courseId, courseTitle: _courseTitle),
              )).then((_) => _loadModules()),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: const Color(0xFFDC2626).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Row(children: [
                  const Icon(Icons.lock_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('COURSE LOCKED', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    Text('Installment overdue — pay now to unlock', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: const Text('PAY NOW', style: TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                ]),
              ),
            ),
          ] else if (_installmentPlanEnabled && _installments.isNotEmpty) ...[
            Builder(builder: (_) {
              final total = _installments.length;
              final nextPending = _installments.firstWhere(
                (i) => i['status'] != 'paid',
                orElse: () => null,
              );
              if (nextPending == null) return const SizedBox.shrink();
              final idx = nextPending['index'];
              final due = DateTime.tryParse(nextPending['dueDate']?.toString() ?? '');
              final dueStr = due != null ? DateFormat('d MMM').format(due) : '';
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => InstallmentScheduleScreen(courseId: _courseId, courseTitle: _courseTitle),
                )).then((_) => _loadModules()),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_view_month_rounded, color: Color(0xFF6366F1), size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      'Installment plan: installment $idx of $total${dueStr.isNotEmpty ? ' — due $dueStr' : ''}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    )),
                    const Text('View schedule', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6366F1))),
                  ]),
                ),
              );
            }),
          ],
          // Live session banner — gated on _isSessionLive (polled every 5s),
          // not on the unpolled _sessions list, so it appears/disappears in
          // sync with the Stream tab's banner and the FAB.
          if (_isSessionLive) ...[
            GestureDetector(
              onTap: _joinLiveClass,
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Row(children: [
                  const Icon(Icons.live_tv_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('● LIVE NOW', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    Text(liveSession?['title']?.toString() ?? 'Live Session',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: const Text('JOIN', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w900)),
                  ),
                ]),
              ),
            ),
          ],

          // Modules
          if (_modules.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _courseType == 'pragmatic' ? const Color(0xFFEEF2FF) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _courseType == 'pragmatic' ? 'Pragmatic — modules unlock on schedule' : 'Self-paced — complete a module to unlock the next',
                  style: TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w700,
                    color: _courseType == 'pragmatic' ? const Color(0xFF4F46E5) : const Color(0xFF15803D),
                  ),
                ),
              ),
            ),
            ..._modules.asMap().entries.map((e) => _buildModuleCard(e.value, e.key)),
          ] else ...[
            Center(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(children: [
                Icon(Icons.library_books_outlined, size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('No modules yet', style: TextStyle(fontSize: 16, color: Color(0xFF94A3B8))),
              ]),
            )),
          ],

          // Standalone Live Sessions (scheduled / ended)
          if (standaloneSessions.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Icon(Icons.live_tv_rounded, color: Colors.red, size: 18),
                SizedBox(width: 8),
                Text('Live Sessions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              ]),
            ),
            ...standaloneSessions.map((s) => _buildStudentSessionTile(s)),
          ],

          // Standalone Assignments
          if (standaloneAssignments.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Icon(Icons.assignment_rounded, color: Color(0xFF6366F1), size: 18),
                SizedBox(width: 8),
                Text('Assignments', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              ]),
            ),
            ...standaloneAssignments.map((a) => _buildStudentAssignmentTile(a)),
          ],

          // Standalone Quizzes
          if (standaloneQuizzes.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Icon(Icons.quiz_rounded, color: Color(0xFFF59E0B), size: 18),
                SizedBox(width: 8),
                Text('Quizzes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              ]),
            ),
            ...standaloneQuizzes.map((q) => _buildStudentQuizTile(q)),
          ],
        ],
      ),
    );
  }

  Widget _buildModuleCard(dynamic mod, int idx) {
    final module = mod is Map ? mod : <String, dynamic>{};
    final title = module['title']?.toString() ?? 'Module ${idx + 1}';
    final description = module['description']?.toString() ?? '';
    final lessons = List<dynamic>.from(module['lessons'] ?? []);
    // Set server-side by GET /courses/:id (courses.js computeProgress/lock logic) —
    // pragmatic courses lock a module until its scheduled unlock date regardless
    // of whether earlier modules were completed early.
    final isLocked = module['isLocked'] == true;
    final unlockDateRaw = module['unlockDate']?.toString();
    final isPragmatic = _courseType == 'pragmatic';
    String? unlockLabel;
    if (isLocked) {
      if (isPragmatic && unlockDateRaw != null) {
        try {
          final d = DateTime.parse(unlockDateRaw).toLocal();
          unlockLabel = 'Unlocks ${d.day}/${d.month}/${d.year}';
        } catch (_) {}
      } else if (!isPragmatic && idx > 0) {
        final prevTitle = (_modules[idx - 1] is Map ? _modules[idx - 1]['title']?.toString() : null)
            ?? 'Module $idx';
        unlockLabel = 'Complete "$prevTitle" to unlock';
      }
      unlockLabel ??= 'Locked';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          initiallyExpanded: !isLocked,
          enabled: !isLocked,
          leading: CircleAvatar(
            backgroundColor: isLocked ? const Color(0xFF94A3B8) : const Color(0xFF1A73E8),
            child: isLocked
                ? const Icon(Icons.lock_rounded, color: Colors.white, size: 18)
                : Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          title: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isLocked ? const Color(0xFF94A3B8) : const Color(0xFF0F172A))),
          subtitle: isLocked && unlockLabel != null
              ? Text(unlockLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6366F1)))
              : (description.isNotEmpty
                  ? Text(description, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis)
                  : Text('${lessons.length} lesson${lessons.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
          children: isLocked
              ? []
              : lessons.isEmpty
                  ? [const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('No lessons in this module', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                    )]
                  : lessons.map<Widget>((lesson) => _buildLessonTile(lesson)).toList(),
        ),
      ),
    );
  }

  String _fmtSessionDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour < 12 ? 'AM' : 'PM';
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}  $h:$m $ampm';
    } catch (_) { return raw; }
  }

  Widget _buildStudentSessionTile(dynamic session) {
    final title = session['title']?.toString() ?? 'Live Session';
    final status = session['status']?.toString() ?? 'scheduled';
    final scheduledAt = session['scheduledAt']?.toString() ?? '';
    final recordingUrl = session['recordingUrl']?.toString() ?? '';
    final meetingLink = session['meetingLink']?.toString() ?? '';
    final isEnded = status == 'ended' || status == 'completed';
    final id = session['_id']?.toString() ?? '';
    final hasMeetLink = meetingLink.isNotEmpty && meetingLink.startsWith('http');

    return GestureDetector(
      onTap: isEnded ? () => _showCompletedSessionOptions(id, title, recordingUrl) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isEnded ? const Color(0xFFF1F5F9) : const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isEnded ? const Color(0xFF94A3B8).withValues(alpha: 0.3) : const Color(0xFFFB923C).withValues(alpha: 0.4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isEnded ? const Color(0xFF64748B) : Colors.red).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(isEnded ? Icons.check_circle_outline_rounded : Icons.live_tv_rounded,
                size: 20, color: isEnded ? const Color(0xFF64748B) : Colors.red),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
              if (scheduledAt.isNotEmpty)
                Text(_fmtSessionDate(scheduledAt),
                  style: TextStyle(fontSize: 12, color: isEnded ? const Color(0xFF64748B) : const Color(0xFFF59E0B))),
            ])),
            if (isEnded)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                child: const Text('Ended', style: TextStyle(color: Colors.black45, fontSize: 12, fontWeight: FontWeight.w600)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                child: const Text('Upcoming', style: TextStyle(color: Color(0xFF1A73E8), fontSize: 12, fontWeight: FontWeight.w600)),
              ),
          ]),
          if (hasMeetLink) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () async {
                final uri = Uri.tryParse(meetingLink);
                if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A73E8).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1A73E8).withValues(alpha: 0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.video_call_rounded, color: Color(0xFF1A73E8), size: 18),
                  SizedBox(width: 8),
                  Text('Join via Google Meet', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A73E8))),
                  Spacer(),
                  Icon(Icons.open_in_new_rounded, color: Color(0xFF1A73E8), size: 16),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildStudentAssignmentTile(dynamic assignment) {
    final title = assignment['title']?.toString() ?? 'Assignment';
    final dueDate = assignment['dueDate']?.toString() ?? '';
    final marks = assignment['totalMarks']?.toString() ?? '';
    final id = assignment['_id']?.toString() ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => AssignmentSubmitScreen(
          assignment: Map<String, dynamic>.from(assignment is Map ? assignment : {}),
          courseId: _courseId,
        ),
      )),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F3FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.assignment_rounded, size: 20, color: Color(0xFF6366F1)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
            Text('${marks.isNotEmpty ? '$marks marks' : ''}${dueDate.isNotEmpty ? '  ·  Due: ${_fmtSessionDate(dueDate)}' : ''}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ])),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
        ]),
      ),
    );
  }

  Widget _buildStudentQuizTile(dynamic quiz) {
    final title = quiz['title']?.toString() ?? 'Quiz';
    final timeLimit = quiz['timeLimit']?.toString() ?? '';
    final passingScore = quiz['passingScore']?.toString() ?? '';
    final id = quiz['_id']?.toString() ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => QuizTakeScreen(
          quiz: Map<String, dynamic>.from(quiz is Map ? quiz : {}),
          enrollmentId: widget.enrollmentId ?? '',
        ),
      )).then((_) => _loadModules()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.quiz_rounded, size: 20, color: Color(0xFFF59E0B)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
            Text('${timeLimit.isNotEmpty ? '$timeLimit min' : ''}${passingScore.isNotEmpty ? '  ·  Pass: $passingScore%' : ''}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ])),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
        ]),
      ),
    );
  }

  Widget _buildLessonTile(dynamic l) {
    final lesson = l is Map ? l : <String, dynamic>{};
    final title = lesson['title']?.toString() ?? 'Lesson';
    final type = lesson['type']?.toString() ?? 'lesson';
    final isLive = type == 'live';
    final status = lesson['status']?.toString() ?? '';
    final scheduledAt = lesson['scheduledAt']?.toString() ?? lesson['scheduledDate']?.toString() ?? '';
    final meetingLink = lesson['meetingLink']?.toString() ?? '';
    final hasMeetLink = isLive && meetingLink.isNotEmpty && meetingLink.startsWith('http');
    final isScheduled = isLive && status != 'live' && status != 'ended' && status != 'completed';

    String dateLabel = '';
    if (scheduledAt.isNotEmpty) {
      try { dateLabel = DateFormat('MMM d, yyyy – h:mm a').format(DateTime.parse(scheduledAt).toLocal()); } catch (_) {}
    }

    Color iconColor = isLive ? Colors.red : const Color(0xFF1A73E8);
    IconData icon = isLive ? Icons.live_tv_rounded : Icons.play_circle_outline_rounded;
    if (type == 'video') icon = Icons.videocam_outlined;
    if (type == 'document') { icon = Icons.description_outlined; iconColor = const Color(0xFF188038); }
    if (type == 'quiz') { icon = Icons.quiz_outlined; iconColor = const Color(0xFF9334E6); }

    String statusLabel = '';
    Color statusColor = const Color(0xFF94A3B8);
    if (isLive) {
      if (status == 'live') { statusLabel = '● LIVE NOW'; statusColor = Colors.red; }
      else if (status == 'ended' || status == 'completed') { statusLabel = 'Ended'; statusColor = const Color(0xFF94A3B8); }
      else if (dateLabel.isNotEmpty) { statusLabel = 'Scheduled · $dateLabel'; statusColor = const Color(0xFF1A73E8); }
      else { statusLabel = 'Scheduled'; statusColor = const Color(0xFF1A73E8); }
    }

    return InkWell(
      onTap: () => _openLessonItem(lesson),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF202124))),
              if (statusLabel.isNotEmpty)
                Text(statusLabel, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
            ])),
            if (status == 'live')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                child: const Text('JOIN', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
              )
            else if (hasMeetLink && isScheduled)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF1A73E8), borderRadius: BorderRadius.circular(6)),
                child: const Text('JOIN', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
              )
            else
              Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey.shade400),
          ]),
          if (hasMeetLink && isScheduled) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final uri = Uri.tryParse(meetingLink);
                if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: Container(
                margin: const EdgeInsets.only(left: 46),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1A73E8).withValues(alpha: 0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.video_call_rounded, color: Color(0xFF1A73E8), size: 16),
                  SizedBox(width: 6),
                  Text('Join via Google Meet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A73E8))),
                  Spacer(),
                  Icon(Icons.open_in_new_rounded, color: Color(0xFF1A73E8), size: 14),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Future<void> _openLessonItem(Map lesson) async {
    final type = lesson['type']?.toString() ?? 'lesson';
    final status = lesson['status']?.toString() ?? '';
    final sessionId = lesson['_id']?.toString() ?? '';
    final title = lesson['title']?.toString() ?? 'Session';
    final recordingUrl = lesson['recordingUrl']?.toString() ?? '';

    if (type == 'live') {
      if (status == 'live') {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => LmsLiveSessionScreen(
            sessionId: sessionId,
            courseId: _courseId,
            sessionTitle: title,
            isInstructor: widget.isInstructor,
          ),
        ));
      } else if (status == 'ended' || status == 'completed') {
        _showCompletedSessionOptions(sessionId, title, recordingUrl);
      } else {
        final meetLink = lesson['meetingLink']?.toString() ?? '';
        if (meetLink.isNotEmpty && meetLink.startsWith('http')) {
          final uri = Uri.tryParse(meetLink);
          if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
        final scheduledAt = lesson['scheduledAt']?.toString() ?? '';
        String dateLabel = scheduledAt;
        if (scheduledAt.isNotEmpty) {
          try { dateLabel = DateFormat('EEEE, MMM d, yyyy – h:mm a').format(DateTime.parse(scheduledAt).toLocal()); } catch (_) {}
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Session scheduled for $dateLabel'),
          backgroundColor: const Color(0xFF1A73E8),
          duration: const Duration(seconds: 3),
        ));
      }
    } else if (type == 'assignment') {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => AssignmentSubmitScreen(
          assignment: Map<String, dynamic>.from(lesson),
          courseId: _courseId,
        ),
      )).then((_) => _loadModules());
    } else if (type == 'quiz') {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => QuizTakeScreen(
          quiz: Map<String, dynamic>.from(lesson),
          enrollmentId: widget.enrollmentId ?? '',
        ),
      )).then((_) => _loadModules());
    } else {
      // Content lesson — open detail page
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => LessonDetailPage(
          lesson: Map<String, dynamic>.from(lesson),
          courseId: _courseId,
          moduleId: lesson['moduleId']?.toString() ?? '',
          enrollmentId: widget.enrollmentId ?? '',
        ),
      )).then((_) => _loadModules());
    }
  }

  // ════════════════════════════════════════════════
  // CLASSWORK TAB (kept for reference, unused)
  // ════════════════════════════════════════════════

  Widget _buildClassworkTab(bool isWide) {
    if (_loadingClasswork) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    // Separate live sessions to pin them at top
    final liveSessions = _sessions
        .where((s) => s['status']?.toString() == 'live')
        .map((s) => {'type': 'session', 'data': s})
        .toList();

    final all = [
      ..._assignments.map((a) => {'type': 'assignment', 'data': a}),
      ..._quizzes.map((q) => {'type': 'quiz', 'data': q}),
      ..._sessions
          .where((s) => s['status']?.toString() != 'live')
          .map((s) => {'type': 'session', 'data': s}),
    ];

    // Also show live banner if _isSessionLive but no session in list yet
    final showLiveBanner = !widget.isInstructor && _isSessionLive && liveSessions.isEmpty;

    return RefreshIndicator(
      onRefresh: _loadClasswork,
      child: (all.isEmpty && liveSessions.isEmpty && !showLiveBanner)
          ? _buildClassworkEmpty()
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 80),
              children: [
                if (widget.isInstructor) ...[
                  _buildInstructorCreateBar(),
                  const SizedBox(height: 12),
                ],
                // Live sessions pinned at top
                if (liveSessions.isNotEmpty) ...[
                  ...liveSessions.map((item) => _buildClassworkCard(item)),
                  const SizedBox(height: 8),
                ],
                // Fallback live banner when session is live but not in list
                if (showLiveBanner) ...[
                  _buildFallbackLiveBanner(),
                  const SizedBox(height: 8),
                ],
                // All other items
                ...all.map((item) => _buildClassworkCard(item)),
              ],
            ),
    );
  }

  Widget _buildFallbackLiveBanner() {
    return GestureDetector(
      onTap: _joinLiveClass,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFB91C1C), Color(0xFFEF4444)],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.red.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.live_tv_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🔴 LIVE SESSION IN PROGRESS',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                  SizedBox(height: 3),
                  Text('Your instructor is live now — tap to join!',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('JOIN NOW',
                  style: TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructorCreateBar() {
    return Row(
      children: [
        _createBtn(Icons.assignment_add, 'Assignment', () {
          if (_courseId.isNotEmpty) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => InstructorCreateAssignmentScreen(courseId: _courseId),
            )).then((_) => _loadClasswork());
          }
        }),
        const SizedBox(width: 10),
        _createBtn(Icons.quiz_outlined, 'Quiz', () {
          if (_courseId.isNotEmpty) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => InstructorCreateQuizScreen(courseId: _courseId),
            )).then((_) => _loadClasswork());
          }
        }),
        const SizedBox(width: 10),
        _createBtn(Icons.videocam_outlined, 'Session', () {
          if (_courseId.isNotEmpty) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => InstructorScheduleSessionScreen(courseId: _courseId),
            )).then((_) => _loadClasswork());
          }
        }),
      ],
    );
  }

  Widget _createBtn(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label,
            style:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1A73E8),
          side: const BorderSide(color: Color(0xFFDADCE0)),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }

  Widget _buildClassworkCard(Map<String, dynamic> item) {
    final type = item['type'] as String;
    final data = item['data'] as Map;
    final title =
        data['title']?.toString() ?? (type == 'quiz' ? 'Quiz' : type == 'session' ? 'Session' : 'Assignment');
    final dueStr = data['dueDate']?.toString() ?? data['scheduledAt']?.toString() ?? '';
    final points = data['totalMarks']?.toString() ?? '';
    final sessionStatus = type == 'session' ? (data['status']?.toString() ?? '') : '';
    final isLiveSession = type == 'session' && sessionStatus == 'live';

    String dueLabel = '';
    if (dueStr.isNotEmpty) {
      try {
        dueLabel = DateFormat('MMM d').format(DateTime.parse(dueStr));
      } catch (_) {}
    }

    Color iconBg;
    IconData icon;
    switch (type) {
      case 'quiz':
        iconBg = const Color(0xFF9334E6);
        icon = Icons.quiz_outlined;
        break;
      case 'session':
        iconBg = isLiveSession ? Colors.red : const Color(0xFF188038);
        icon = isLiveSession ? Icons.live_tv_rounded : Icons.videocam_outlined;
        break;
      default:
        iconBg = const Color(0xFF1A73E8);
        icon = Icons.assignment_outlined;
    }

    // Live session card — special highlighted style for students
    if (isLiveSession && !widget.isInstructor) {
      return GestureDetector(
        onTap: () => _openItem(type, data),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFB91C1C), Color(0xFFEF4444)],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: Colors.red.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.live_tv_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('● LIVE',
                            style: TextStyle(color: Color(0xFFB91C1C), fontSize: 10, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(title,
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    const Text('Your instructor is live now — tap to join!',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('JOIN NOW',
                    style: TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w900, fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    }

    final sessionMeetLink = type == 'session' ? (data['meetingLink']?.toString() ?? '') : '';
    final hasSessionMeetLink = sessionMeetLink.isNotEmpty && sessionMeetLink.startsWith('http');
    final isScheduledSession = type == 'session' && sessionStatus == 'scheduled';

    return InkWell(
      onTap: () => _openItem(type, data),
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              // Icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF202124))),
                    if (dueLabel.isNotEmpty || points.isNotEmpty)
                      Text(
                        [
                          if (dueLabel.isNotEmpty) 'Due $dueLabel',
                          if (points.isNotEmpty) '$points points',
                        ].join('  ·  '),
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF70757A)),
                      ),
                    if (type == 'session' && sessionStatus.isNotEmpty && sessionStatus != 'live')
                      Row(children: [
                        Text(
                          sessionStatus == 'scheduled' ? 'Scheduled${dueLabel.isNotEmpty ? ' · $dueLabel' : ''}' :
                          sessionStatus == 'ended' ? 'Session ended' :
                          sessionStatus == 'completed' ? 'Completed' : sessionStatus,
                          style: TextStyle(
                            fontSize: 12,
                            color: sessionStatus == 'scheduled' ? const Color(0xFF1A73E8) : const Color(0xFF70757A),
                          ),
                        ),
                      ]),
                  ],
                ),
              ),
              if (widget.isInstructor)
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded,
                      size: 18, color: Color(0xFF70757A)),
                  onPressed: () => _showClassworkMenu(type, data),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                )
              else if (isScheduledSession && hasSessionMeetLink)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF1A73E8), borderRadius: BorderRadius.circular(6)),
                  child: const Text('JOIN', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                )
              else
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: Color(0xFFDADCE0)),
            ],
          ),
          if (!widget.isInstructor && isScheduledSession && hasSessionMeetLink) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final uri = Uri.tryParse(sessionMeetLink);
                if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: Container(
                margin: const EdgeInsets.only(left: 48),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1A73E8).withValues(alpha: 0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.video_call_rounded, color: Color(0xFF1A73E8), size: 16),
                  SizedBox(width: 6),
                  Text('Join via Google Meet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A73E8))),
                  Spacer(),
                  Icon(Icons.open_in_new_rounded, color: Color(0xFF1A73E8), size: 14),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Future<void> _openItem(String type, Map data) async {
    if (type == 'assignment') {
      if (widget.isInstructor) {
        // Straight into that assignment's submissions/grading — the old
        // behavior (a menu with only "Grade Submissions"/"Delete
        // Assignment") made it look like the feed card wasn't really
        // clickable to anything useful.
        final assignmentId = data['_id']?.toString() ?? '';
        if (assignmentId.isNotEmpty) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => InstructorGradingScreen(
              assignmentId: assignmentId,
              assignmentTitle: data['title']?.toString() ?? 'Assignment',
            ),
          ));
        }
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AssignmentSubmitScreen(
            assignment: Map<String, dynamic>.from(data),
            courseId: _courseId,
            enrollmentId: widget.enrollmentId,
          ),
        ),
      );
    } else if (type == 'quiz') {
      if (widget.isInstructor) {
        _showClassworkMenu(type, data);
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuizTakeScreen(
            quiz: Map<String, dynamic>.from(data),
            enrollmentId: widget.enrollmentId ?? '',
          ),
        ),
      );
    } else if (type == 'session') {
      final sessionId = data['_id']?.toString() ?? widget.course['_id']?.toString() ?? '';
      final sessionTitle = data['title']?.toString() ?? 'Live Session';
      final status = data['status']?.toString() ?? '';
      final recordingUrl = data['recordingUrl']?.toString() ?? '';

      // Completed/ended sessions → show recording options (for all users)
      if (status == 'completed' || status == 'ended') {
        _showCompletedSessionOptions(sessionId, sessionTitle, recordingUrl);
        return;
      }

      // Scheduled sessions — open Google Meet link if set, else show info
      if (status == 'scheduled') {
        final meetLink = data['meetingLink']?.toString() ?? '';
        if (meetLink.isNotEmpty && meetLink.startsWith('http')) {
          final uri = Uri.tryParse(meetLink);
          if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This session has not started yet.'),
          backgroundColor: Color(0xFF64748B),
          duration: Duration(seconds: 2),
        ));
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LmsLiveSessionScreen(
            sessionId: sessionId,
            courseId: widget.course['_id']?.toString() ?? '',
            sessionTitle: sessionTitle,
            isInstructor: widget.isInstructor,
          ),
        ),
      );
    }
  }

  void _showCompletedSessionOptions(String sessionId, String title, String recordingUrl) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF202124)),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 4),
            const Divider(),
            // Recordings now archive to Google Drive only — no in-app
            // playback option here anymore ("Watch Recording" removed).
            if (widget.isInstructor && recordingUrl.isNotEmpty)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFFFEBEE), shape: BoxShape.circle),
                  child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFB3261E), size: 22),
                ),
                title: const Text('Delete Recording', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFFB3261E))),
                subtitle: const Text('Permanently remove this recording', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteRecording(sessionId, title);
                },
              ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFE6F4EA), shape: BoxShape.circle),
                child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF188038), size: 22),
              ),
              title: const Text('View Chat Transcript', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('All messages from this session', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _viewSessionTranscript(sessionId, title);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteRecording(String sessionId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Recording?'),
        content: Text('The recording for "$title" will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _lms.updateSession(sessionId, {'recordingUrl': '', 'recordingBlobUrl': ''});
      _loadClasswork();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording deleted'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _viewSessionTranscript(String sessionId, String title) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 16),
          Text('Loading transcript...'),
        ]),
      ),
    );

    try {
      final result = await LmsService().getSessionTranscript(sessionId);
      if (!mounted) return;
      Navigator.pop(context); // close loading

      final transcript = result['transcript']?.toString() ?? 'No transcript available.';

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF188038), size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis)),
          ]),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              child: SelectableText(
                transcript,
                style: const TextStyle(fontSize: 13, height: 1.7, fontFamily: 'monospace'),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load transcript: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _openSessionLink(Map data, {bool isInstructor = false}) async {
    final meetingLink = data['meetingLink']?.toString() ?? '';
    final meetingId = data['meetingId']?.toString() ?? '';
    final meetingPassword = data['meetingPassword']?.toString() ?? '';
    String platform = data['platform']?.toString() ?? 'zoom';
    if (meetingLink.contains('meet.google.com')) platform = 'meet';
    else if (meetingLink.contains('zoom.us')) platform = 'zoom';
    else if (meetingLink.contains('teams.microsoft.com')) platform = 'teams';
    final title = data['title']?.toString() ?? 'Live Session';

    if (meetingLink.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No meeting link set for this session.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.live_tv_rounded, color: Colors.red, size: 24),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sessionInfoRow(Icons.videocam_rounded, 'Platform', _platformName(platform)),
            if (meetingId.isNotEmpty) ...[const SizedBox(height: 8), _sessionInfoRow(Icons.tag_rounded, 'Meeting ID', meetingId)],
            if (meetingPassword.isNotEmpty) ...[const SizedBox(height: 8), _sessionInfoRow(Icons.lock_outline_rounded, 'Password', meetingPassword)],
            const SizedBox(height: 8),
            _sessionInfoRow(Icons.link_rounded, 'Link', meetingLink, overflow: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isInstructor ? Colors.red : const Color(0xFF1A73E8),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse(meetingLink);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: Icon(isInstructor ? Icons.play_arrow_rounded : Icons.login_rounded, size: 18),
            label: Text(isInstructor ? 'Start Session' : 'Join Session'),
          ),
        ],
      ),
    );
  }

  Widget _sessionInfoRow(IconData icon, String label, String value, {bool overflow = false}) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: const Color(0xFF70757A)),
      const SizedBox(width: 6),
      Text('$label: ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF444746))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF202124)), overflow: overflow ? TextOverflow.ellipsis : null)),
    ]);
  }

  String _platformName(String p) {
    switch (p.toLowerCase()) {
      case 'zoom': return 'Zoom Meeting';
      case 'meet': return 'Google Meet';
      case 'teams': return 'Microsoft Teams';
      default: return 'Custom Link';
    }
  }

  void _showClassworkMenu(String type, Map data) {
    final id = data['_id']?.toString() ?? '';
    final title = data['title']?.toString() ?? type;
    final meetingLink = data['meetingLink']?.toString() ?? '';
    final hasMeetLink = meetingLink.isNotEmpty && meetingLink.startsWith('http');
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Session — Google Meet link (both instructor and student, if set)
            if (type == 'session' && hasMeetLink)
              ListTile(
                leading: const Icon(Icons.video_call_rounded, color: Color(0xFF1A73E8)),
                title: const Text('Join via Google Meet', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A73E8))),
                subtitle: Text(meetingLink, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                onTap: () async {
                  Navigator.pop(context);
                  final uri = Uri.tryParse(meetingLink);
                  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
            // Session — Start button (instructor)
            if (type == 'session')
              ListTile(
                leading: const Icon(Icons.play_circle_rounded, color: Colors.red),
                title: const Text('Start Session', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Launch iCare live video session'),
                onTap: () {
                  Navigator.pop(context);
                  final sessionId = data['_id']?.toString() ?? widget.course['_id']?.toString() ?? '';
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => LmsLiveSessionScreen(
                      sessionId: sessionId,
                      courseId: widget.course['_id']?.toString() ?? '',
                      sessionTitle: data['title']?.toString() ?? 'Live Session',
                      isInstructor: true,
                      lessonId: data['_id']?.toString(),
                    ),
                  ));
                },
              ),
            // Recordings now archive to Google Drive only — no in-app
            // "Watch Recording" option here anymore.
            // Session — Delete Recording (instructor only)
            if (type == 'session' && widget.isInstructor &&
                (data['status'] == 'completed' || data['status'] == 'ended') &&
                (data['recordingUrl']?.toString() ?? '').isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFB3261E)),
                title: const Text('Delete Recording', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFB3261E))),
                subtitle: const Text('Permanently remove this recording'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteRecording(id, data['title']?.toString() ?? 'Session');
                },
              ),
            // Session — View Transcript (completed sessions)
            if (type == 'session' &&
                (data['status'] == 'completed' || data['status'] == 'ended') &&
                id.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF188038)),
                title: const Text('View Chat Transcript', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Messages from this session'),
                onTap: () {
                  Navigator.pop(context);
                  _viewSessionTranscript(id, data['title']?.toString() ?? 'Session Transcript');
                },
              ),
            // Assignment — grade
            if (type == 'assignment' && id.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.grade_outlined, color: Color(0xFF1A73E8)),
                title: const Text('Grade submissions'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => InstructorGradingScreen(
                      assignmentId: id,
                      assignmentTitle: title,
                    ),
                  ));
                },
              ),
            // Session — Reschedule (instructor only, upcoming sessions)
            if (type == 'session' && widget.isInstructor &&
                data['status']?.toString() != 'completed' && data['status']?.toString() != 'ended')
              ListTile(
                leading: const Icon(Icons.calendar_month_rounded, color: Color(0xFF6366F1)),
                title: const Text('Reschedule', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6366F1))),
                subtitle: const Text('Change session date with announcement'),
                onTap: () async {
                  Navigator.pop(context);
                  await _rescheduleSession(id, data['title']?.toString() ?? 'Session');
                },
              ),
            // Session — Cancel (instructor only)
            if (type == 'session' && widget.isInstructor &&
                data['status']?.toString() != 'completed' && data['status']?.toString() != 'ended' && data['status']?.toString() != 'cancelled')
              ListTile(
                leading: const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444)),
                title: const Text('Cancel Session', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                subtitle: const Text('Notify students and log cancellation'),
                onTap: () async {
                  Navigator.pop(context);
                  await _cancelSession(id, data['title']?.toString() ?? 'Session');
                },
              ),
            if (type == 'assignment' || type == 'quiz')
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFB3261E)),
                title: Text('Delete $type'.replaceFirst('a', 'A').replaceFirst('q', 'Q'),
                    style: const TextStyle(color: Color(0xFFB3261E))),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text('Delete ${type == 'quiz' ? 'Quiz' : 'Assignment'}?'),
                      content: Text('"$title" will be permanently deleted.${type == 'assignment' ? ' All submissions will also be removed.' : ''}'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && id.isNotEmpty) {
                    try {
                      if (type == 'quiz') {
                        await _lms.deleteQuiz(id);
                      } else {
                        await _lms.deleteAssignment(id);
                      }
                      _loadClasswork();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('${type == 'quiz' ? 'Quiz' : 'Assignment'} deleted'),
                          backgroundColor: Colors.green,
                        ));
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Delete failed: $e'),
                          backgroundColor: Colors.red,
                        ));
                      }
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _rescheduleSession(String sessionId, String sessionTitle) async {
    if (sessionId.isEmpty) return;
    DateTime? newDate;
    TimeOfDay? newTime;
    final reasonCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Reschedule "$sessionTitle"', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_rounded, color: Color(0xFF6366F1)),
                title: Text(newDate == null ? 'Pick new date' : '${newDate!.day}/${newDate!.month}/${newDate!.year}'),
                onTap: () async {
                  final d = await showDatePicker(context: ctx, initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (d != null) setS(() => newDate = d);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time_rounded, color: Color(0xFF6366F1)),
                title: Text(newTime == null ? 'Pick new time' : newTime!.format(ctx)),
                onTap: () async {
                  final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                  if (t != null) setS(() => newTime = t);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(labelText: 'Reason (optional)', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white, elevation: 0),
              onPressed: () async {
                if (newDate == null) return;
                final dt = DateTime(newDate!.year, newDate!.month, newDate!.day,
                    newTime?.hour ?? 9, newTime?.minute ?? 0);
                Navigator.pop(ctx);
                try {
                  await _lms.rescheduleSession(sessionId, newDate: dt.toIso8601String(), reason: reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : null);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session rescheduled! Students notified.'), backgroundColor: Colors.green));
                    _loadClasswork();
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
                }
              },
              child: const Text('Reschedule'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelSession(String sessionId, String sessionTitle) async {
    if (sessionId.isEmpty) return;
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancel "$sessionTitle"?', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Students will be notified about the cancellation.', style: TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Reason (optional)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white, elevation: 0),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Session'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _lms.cancelSession(sessionId, reason: reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session cancelled. Students notified.'), backgroundColor: Colors.orange));
        _loadClasswork();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _buildClassworkEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No classwork yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF5F6368))),
          if (widget.isInstructor) ...[
            const SizedBox(height: 24),
            _buildInstructorCreateBar(),
          ],
        ],
      ),
    );
  }

  void _showCreateMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F0FE),
                child: Icon(Icons.view_module_rounded, color: Color(0xFF1A73E8), size: 20),
              ),
              title: const Text('Add Module', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Add a new module to Course Content'),
              onTap: () {
                Navigator.pop(context);
                _embeddedContentKey.currentState?.triggerAddModule();
              },
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F0FE),
                child: Icon(Icons.assignment_outlined, color: Color(0xFF1A73E8), size: 20),
              ),
              title: const Text('Assignment', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Create an assignment for students'),
              onTap: () {
                Navigator.pop(context);
                if (_courseId.isNotEmpty) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => InstructorCreateAssignmentScreen(courseId: _courseId),
                  )).then((_) => _loadClasswork());
                }
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFF3E8FF),
                child: Icon(Icons.quiz_outlined, color: Color(0xFF9334E6), size: 20),
              ),
              title: const Text('Quiz', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Create a quiz for students'),
              onTap: () {
                Navigator.pop(context);
                if (_courseId.isNotEmpty) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => InstructorCreateQuizScreen(courseId: _courseId),
                  )).then((_) => _loadClasswork());
                }
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE6F4EA),
                child: Icon(Icons.videocam_outlined, color: Color(0xFF188038), size: 20),
              ),
              title: const Text('Live Session', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Schedule a live class session'),
              onTap: () {
                Navigator.pop(context);
                if (_courseId.isNotEmpty) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => InstructorScheduleSessionScreen(courseId: _courseId),
                  )).then((_) => _loadClasswork());
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════
  // PEOPLE TAB
  // ════════════════════════════════════════════════

  Future<void> _showInviteTeacherDialog() async {
    final emailCtrl = TextEditingController();
    String selectedRole = 'normal';
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.person_add_outlined, color: Color(0xFF1A73E8)),
          SizedBox(width: 10),
          Text('Invite Co-Teacher', style: TextStyle(fontWeight: FontWeight.w700)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            'Enter the email address of the teacher you want to invite. They will receive an email to join this course as a co-teacher.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Teacher Email Address',
              hintText: 'teacher@example.com',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),
          const Align(alignment: Alignment.centerLeft, child: Text('Role', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _inviteRoleChip('Lead Instructor', 'lead', selectedRole, (v) => setDlg(() => selectedRole = v))),
            const SizedBox(width: 8),
            Expanded(child: _inviteRoleChip('Normal Instructor', 'normal', selectedRole, (v) => setDlg(() => selectedRole = v))),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, color: Colors.amber.shade700, size: 16),
              const SizedBox(width: 8),
              const Expanded(child: Text(
                'Co-teachers can manage content, grade assignments, and run live sessions. Only the Lead Instructor can issue certificates.',
                style: TextStyle(fontSize: 11, color: Color(0xFF78350F)),
              )),
            ]),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white),
            onPressed: () async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid email'), backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await _lms.inviteTeacher(courseId: _courseId, email: email, role: selectedRole);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Invitation sent to $email'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Send Invite'),
          ),
        ],
      )),
    );
  }

  Widget _inviteRoleChip(String label, String value, String selected, void Function(String) onTap) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A73E8).withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF1A73E8) : const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? const Color(0xFF1A73E8) : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeopleTab(bool isWide) {
    final instructor = widget.course['instructor'] as Map?;
    final instructorName = instructor?['name']?.toString() ??
        instructor?['username']?.toString() ??
        'iCare Instructor';
    final coTeachers = (widget.course['coTeachers'] as List?) ?? [];

    return RefreshIndicator(
      onRefresh: _loadPeople,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          // Teacher section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Teachers',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF1A73E8)),
              ),
              if (widget.isInstructor)
                TextButton.icon(
                  onPressed: _showInviteTeacherDialog,
                  icon: const Icon(Icons.person_add_outlined,
                      size: 16, color: Color(0xFF1A73E8)),
                  label: const Text('Invite Teacher',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF1A73E8))),
                ),
            ],
          ),
          const Divider(color: Color(0xFF1A73E8), thickness: 1.5),
          const SizedBox(height: 8),
          // Lead instructor
          _personRow(instructorName, isTeacher: true, roleLabel: 'Lead Instructor'),
          // Co-teachers
          ...coTeachers.map((ct) {
            final ctName = ct['name']?.toString() ?? ct['email']?.toString() ?? 'Co-Teacher';
            final ctRole = ct['role']?.toString() ?? 'normal';
            final ctId = ct['userId']?.toString() ?? '';
            final roleLabel = ctRole == 'lead' ? 'Lead Instructor' : 'Co-Instructor';
            return _personRow(ctName, isTeacher: true, roleLabel: roleLabel, isLead: ctRole == 'lead',
              onRemove: widget.isInstructor && ctId.isNotEmpty ? () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Remove Co-Teacher'),
                    content: Text('Remove $ctName from this course?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  final lms = LmsService();
                  final courseId = widget.course['_id']?.toString() ?? '';
                  final result = await lms.removeCoTeacher(courseId: courseId, userId: ctId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(result['success'] == true ? '$ctName removed' : (result['message'] ?? 'Failed')),
                      backgroundColor: result['success'] == true ? Colors.green : Colors.red,
                    ));
                    if (result['success'] == true) _loadPeople();
                  }
                }
              } : null,
            );
          }),
          const SizedBox(height: 24),

          // Students section
          Row(
            children: [
              const Text(
                'Students',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF1A73E8)),
              ),
              const SizedBox(width: 8),
              if (_students.isNotEmpty)
                Text(
                  '(${_students.length})',
                  style: const TextStyle(
                      fontSize: 16, color: Color(0xFF70757A)),
                ),
            ],
          ),
          const Divider(color: Color(0xFF1A73E8), thickness: 1.5),
          const SizedBox(height: 8),
          if (_loadingPeople)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(strokeWidth: 2)))
          else if (_students.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No students have joined yet.',
                style: TextStyle(fontSize: 14, color: Color(0xFF5F6368)),
              ),
            )
          else
            ..._students.map((s) {
              final name = (s['user'] as Map?)?['name']?.toString() ??
                  s['name']?.toString() ??
                  'Student';
              final studentId = ((s['user'] as Map?)?['_id'] ?? s['_id'])?.toString() ?? '';
              return _personRow(
                name,
                isTeacher: false,
                studentId: studentId,
                onRemoveStudent: widget.isInstructor && studentId.isNotEmpty
                    ? () => _confirmRemoveStudent(studentId, name)
                    : null,
              );
            }),
        ],
      ),
    );
  }

  Future<void> _confirmRemoveStudent(String studentId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Student'),
        content: Text('Remove "$name" from this course? They will lose access to the course content and their enrollment will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _lms.removeStudentFromCourse(courseId: _courseId, studentId: studentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$name" removed from the course'), backgroundColor: Colors.green),
        );
        _loadPeople();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove student: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _personRow(String name, {required bool isTeacher, String? roleLabel, bool isLead = false, VoidCallback? onRemove, String? studentId, VoidCallback? onRemoveStudent}) {
    final avatarColor = isTeacher
        ? (isLead ? const Color(0xFF9334E6) : const Color(0xFF1A73E8))
        : Colors.grey.shade300;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: avatarColor,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: isTeacher ? Colors.white : Colors.grey.shade600,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 14, color: Color(0xFF202124))),
                if (roleLabel != null)
                  Text(roleLabel, style: const TextStyle(fontSize: 11, color: Color(0xFF70757A))),
              ],
            ),
          ),
          if (isTeacher && roleLabel != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isLead ? const Color(0xFFF3E8FF) : const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isLead ? 'Lead' : 'Co-Teacher',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isLead ? const Color(0xFF7C3AED) : const Color(0xFF1A73E8),
                ),
              ),
            ),
            if (onRemove != null)
              IconButton(
                icon: const Icon(Icons.person_remove_outlined, size: 16, color: Colors.red),
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Remove co-teacher',
              ),
          ] else if (!isTeacher)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  size: 18, color: Color(0xFF70757A)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              itemBuilder: (_) => [
                if (onRemoveStudent != null)
                  const PopupMenuItem(
                    value: 'remove',
                    child: Row(children: [
                      Icon(Icons.person_remove_outlined, size: 18, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Remove from course', style: TextStyle(color: Colors.red)),
                    ]),
                  )
                else
                  const PopupMenuItem(
                    enabled: false,
                    child: Text('No actions available'),
                  ),
              ],
              onSelected: (v) {
                if (v == 'remove') onRemoveStudent?.call();
              },
            ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════
  // GRADES TAB (student)
  // ════════════════════════════════════════════════

  Widget _buildStudentGradesTab() {
    if (_loadingGrades) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final totalAssignments = _assignments.length;
    final gradedCount = _myGrades.where((g) => g['submission']?['status'] == 'graded').length;
    final attendedSessions = (_myAttendance?['present'] ?? 0) as num;
    final totalSessions = (_myAttendance?['total'] ?? 0) as num;
    final attendancePct = totalSessions > 0
        ? ((attendedSessions / totalSessions) * 100).round()
        : 0;

    return RefreshIndicator(
      onRefresh: () async {
        await _loadClasswork();
        await _loadStudentGrades();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        children: [
          // ── Summary cards row ──────────────────────────────
          Row(children: [
            Expanded(child: _gradeSummaryCard(
              'Assignments',
              '$gradedCount / $totalAssignments graded',
              Icons.assignment_turned_in_outlined,
              const Color(0xFF1A73E8),
            )),
            const SizedBox(width: 12),
            Expanded(child: _gradeSummaryCard(
              'Attendance',
              '$attendancePct%',
              Icons.how_to_reg_outlined,
              attendancePct >= 75 ? const Color(0xFF188038) : const Color(0xFFE37400),
            )),
            const SizedBox(width: 12),
            Expanded(child: _gradeSummaryCard(
              'Quizzes',
              '${_myQuizAttempts.length} taken',
              Icons.quiz_outlined,
              const Color(0xFF9334E6),
            )),
          ]),

          const SizedBox(height: 24),

          // ── Assignments grades ─────────────────────────────
          if (_assignments.isNotEmpty) ...[
            const Text('Assignments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF202124))),
            const SizedBox(height: 8),
            ..._assignments.map((a) {
              final assignId = a['_id']?.toString() ?? '';
              final grade = _myGrades.firstWhere(
                (g) => g['assignment']?['_id']?.toString() == assignId,
                orElse: () => null,
              );
              final submission = grade?['submission'];
              final title = a['title']?.toString() ?? 'Assignment';
              final totalMarks = a['totalMarks']?.toString() ?? '--';
              final obtained = submission?['marksObtained']?.toString();
              final submissionStatus = submission?['status']?.toString();
              final status = submission == null
                  ? 'Pending'
                  : submissionStatus == 'graded' ? 'Graded'
                  : (submissionStatus == 'submitted' || submissionStatus == 'late') ? 'Submitted'
                  : 'Pending';
              final feedback = submission?['feedback']?.toString() ?? '';
              final stars = submission?['stars'];
              final starCount = stars != null ? (stars as num).toInt() : 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDADCE0)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.assignment_outlined, size: 18, color: Color(0xFF1A73E8)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(title, style: const TextStyle(fontSize: 14, color: Color(0xFF202124), fontWeight: FontWeight.w500))),
                    _gradeChip(status, obtained, totalMarks),
                  ]),
                  if (starCount > 0) ...[
                    const SizedBox(height: 8),
                    Row(children: List.generate(5, (i) => Icon(
                      i < starCount ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 18,
                      color: i < starCount ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                    ))),
                  ],
                  if (feedback.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.comment_outlined, size: 14, color: Color(0xFF70757A)),
                        const SizedBox(width: 6),
                        Expanded(child: Text('Feedback: $feedback',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF5F6368)))),
                      ]),
                    ),
                  ],
                ]),
              );
            }),
            const SizedBox(height: 16),
          ],

          // ── Quiz scores ────────────────────────────────────
          if (_myQuizAttempts.isNotEmpty) ...[
            const Text('Quizzes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF202124))),
            const SizedBox(height: 8),
            ..._myQuizAttempts.map((attempt) {
              final quizTitle = attempt['quizTitle']?.toString()
                  ?? attempt['quiz']?['title']?.toString()
                  ?? 'Quiz';
              final score = attempt['score']?.toString() ?? attempt['obtainedMarks']?.toString() ?? '--';
              final total = attempt['totalMarks']?.toString() ?? attempt['quiz']?['totalMarks']?.toString() ?? '--';
              final passed = attempt['passed'] == true;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDADCE0)),
                ),
                child: Row(children: [
                  const Icon(Icons.quiz_outlined, size: 18, color: Color(0xFF9334E6)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(quizTitle, style: const TextStyle(fontSize: 14, color: Color(0xFF202124)))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: passed ? const Color(0xFFE6F4EA) : const Color(0xFFFCE8E6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$score / $total',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: passed ? const Color(0xFF188038) : const Color(0xFFD93025)),
                    ),
                  ),
                ]),
              );
            }),
            const SizedBox(height: 16),
          ],

          // ── Attendance detail ──────────────────────────────
          if (_myAttendance != null) ...[
            const Text('Attendance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF202124))),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDADCE0)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.how_to_reg_outlined, size: 20, color: Color(0xFF188038)),
                  const SizedBox(width: 8),
                  Text('${attendedSessions.toInt()} of ${totalSessions.toInt()} sessions attended',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF202124))),
                  const Spacer(),
                  Text('$attendancePct%', style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800,
                      color: attendancePct >= 75 ? const Color(0xFF188038) : const Color(0xFFE37400))),
                ]),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: totalSessions > 0 ? attendedSessions / totalSessions : 0,
                    backgroundColor: const Color(0xFFE8F0FE),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        attendancePct >= 75 ? const Color(0xFF188038) : const Color(0xFFE37400)),
                    minHeight: 8,
                  ),
                ),
                if (attendancePct < 75) ...[
                  const SizedBox(height: 8),
                  const Text('⚠️ Attendance below 75% may affect course completion.',
                      style: TextStyle(fontSize: 12, color: Color(0xFFD93025))),
                ],
                () {
                  final sessions = List<dynamic>.from(_myAttendance?['attendance'] ?? []);
                  if (sessions.isEmpty) return const SizedBox.shrink();
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    const Text('Session Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF70757A))),
                    const SizedBox(height: 8),
                    ...sessions.map((s) {
                      final st = s['status']?.toString() ?? 'absent';
                      final dateStr = s['sessionDate']?.toString() ?? '';
                      DateTime? date;
                      try { date = DateTime.parse(dateStr); } catch (_) {}
                      final stColor = st == 'present' ? const Color(0xFF188038) : st == 'late' ? const Color(0xFFE37400) : const Color(0xFFD93025);
                      final stBg = st == 'present' ? const Color(0xFFE6F4EA) : st == 'late' ? const Color(0xFFFFF3E0) : const Color(0xFFFCE8E6);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: stColor, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(s['sessionTitle']?.toString() ?? 'Session', style: const TextStyle(fontSize: 12, color: Color(0xFF202124)))),
                          if (date != null) Text(DateFormat('MMM d').format(date), style: const TextStyle(fontSize: 11, color: Color(0xFF70757A))),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: stBg, borderRadius: BorderRadius.circular(8)),
                            child: Text(st[0].toUpperCase() + st.substring(1), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: stColor)),
                          ),
                        ]),
                      );
                    }),
                  ]);
                }(),
              ]),
            ),
          ],

          // Empty state
          if (_assignments.isEmpty && _myQuizAttempts.isEmpty && _myAttendance == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.grade_outlined, size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text('No grades yet', style: TextStyle(fontSize: 15, color: Color(0xFF5F6368))),
                  const SizedBox(height: 4),
                  const Text('Complete assignments and quizzes to see your grades here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF70757A))),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _gradeSummaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF70757A))),
      ]),
    );
  }

  Widget _gradeChip(String status, String? obtained, String total) {
    Color bg;
    Color fg;
    String text;
    if (obtained != null) {
      bg = const Color(0xFFE6F4EA);
      fg = const Color(0xFF188038);
      text = '$obtained / $total';
    } else if (status == 'Submitted') {
      bg = const Color(0xFFFFF8E1);
      fg = const Color(0xFFE37400);
      text = 'Submitted';
    } else {
      bg = const Color(0xFFF1F3F4);
      fg = const Color(0xFF70757A);
      text = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  // ════════════════════════════════════════════════
  // GRADES TAB (instructor)
  // ════════════════════════════════════════════════

  Future<void> _loadAttendanceReport() async {
    if (_courseId.isEmpty) return;
    setState(() => _loadingAttendanceReport = true);
    try {
      final data = await _lms.getAttendanceReport(_courseId);
      if (mounted) setState(() => _attendanceReport = data);
    } catch (_) {}
    if (mounted) setState(() => _loadingAttendanceReport = false);
  }

  Widget _buildGradesTab() {
    if (_loadingClasswork) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadClasswork();
        await _loadAttendanceReport();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          // ── Assignments section ──
          if (_assignments.isNotEmpty) ...[
            const Text('Assignments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF202124))),
            const SizedBox(height: 8),
            ..._assignments.map((a) {
              final id = a['_id']?.toString() ?? '';
              final title = a['title']?.toString() ?? 'Assignment';
              final count = ((a['submissionCount'] ?? 0) as num).toInt();
              final total = a['totalMarks']?.toString() ?? '--';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 36, height: 36,
                  decoration: const BoxDecoration(color: Color(0xFF1A73E8), shape: BoxShape.circle),
                  child: const Icon(Icons.assignment_outlined, color: Colors.white, size: 18),
                ),
                title: Text(title, style: const TextStyle(fontSize: 14, color: Color(0xFF202124))),
                subtitle: Text('$count submitted  ·  $total pts', style: const TextStyle(fontSize: 12, color: Color(0xFF70757A))),
                trailing: id.isNotEmpty
                    ? OutlinedButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => InstructorGradingScreen(assignmentId: id, assignmentTitle: title),
                        )),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1A73E8),
                          side: const BorderSide(color: Color(0xFFDADCE0)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        child: const Text('View grades', style: TextStyle(fontSize: 13)),
                      )
                    : null,
              );
            }),
            const SizedBox(height: 24),
          ],

          // ── Attendance Report section ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Attendance Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF202124))),
              TextButton.icon(
                onPressed: _loadAttendanceReport,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loadingAttendanceReport)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2)))
          else
            _buildAttendanceReportTable(),

          if (_assignments.isEmpty && (_attendanceReport['students'] as List? ?? []).isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.grade_outlined, size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text('No grades or attendance yet', style: TextStyle(fontSize: 15, color: Color(0xFF5F6368))),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAttendanceReportTable() {
    final students = (_attendanceReport['students'] as List?) ?? [];

    if (students.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text('No attendance data yet. Sessions will appear here after live classes.',
            style: TextStyle(fontSize: 13, color: Color(0xFF70757A))),
      );
    }

    return Column(
      children: students.map((s) {
        final name = s['name']?.toString() ?? 'Student';
        final pct = (s['percentage'] as num? ?? 0).toInt();
        final present = (s['present'] as num? ?? 0).toInt();
        final total = (s['total'] as num? ?? 0).toInt();
        final late = (s['late'] as num? ?? 0).toInt();
        final pctColor = pct >= 75 ? const Color(0xFF188038) : pct >= 50 ? const Color(0xFFE37400) : const Color(0xFFD93025);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFDADCE0)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: pctColor.withValues(alpha: 0.12),
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'S',
                    style: TextStyle(color: pctColor, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF202124))),
                  Text('$present present · $late late · ${total - present - late} absent (of $total)',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF70757A))),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: pctColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$pct%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: pctColor)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Banner pattern painter (diagonal lines)
// ─────────────────────────────────────────────────────────────

class _BannerPatternPainter extends CustomPainter {
  final Color color;
  _BannerPatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const gap = 30.0;
    for (double i = -size.height; i < size.width + size.height; i += gap) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BannerPatternPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────
// Feed item model
// ─────────────────────────────────────────────────────────────

enum _FeedItemType { announcement, assignment }

class _FeedItem {
  final _FeedItemType type;
  final dynamic data;
  final DateTime? date;
  _FeedItem({required this.type, required this.data, this.date});
}

// ─────────────────────────────────────────────────────────────
// Embedded Course Content — full InstructorCourseContentScreen
// body rendered inline inside the Course Content tab
// ─────────────────────────────────────────────────────────────
class _EmbeddedCourseContent extends StatefulWidget {
  final String courseId;
  const _EmbeddedCourseContent({super.key, required this.courseId});

  @override
  State<_EmbeddedCourseContent> createState() => _EmbeddedCourseContentState();
}

class _EmbeddedCourseContentState extends State<_EmbeddedCourseContent> {
  final _screenKey = GlobalKey<InstructorCourseContentScreenState>();

  void triggerAddModule() => _screenKey.currentState?.addModule();

  @override
  Widget build(BuildContext context) {
    return InstructorCourseContentScreen(key: _screenKey, courseId: widget.courseId, embedded: true);
  }
}
