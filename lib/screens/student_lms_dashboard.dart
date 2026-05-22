import 'dart:async';
import 'package:flutter/material.dart';
import 'package:icare/screens/classroom_course_view.dart';
import 'package:icare/screens/lms_live_session_screen.dart';
import 'package:icare/screens/lms_public_catalog.dart';
import 'package:icare/screens/quiz_take_screen.dart';
import 'package:icare/screens/assignment_submit_screen.dart';
import 'package:icare/services/course_service.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';

class StudentLmsDashboard extends StatefulWidget {
  const StudentLmsDashboard({super.key});

  @override
  State<StudentLmsDashboard> createState() => _StudentLmsDashboardState();
}

class _StudentLmsDashboardState extends State<StudentLmsDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CourseService _courseService = CourseService();
  final LmsService _lmsService = LmsService();

  List<dynamic> _enrollments = [];
  List<Map<String, dynamic>> _allTodoItems = [];
  bool _loadingCourses = true;
  bool _loadingTodo = true;
  String _userName = '';

  // Global live session detector
  Timer? _globalLivePoller;
  Map<String, dynamic>? _activeLiveSession;
  final bool _liveDialogShown = false;
  final Set<String> _shownSessions = {}; // never re-show for same courseId

  static const List<Color> _classColors = [
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFFD84315),
    Color(0xFF00695C),
    Color(0xFF1976D2),
    Color(0xFFAD1457),
    Color(0xFF4527A0),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserName();
    _loadEnrollments();
    _startGlobalLivePolling();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _globalLivePoller?.cancel();
    super.dispose();
  }

  void _startGlobalLivePolling() {
    _checkAllCoursesForLive();
    _globalLivePoller = Timer.periodic(const Duration(seconds: 15), (_) => _checkAllCoursesForLive());
  }

  Future<void> _checkAllCoursesForLive() async {
    if (!mounted || _enrollments.isEmpty) return;
    for (final enrollment in _enrollments) {
      final course = enrollment['courseId'] as Map? ?? enrollment['course'] as Map? ?? {};
      final courseId = course['_id']?.toString() ?? enrollment['courseId']?.toString() ?? '';
      if (courseId.isEmpty) continue;
      try {
        final result = await _lmsService.checkActiveLiveSession(courseId);
        if (result['isLive'] == true && mounted) {
          final courseTitle = course['title']?.toString() ?? 'Your Course';
          if (LmsLiveSessionScreen.activeCourseId == courseId) return;
          if (_shownSessions.contains(courseId)) return; // already shown
          setState(() => _activeLiveSession = {'courseId': courseId, 'courseTitle': courseTitle});
          _shownSessions.add(courseId);
          _showLiveAlert(courseId, courseTitle, course);
          return;
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _activeLiveSession = null);
      _shownSessions.clear(); // Reset so next new session can show popup
    }
  }

  void _showLiveAlert(String courseId, String courseTitle, Map course) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFF1C2333),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.live_tv_rounded, color: Colors.red, size: 56),
          const SizedBox(height: 12),
          const Text('🔴 LIVE SESSION STARTED!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('$courseTitle\nis now live. Join now!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ]),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => LmsLiveSessionScreen(
                  sessionId: courseId,
                  courseId: courseId,
                  sessionTitle: courseTitle,
                  isInstructor: false,
                ),
              ));
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('JOIN NOW', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUserName() async {
    final user = await SharedPref().getUserData();
    if (mounted && user != null) {
      setState(() {
        _userName = user.name.isNotEmpty ? user.name : user.email.split('@').first;
      });
    }
  }

  Future<void> _loadEnrollments() async {
    setState(() {
      _loadingCourses = true;
      _loadingTodo = true;
    });
    try {
      final enrollments = await _courseService.myPurchases();
      if (mounted) {
        setState(() {
          _enrollments = enrollments;
          _loadingCourses = false;
        });
        await _loadTodoItems(enrollments);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingCourses = false;
          _loadingTodo = false;
        });
      }
    }
  }

  Future<void> _loadTodoItems(List<dynamic> enrollments) async {
    final List<Map<String, dynamic>> items = [];
    for (final enrollment in enrollments) {
      final course = enrollment['course'] as Map<String, dynamic>? ?? {};
      final courseId = course['_id']?.toString() ?? '';
      final courseName = course['title'] ?? course['name'] ?? 'Unknown Course';
      if (courseId.isEmpty) continue;

      try {
        final assignments = await _lmsService.getCourseAssignments(courseId);
        for (final a in assignments) {
          final submission = a['mySubmission'];
          if (submission == null) {
            items.add({
              ...Map<String, dynamic>.from(a is Map ? a : {}),
              '_type': 'assignment',
              '_courseName': courseName,
              '_courseId': courseId,
              '_enrollmentId': enrollment['_id']?.toString() ?? '',
            });
          }
        }
      } catch (_) {}

      try {
        final quizzes = await _lmsService.getCourseQuizzes(courseId);
        for (final q in quizzes) {
          items.add({
            ...Map<String, dynamic>.from(q is Map ? q : {}),
            '_type': 'quiz',
            '_courseName': courseName,
            '_courseId': courseId,
            '_enrollmentId': enrollment['_id']?.toString() ?? '',
          });
        }
      } catch (_) {}
    }

    items.sort((a, b) {
      final aDate = _parseDueDate(a);
      final bDate = _parseDueDate(b);
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });

    if (mounted) {
      setState(() {
        _allTodoItems = items;
        _loadingTodo = false;
      });
    }
  }

  DateTime? _parseDueDate(Map<String, dynamic> item) {
    final str = item['dueDate']?.toString() ?? '';
    if (str.isEmpty) return null;
    try {
      return DateTime.parse(str);
    } catch (_) {
      return null;
    }
  }

  Future<void> _refresh() async {
    await _loadEnrollments();
  }

  Color _cardColor(int index) => _classColors[index % _classColors.length];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.school_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'iCare Academy',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LmsPublicCatalog()),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
              child: Text(
                _userName.isNotEmpty ? _userName[0].toUpperCase() : 'S',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryColor,
                ),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryColor,
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: AppColors.primaryColor,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.class_rounded, size: 16),
                  SizedBox(width: 6),
                  Text('Classes'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 16),
                  const SizedBox(width: 6),
                  const Text('To-do'),
                  if (_allTodoItems.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_allTodoItems.length}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LmsPublicCatalog()),
        ),
        backgroundColor: AppColors.primaryColor,
        tooltip: 'Browse Courses',
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildClassesTab(isWide),
          _buildTodoTab(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CLASSES TAB — Google Classroom card grid
  // ═══════════════════════════════════════════════════════════

  Widget _buildClassesTab(bool isWide) {
    if (_loadingCourses) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_enrollments.isEmpty) {
      return _buildEmptyClasses();
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: GridView.builder(
        padding: EdgeInsets.all(isWide ? 24 : 16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isWide ? 3 : (MediaQuery.of(context).size.width > 600 ? 2 : 1),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isWide ? 1.1 : 1.0,
        ),
        itemCount: _enrollments.length,
        itemBuilder: (ctx, i) => _buildClassCard(_enrollments[i], i),
      ),
    );
  }

  Widget _buildClassCard(dynamic enrollment, int index) {
    final course = enrollment['course'] as Map<String, dynamic>? ?? {};
    final title = course['title'] ?? course['name'] ?? 'Untitled Course';
    final instructor = (course['instructor'] as Map?)?['name'] ??
        (course['instructor'] as Map?)?['username'] ??
        'iCare Instructor';
    final section = course['category'] ?? course['section'] ?? '';
    final progressData = enrollment['progress'];
    int progress = 0;
    if (progressData is int) {
      progress = progressData;
    } else if (progressData is Map) {
      progress = (progressData['percent'] ?? 0).toInt();
    }
    final color = _cardColor(index);
    final enrollmentId = enrollment['_id']?.toString();
    final courseId = course['_id']?.toString() ?? '';
    final isLive = _activeLiveSession?['courseId'] == courseId;

    return GestureDetector(
      onTap: () {
        if (isLive) {
          // Go directly to live session if this course is live
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => LmsLiveSessionScreen(
              sessionId: courseId,
              courseId: courseId,
              sessionTitle: title,
              isInstructor: false,
            ),
          ));
        } else {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => ClassroomCourseView(
              course: course,
              enrollmentId: enrollmentId,
              isInstructor: false,
            ),
          ));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isLive ? Colors.red : const Color(0xFFE2E8F0), width: isLive ? 2 : 1),
          boxShadow: isLive
              ? [BoxShadow(color: Colors.red.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colored header
            Container(
              height: 96,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isLive) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.circle, color: Colors.white, size: 8),
                            SizedBox(width: 4),
                            Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                          ]),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.menu_book_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (section.isNotEmpty)
                    Text(
                      section,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Instructor row
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Text(
                      instructor.isNotEmpty ? instructor[0].toUpperCase() : 'I',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: color),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      instructor,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                      Text(
                        '$progress%',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress / 100,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
            // Action buttons row (Google Classroom style)
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _cardIconBtn(
                    Icons.open_in_new_rounded,
                    'Open',
                    color,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClassroomCourseView(
                          course: course,
                          enrollmentId: enrollmentId,
                          isInstructor: false,
                        ),
                      ),
                    ),
                  ),
                  _cardIconBtn(
                    Icons.assignment_rounded,
                    'Classwork',
                    const Color(0xFF64748B),
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClassroomCourseView(
                          course: course,
                          enrollmentId: enrollmentId,
                          isInstructor: false,
                          initialTab: 1,
                        ),
                      ),
                    ),
                  ),
                  _cardIconBtn(
                    Icons.more_vert_rounded,
                    'More',
                    const Color(0xFF64748B),
                    () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardIconBtn(
      IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  Widget _buildEmptyClasses() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.class_rounded,
                  size: 64, color: AppColors.primaryColor),
            ),
            const SizedBox(height: 24),
            const Text(
              'No classes yet',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Browse the catalog and enroll in a course to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LmsPublicCatalog()),
              ),
              icon: const Icon(Icons.explore_rounded, size: 18),
              label: const Text('Browse Courses',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TO-DO TAB
  // ═══════════════════════════════════════════════════════════

  Widget _buildTodoTab() {
    if (_loadingTodo) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_allTodoItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 64, color: Color(0xFF10B981)),
            const SizedBox(height: 16),
            const Text(
              'You are all caught up!',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'No pending assignments or quizzes.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    // Group by due date
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final item in _allTodoItems) {
      final due = _parseDueDate(item);
      String groupKey;
      if (due == null) {
        groupKey = 'No due date';
      } else {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final dueDay = DateTime(due.year, due.month, due.day);
        final diff = dueDay.difference(today).inDays;
        if (diff < 0) {
          groupKey = 'Overdue';
        } else if (diff == 0) {
          groupKey = 'Due today';
        } else if (diff == 1) {
          groupKey = 'Due tomorrow';
        } else if (diff <= 7) {
          groupKey = 'Due this week';
        } else {
          groupKey = 'Upcoming';
        }
      }
      grouped.putIfAbsent(groupKey, () => []).add(item);
    }

    const order = [
      'Overdue',
      'Due today',
      'Due tomorrow',
      'Due this week',
      'Upcoming',
      'No due date'
    ];

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final key in order)
            if (grouped.containsKey(key)) ...[
              _todoSectionHeader(key),
              const SizedBox(height: 8),
              ...grouped[key]!.map((item) => _buildTodoItem(item)),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  Widget _todoSectionHeader(String title) {
    Color color;
    if (title == 'Overdue') {
      color = const Color(0xFFEF4444);
    } else if (title == 'Due today') {
      color = const Color(0xFFF59E0B);
    } else {
      color = const Color(0xFF64748B);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildTodoItem(Map<String, dynamic> item) {
    final isAssignment = item['_type'] == 'assignment';
    final title = item['title'] ?? (isAssignment ? 'Assignment' : 'Quiz');
    final courseName = item['_courseName'] ?? '';
    final due = _parseDueDate(item);
    final courseId = item['_courseId'] ?? '';
    final enrollmentId = item['_enrollmentId'] ?? '';

    final color = isAssignment ? const Color(0xFF0EA5E9) : const Color(0xFF8B5CF6);

    return GestureDetector(
      onTap: () {
        if (isAssignment) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AssignmentSubmitScreen(
                assignment: item,
                courseId: courseId,
                enrollmentId: enrollmentId.isNotEmpty ? enrollmentId : null,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QuizTakeScreen(
                quiz: item,
                enrollmentId: enrollmentId,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isAssignment
                    ? Icons.assignment_outlined
                    : Icons.quiz_outlined,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    courseName,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  if (due != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Due ${DateFormat('MMM dd, yyyy').format(due)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: due.isBefore(DateTime.now())
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: const Color(0xFFCBD5E1), size: 20),
          ],
        ),
      ),
    );
  }
}
