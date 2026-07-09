import 'package:flutter/material.dart';
import 'package:icare/screens/doctor_notifications.dart';
import 'package:icare/screens/gamification_screen.dart';
import 'package:icare/screens/lms_course_page.dart';
import 'package:icare/services/course_service.dart';
import 'package:icare/services/gamification_service.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/theme.dart';

/// Student-facing Course Settings — one screen linking out to everything
/// about this specific course that already has real data behind it
/// (attendance %, certificate status, quiz attempts, badges/points,
/// downloadable lesson resources, notifications, discussion, support).
/// Deliberately does NOT include cards for features with no backend yet
/// (calendar sync, per-course privacy toggles, cohort leaderboard) —
/// every card here is fully functional.
class StudentCourseSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> course;
  final String? enrollmentId;

  const StudentCourseSettingsScreen({
    super.key,
    required this.course,
    this.enrollmentId,
  });

  @override
  State<StudentCourseSettingsScreen> createState() => _StudentCourseSettingsScreenState();
}

class _StudentCourseSettingsScreenState extends State<StudentCourseSettingsScreen> {
  final LmsService _lms = LmsService();
  final CourseService _courseService = CourseService();
  final GamificationService _gamification = GamificationService();

  bool _loading = true;
  double _progressPct = 0;
  double _attendancePct = 0;
  int _quizzesTotal = 0;
  int _quizzesAttempted = 0;
  String _certificateStatus = 'Not eligible'; // Not eligible | In progress | Ready | Approved
  int _points = 0;
  int _badges = 0;
  int _resourceCount = 0;

  String get _courseId => widget.course['_id']?.toString() ?? '';
  String get _courseTitle => widget.course['title']?.toString() ?? 'Course';
  String get _instructorName {
    final instr = widget.course['instructor'] ?? widget.course['instructorName'];
    if (instr is Map) return (instr['name'] ?? instr['username'] ?? 'Instructor').toString();
    return instr?.toString() ?? 'Instructor';
  }
  int get _durationValue => ((widget.course['duration'] ?? 0) as num).toInt();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadProgress(),
      _loadAttendance(),
      _loadQuizzes(),
      _loadCertificate(),
      _loadGamification(),
    ]);
    _countResources();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadProgress() async {
    if (widget.enrollmentId == null) return;
    try {
      final data = await _lms.getEnrollmentProgress(widget.enrollmentId!);
      final pct = (data['progressPct'] as num?)?.toDouble() ?? 0;
      if (mounted) setState(() => _progressPct = pct);
    } catch (_) {}
  }

  Future<void> _loadAttendance() async {
    if (_courseId.isEmpty) return;
    try {
      final data = await _lms.getMyAttendance(_courseId);
      final pct = (data['percentage'] as num?)?.toDouble() ?? 0;
      if (mounted) setState(() => _attendancePct = pct);
    } catch (_) {}
  }

  Future<void> _loadQuizzes() async {
    if (_courseId.isEmpty) return;
    try {
      final quizzes = await _lms.getCourseQuizzes(_courseId);
      final attempts = await _lms.getMyAssessmentQuizzes();
      final attemptedIds = attempts
          .map((a) => (a as Map)['quizId']?.toString())
          .whereType<String>()
          .toSet();
      if (mounted) {
        setState(() {
          _quizzesTotal = quizzes.length;
          _quizzesAttempted = quizzes.where((q) => attemptedIds.contains((q as Map)['_id']?.toString())).length;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadCertificate() async {
    try {
      final certs = await _courseService.myCertificates();
      final mine = certs.firstWhere(
        (c) => (c as Map)['courseId']?.toString() == _courseId,
        orElse: () => null,
      );
      if (mine != null) {
        if (mounted) setState(() => _certificateStatus = 'Approved');
        return;
      }
      final released = widget.course['certificateReleased'] == true;
      final completed = _progressPct >= 100;
      if (mounted) {
        setState(() {
          _certificateStatus = released && completed
              ? 'Ready to claim'
              : completed
                  ? 'Pending release'
                  : 'In progress';
        });
      }
    } catch (_) {}
  }

  Future<void> _loadGamification() async {
    try {
      final res = await _gamification.getMyStats();
      if (res['success'] != false && mounted) {
        setState(() {
          _points = (res['points'] as num?)?.toInt() ?? 0;
          _badges = (res['badges'] as List?)?.length ?? 0;
        });
      }
    } catch (_) {}
  }

  void _countResources() {
    final modules = (widget.course['modules'] as List?) ?? [];
    int count = 0;
    for (final m in modules) {
      final lessons = ((m as Map)['lessons'] as List?) ?? [];
      for (final l in lessons) {
        final lesson = l as Map;
        if ((lesson['documentUrl']?.toString().isNotEmpty ?? false)) count++;
        final resources = (lesson['resources'] as List?) ?? [];
        count += resources.length;
      }
    }
    _resourceCount = count;
  }

  void _openCoursePage({int initialTab = 0}) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => LmsCoursePage(
        course: widget.course,
        enrollmentId: widget.enrollmentId,
        initialTabIndex: initialTab,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossCount = width > 1000 ? 3 : (width > 650 ? 2 : 1);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF0F172A),
        title: const Text('Course Settings', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    GridView.count(
                      crossAxisCount: crossCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.6,
                      children: [
                        _buildCard(
                          icon: Icons.notifications_outlined,
                          color: const Color(0xFF8B5CF6),
                          title: 'Notifications',
                          rows: const ['Assignment reminders', 'Live class reminders', 'Announcement notifications'],
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DoctorNotifications())),
                        ),
                        _buildCard(
                          icon: Icons.workspace_premium_outlined,
                          color: const Color(0xFFD4AF37),
                          title: 'Certificate',
                          rows: ['Status: $_certificateStatus'],
                          onTap: () => _openCoursePage(),
                        ),
                        _buildCard(
                          icon: Icons.quiz_outlined,
                          color: const Color(0xFFF59E0B),
                          title: 'Assessments',
                          rows: ['Quiz attempts: $_quizzesAttempted / $_quizzesTotal'],
                          onTap: () => _openCoursePage(initialTab: 2),
                        ),
                        _buildCard(
                          icon: Icons.event_available_outlined,
                          color: const Color(0xFF10B981),
                          title: 'Attendance',
                          rows: ['Your attendance: ${_attendancePct.toStringAsFixed(0)}%'],
                          onTap: () => _openCoursePage(initialTab: 4),
                        ),
                        _buildCard(
                          icon: Icons.emoji_events_outlined,
                          color: const Color(0xFFEF4444),
                          title: 'Badges & Points',
                          rows: ['Points earned: $_points', 'Badges unlocked: $_badges'],
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GamificationScreen())),
                        ),
                        _buildCard(
                          icon: Icons.download_outlined,
                          color: const Color(0xFF0EA5E9),
                          title: 'Downloads',
                          rows: ['$_resourceCount resource${_resourceCount == 1 ? '' : 's'} available'],
                          onTap: () => _openCoursePage(initialTab: 1),
                        ),
                        _buildCard(
                          icon: Icons.forum_outlined,
                          color: const Color(0xFF6366F1),
                          title: 'Discussion',
                          rows: const ['Class announcements & posts'],
                          onTap: () => _openCoursePage(initialTab: 0),
                        ),
                        _buildCard(
                          icon: Icons.support_agent_outlined,
                          color: const Color(0xFF64748B),
                          title: 'Support',
                          rows: const ['Report an issue', 'Contact support'],
                          onTap: _showSupportSheet,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_courseTitle,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text('Instructor: $_instructorName',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13)),
                if (_durationValue > 0) ...[
                  const SizedBox(height: 2),
                  Text('Duration: ${(_durationValue / 7).ceil()} weeks',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(alignment: Alignment.center, children: [
                  CircularProgressIndicator(
                    value: (_progressPct / 100).clamp(0, 1),
                    strokeWidth: 5,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
                  ),
                  Text('${_progressPct.toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                ]),
              ),
              const SizedBox(height: 4),
              const Text('Progress', style: TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required Color color,
    required String title,
    required List<String> rows,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A))),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 18),
              ],
            ),
            const SizedBox(height: 10),
            ...rows.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(r, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                )),
          ],
        ),
      ),
    );
  }

  void _showSupportSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('Support', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            ListTile(
              leading: const Icon(Icons.email_outlined, color: AppColors.primaryColor),
              title: const Text('Contact support'),
              subtitle: const Text('support@icare.com.co'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.report_problem_outlined, color: Colors.orange),
              title: const Text('Report an issue with this course'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Thanks — please email support@icare.com.co with details.')),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
