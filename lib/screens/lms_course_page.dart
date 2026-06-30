import 'package:flutter/material.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/screens/lesson_detail_page.dart';
import 'package:icare/screens/certificate_templates_screen.dart';
import 'package:icare/screens/quiz_take_screen.dart';
import 'package:icare/widgets/video_player_widget.dart';
import 'package:intl/intl.dart';

class LmsCoursePage extends StatefulWidget {
  final Map<String, dynamic> course;
  final String? enrollmentId;
  final bool isInstructor;

  const LmsCoursePage({
    super.key,
    required this.course,
    this.enrollmentId,
    this.isInstructor = false,
  });

  @override
  State<LmsCoursePage> createState() => _LmsCoursePageState();
}

class _LmsCoursePageState extends State<LmsCoursePage> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final LmsService _lms = LmsService();
  String get _courseId => widget.course['_id']?.toString() ?? '';
  String get _courseName => widget.course['title'] ?? 'Course';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.primaryColor;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: color,
            leading: const CustomBackButton(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 80, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_courseName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      widget.course['category'] ?? 'Healthcare',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabs,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(text: 'Stream'),
                Tab(text: 'Classwork'),
                Tab(text: 'Grades'),
                Tab(text: 'People'),
                Tab(text: 'Attendance'),
                Tab(text: 'Recordings'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            _StreamTab(courseId: _courseId, lms: _lms, isInstructor: widget.isInstructor),
            _ClassworkTab(courseId: _courseId, lms: _lms, isInstructor: widget.isInstructor, course: widget.course, enrollmentId: widget.enrollmentId),
            _GradesTab(courseId: _courseId, lms: _lms, isInstructor: widget.isInstructor, course: widget.course, enrollmentId: widget.enrollmentId),
            _PeopleTab(courseId: _courseId, lms: _lms, course: widget.course, isInstructor: widget.isInstructor),
            _AttendanceTab(courseId: _courseId, lms: _lms, isInstructor: widget.isInstructor),
            _RecordingsTab(courseId: _courseId, lms: _lms),
          ],
        ),
      ),
    );
  }
}

// ─── STREAM TAB (Announcements) ───────────────────────────────────────────────
class _StreamTab extends StatefulWidget {
  final String courseId;
  final LmsService lms;
  final bool isInstructor;
  const _StreamTab({required this.courseId, required this.lms, required this.isInstructor});

  @override
  State<_StreamTab> createState() => _StreamTabState();
}

class _StreamTabState extends State<_StreamTab> {
  List<dynamic> _posts = [];
  bool _loading = true;
  final _ctrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final posts = await widget.lms.getAnnouncements(widget.courseId);
    if (mounted) setState(() { _posts = posts; _loading = false; });
  }

  Future<void> _post() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    await widget.lms.postAnnouncement(widget.courseId, text);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.isInstructor) ...[
            _PostBox(ctrl: _ctrl, onPost: _post),
            const SizedBox(height: 16),
          ],
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
          if (!_loading && _posts.isEmpty)
            _EmptyState(icon: Icons.campaign_outlined, text: 'No announcements yet'),
          ..._posts.map((p) => _PostCard(post: p, lms: widget.lms, onRefresh: _load)),
        ],
      ),
    );
  }
}

class _PostBox extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onPost;
  const _PostBox({required this.ctrl, required this.onPost});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextField(
            controller: ctrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Announce something to your class...',
              border: InputBorder.none,
            ),
          ),
          ElevatedButton(
            onPressed: onPost,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white),
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final dynamic post;
  final LmsService lms;
  final VoidCallback onRefresh;
  const _PostCard({required this.post, required this.lms, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final comments = (post['comments'] as List?) ?? [];
    final ctrl = TextEditingController();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(backgroundColor: AppColors.primaryColor,
              child: Text((post['authorName'] ?? 'I')[0].toUpperCase(), style: const TextStyle(color: Colors.white))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(post['authorName'] ?? 'Instructor', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text(_fmt(post['createdAt']), style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ])),
          ]),
          const SizedBox(height: 12),
          Text(post['content'] ?? '', style: const TextStyle(fontSize: 14, height: 1.5)),
          if (comments.isNotEmpty) ...[
            const Divider(height: 20),
            ...comments.map((c) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const CircleAvatar(radius: 14, backgroundColor: Color(0xFFE2E8F0),
                  child: Icon(Icons.person, size: 14, color: Color(0xFF94A3B8))),
                const SizedBox(width: 8),
                Expanded(child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c['authorName'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    Text(c['text'] ?? '', style: const TextStyle(fontSize: 13)),
                  ]),
                )),
              ]),
            )),
          ],
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(
              controller: ctrl,
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
            )),
            IconButton(icon: const Icon(Icons.send_rounded, color: AppColors.primaryColor),
              onPressed: () async {
                if (ctrl.text.trim().isEmpty) return;
                await lms.addComment(post['_id'], ctrl.text.trim());
                ctrl.clear();
                onRefresh();
              }),
          ]),
        ],
      ),
    );
  }

  String _fmt(dynamic d) {
    if (d == null) return '';
    try { return DateFormat('MMM d, yyyy').format(DateTime.parse(d.toString())); } catch (_) { return ''; }
  }
}

// ─── CLASSWORK TAB ────────────────────────────────────────────────────────────
class _ClassworkTab extends StatefulWidget {
  final String courseId;
  final LmsService lms;
  final bool isInstructor;
  final Map<String, dynamic> course;
  final String? enrollmentId;
  const _ClassworkTab({required this.courseId, required this.lms, required this.isInstructor, required this.course, this.enrollmentId});

  @override
  State<_ClassworkTab> createState() => _ClassworkTabState();
}

class _ClassworkTabState extends State<_ClassworkTab> {
  List<dynamic> _assignments = [];
  List<dynamic> _quizzes = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final results = await Future.wait([
      widget.lms.getCourseAssignments(widget.courseId),
      widget.lms.getCourseQuizzes(widget.courseId),
    ]);
    if (mounted) {
      setState(() {
      _assignments = results[0];
      _quizzes = results[1];
      _loading = false;
    });
    }
  }

  void _showCreateDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl  = TextEditingController();
    final marksCtrl = TextEditingController(text: '100');
    DateTime? dueDate;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('Create Assignment'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title *', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Instructions', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: marksCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total Marks', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(dueDate == null ? 'Set Due Date' : DateFormat('MMM d, yyyy').format(dueDate!)),
            onPressed: () async {
              final d = await showDatePicker(context: ctx, initialDate: DateTime.now().add(const Duration(days: 7)),
                firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (d != null) setLocal(() => dueDate = d);
            },
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white),
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await widget.lms.createAssignment({
                'courseId': widget.courseId,
                'title': titleCtrl.text.trim(),
                'description': descCtrl.text.trim(),
                if (dueDate != null) 'dueDate': dueDate!.toIso8601String(),
                'totalMarks': int.tryParse(marksCtrl.text) ?? 100,
              });
              _load();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: widget.isInstructor
          ? FloatingActionButton.extended(
              onPressed: _showCreateDialog,
              backgroundColor: AppColors.primaryColor,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Assignment', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Course modules/lessons section
            _SectionHeader(title: 'Course Content', icon: Icons.menu_book_rounded),
            const SizedBox(height: 8),
            _CourseLessons(course: widget.course, enrollmentId: widget.enrollmentId, lms: widget.lms, isInstructor: widget.isInstructor),
            const SizedBox(height: 24),
            _SectionHeader(title: 'Assignments', icon: Icons.assignment_rounded),
            const SizedBox(height: 8),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (!_loading && _assignments.isEmpty)
              _EmptyState(icon: Icons.assignment_outlined, text: 'No assignments yet'),
            ..._assignments.map((a) => _AssignmentCard(
              assignment: a,
              lms: widget.lms,
              isInstructor: widget.isInstructor,
              onRefresh: _load,
            )),
            const SizedBox(height: 24),
            _SectionHeader(title: 'Quizzes', icon: Icons.quiz_outlined),
            const SizedBox(height: 8),
            if (_loading) const SizedBox.shrink(),
            if (!_loading && _quizzes.isEmpty)
              _EmptyState(icon: Icons.quiz_outlined, text: 'No quizzes yet'),
            ..._quizzes.map((q) => _QuizCard(
              quiz: q,
              lms: widget.lms,
              enrollmentId: widget.enrollmentId,
              isInstructor: widget.isInstructor,
            )),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: AppColors.primaryColor, size: 20),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
    ]);
  }
}

class _CourseLessons extends StatelessWidget {
  final Map<String, dynamic> course;
  final String? enrollmentId;
  final LmsService lms;
  final bool isInstructor;
  const _CourseLessons({required this.course, this.enrollmentId, required this.lms, this.isInstructor = false});

  @override
  Widget build(BuildContext context) {
    final modules = (course['modules'] as List?) ?? [];
    if (modules.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: const Text('No lessons added yet', style: TextStyle(color: Color(0xFF94A3B8))),
      );
    }

    final isPragmatic = course['courseType']?.toString().toLowerCase() == 'pragmatic';
    final isSelfPaced = !isPragmatic;
    final isInstructor = this.isInstructor;
    final courseStart = course['startDate'] != null
        ? DateTime.tryParse(course['startDate'].toString())
        : null;
    final completedModuleIds = <String>{};
    final rawCompleted = course['_completedModules'];
    if (rawCompleted is List) {
      for (final id in rawCompleted) { completedModuleIds.add(id.toString()); }
    }

    DateTime? pragmaticUnlockDate(int index) {
      if (!isPragmatic || courseStart == null) return null;
      int days = 0;
      for (int i = 0; i < index; i++) {
        days += ((modules[i] as Map)['durationDays'] as num? ?? 7).toInt();
      }
      return courseStart.add(Duration(days: days));
    }

    bool isModuleLocked(int index) {
      if (index == 0) return false;
      if (isInstructor) return false;
      if (isPragmatic) {
        final unlock = pragmaticUnlockDate(index);
        return unlock != null && DateTime.now().isBefore(unlock);
      }
      if (isSelfPaced) {
        final prevId = (modules[index - 1] as Map)['_id']?.toString() ?? '';
        if (prevId.isNotEmpty && !completedModuleIds.contains(prevId)) return true;
      }
      return false;
    }

    return Column(children: modules.asMap().entries.map((me) {
      final m = me.value as Map;
      final moduleId = m['_id']?.toString() ?? '';
      final lessons = (m['lessons'] as List?) ?? [];
      final quizzes = (m['quizzes'] as List?) ?? [];
      final locked = isModuleLocked(me.key);
      final unlockDate = isPragmatic ? pragmaticUnlockDate(me.key) : null;

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: locked ? const Color(0xFFF8FAFC) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
        ),
        child: locked
            ? ListTile(
                leading: CircleAvatar(radius: 16, backgroundColor: Colors.grey.shade200,
                  child: Text('${me.key + 1}', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w700, fontSize: 12))),
                title: Text(m['title'] ?? 'Module ${me.key + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF94A3B8))),
                subtitle: Text(
                  isPragmatic && unlockDate != null
                      ? 'Unlocks ${DateFormat('MMM d, yyyy').format(unlockDate)}'
                      : 'Complete the previous module to unlock',
                  style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1))),
                trailing: const Icon(Icons.lock_outline_rounded, color: Color(0xFFCBD5E1), size: 20),
              )
            : ExpansionTile(
                leading: CircleAvatar(radius: 16, backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                  child: Text('${me.key + 1}', style: TextStyle(color: AppColors.primaryColor, fontWeight: FontWeight.w700, fontSize: 12))),
                title: Text(m['title'] ?? 'Module ${me.key + 1}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: Text('${lessons.length} lessons · ${quizzes.length} quizzes', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                children: [
                  ...lessons.map((l) {
                    final liveDateTime = l['liveSessionDateTime'] != null
                        ? DateTime.tryParse(l['liveSessionDateTime'].toString())
                        : null;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: Icon(
                            liveDateTime != null ? Icons.video_call_rounded : Icons.play_circle_outline_rounded,
                            color: liveDateTime != null ? const Color(0xFF6366F1) : AppColors.primaryColor,
                            size: 20,
                          ),
                          title: Text(l['title'] ?? 'Lesson', style: const TextStyle(fontSize: 13)),
                          dense: true,
                          subtitle: liveDateTime != null
                              ? Text(
                                  'Live: ${liveDateTime.day}/${liveDateTime.month}/${liveDateTime.year}  ${liveDateTime.hour.toString().padLeft(2,'0')}:${liveDateTime.minute.toString().padLeft(2,'0')}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF6366F1), fontWeight: FontWeight.w600),
                                )
                              : null,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LessonDetailPage(
                                lesson: l,
                                courseId: course['_id']?.toString() ?? '',
                                moduleId: moduleId,
                                enrollmentId: enrollmentId,
                              ),
                            ),
                          ),
                        ),
                        if (liveDateTime != null && l['liveSessionNote'] != null && (l['liveSessionNote'] as String).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 52, right: 16, bottom: 4),
                            child: Text(l['liveSessionNote'].toString(), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ),
                      ],
                    );
                  }),
                  ...quizzes.map((q) => ListTile(
                    leading: const Icon(Icons.quiz_outlined, color: Colors.orange, size: 20),
                    title: Text(q['title'] ?? 'Quiz', style: const TextStyle(fontSize: 13)),
                    trailing: !isInstructor ? const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey) : null,
                    dense: true,
                    onTap: isInstructor ? null : () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => QuizTakeScreen(quiz: Map<String, dynamic>.from(q is Map ? q : {}), enrollmentId: enrollmentId ?? ''),
                    )),
                  )),
                  if (!isInstructor && moduleId.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: ElevatedButton.icon(
                        onPressed: () => _markModuleComplete(context, moduleId),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Mark Module as Complete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                ],
              ),
      );
    }).toList());
  }

  Future<void> _markModuleComplete(BuildContext context, String moduleId) async {
    try {
      if (enrollmentId == null || enrollmentId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enrollment not found'), backgroundColor: Colors.red),
        );
        return;
      }

      final result = await lms.markModuleComplete(
        enrollmentId: enrollmentId!,
        moduleId: moduleId,
      );

      if (context.mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Module marked as complete! Instructor has been notified.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to mark complete'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ─── QUIZ CARD ────────────────────────────────────────────────────────────────
class _QuizCard extends StatelessWidget {
  final dynamic quiz;
  final LmsService lms;
  final String? enrollmentId;
  final bool isInstructor;
  const _QuizCard({required this.quiz, required this.lms, this.enrollmentId, required this.isInstructor});

  @override
  Widget build(BuildContext context) {
    final questions = (quiz['questions'] as List? ?? []).length;
    final totalMarks = quiz['totalMarks'] ?? quiz['passingScore'] ?? 0;
    final timeLimit = quiz['timeLimit'];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: Colors.indigo.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.quiz_outlined, color: Colors.indigo, size: 22),
        ),
        title: Text(quiz['title'] ?? 'Quiz', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (quiz['description'] != null && quiz['description'].toString().isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 2),
              child: Text(quiz['description'], style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)), maxLines: 2, overflow: TextOverflow.ellipsis)),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.help_outline_rounded, size: 12, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text('$questions questions', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(width: 12),
            Icon(Icons.score_rounded, size: 12, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text('$totalMarks marks', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            if (timeLimit != null) ...[
              const SizedBox(width: 12),
              Icon(Icons.timer_outlined, size: 12, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text('${timeLimit}m', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ]),
        ]),
        trailing: isInstructor
            ? const Icon(Icons.visibility_outlined, color: Colors.grey, size: 20)
            : ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => QuizTakeScreen(quiz: _quizMap, enrollmentId: enrollmentId ?? ''),
                )),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                child: const Text('Attempt'),
              ),
      ),
    );
  }

  Map<String, dynamic> get _quizMap => Map<String, dynamic>.from(quiz is Map ? quiz as Map : {});
}

class _AssignmentCard extends StatelessWidget {
  final dynamic assignment;
  final LmsService lms;
  final bool isInstructor;
  final VoidCallback onRefresh;
  const _AssignmentCard({required this.assignment, required this.lms, required this.isInstructor, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final due = assignment['dueDate'];
    final isOverdue = due != null && DateTime.now().isAfter(DateTime.parse(due.toString()));
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: AppColors.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.assignment_rounded, color: AppColors.primaryColor, size: 22),
        ),
        title: Text(assignment['title'] ?? 'Assignment', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (assignment['description'] != null && assignment['description'].toString().isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 2),
              child: Text(assignment['description'], style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)), maxLines: 2, overflow: TextOverflow.ellipsis)),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.score_rounded, size: 12, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text('${assignment['totalMarks']} marks', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            if (due != null) ...[
              const SizedBox(width: 12),
              Icon(Icons.schedule_rounded, size: 12, color: isOverdue ? Colors.red : Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                'Due ${DateFormat('MMM d').format(DateTime.parse(due.toString()))}',
                style: TextStyle(fontSize: 12, color: isOverdue ? Colors.red : const Color(0xFF64748B)),
              ),
            ],
          ]),
        ]),
        trailing: isInstructor
            ? TextButton(
                onPressed: () => _showSubmissions(context),
                child: const Text('Submissions'),
              )
            : ElevatedButton(
                onPressed: () => _showSubmitDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Submit', style: TextStyle(fontSize: 12)),
              ),
      ),
    );
  }

  void _showSubmitDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('Submit: ${assignment['title']}'),
      content: TextField(controller: ctrl, maxLines: 5,
        decoration: const InputDecoration(labelText: 'Your answer / notes', border: OutlineInputBorder())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white),
          onPressed: () async {
            Navigator.pop(ctx);
            final result = await lms.submitAssignment(assignmentId: assignment['_id'], content: ctrl.text.trim());
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(result['success'] == true ? 'Submitted successfully!' : (result['message'] ?? 'Failed')),
                backgroundColor: result['success'] == true ? Colors.green : Colors.red,
              ));
            }
          },
          child: const Text('Submit'),
        ),
      ],
    ));
  }

  void _showSubmissions(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _SubmissionsPage(
      assignment: assignment, lms: lms,
    )));
  }
}

// ─── SUBMISSIONS PAGE (Instructor) ────────────────────────────────────────────
class _SubmissionsPage extends StatefulWidget {
  final dynamic assignment;
  final LmsService lms;
  const _SubmissionsPage({required this.assignment, required this.lms});

  @override
  State<_SubmissionsPage> createState() => _SubmissionsPageState();
}

class _SubmissionsPageState extends State<_SubmissionsPage> {
  List<dynamic> _subs = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final s = await widget.lms.getSubmissions(widget.assignment['_id']);
    if (mounted) setState(() { _subs = s; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: const CustomBackButton(),
        title: Text('${widget.assignment['title']} — Submissions',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _subs.isEmpty
              ? _EmptyState(icon: Icons.inbox_rounded, text: 'No submissions yet')
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _subs.length,
                  itemBuilder: (ctx, i) {
                    final s = _subs[i];
                    final student = s['studentId'];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          CircleAvatar(backgroundColor: AppColors.primaryColor,
                            child: Text((student?['name'] ?? 'S')[0].toUpperCase(), style: const TextStyle(color: Colors.white))),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(student?['name'] ?? student?['username'] ?? 'Student',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(student?['email'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                          ])),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: s['status'] == 'graded' ? Colors.green.withValues(alpha: 0.1)
                                  : s['status'] == 'late' ? Colors.red.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              s['status'] == 'graded' ? '${s['marksObtained']}/${widget.assignment['totalMarks']}'
                                  : (s['status'] ?? 'submitted').toUpperCase(),
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                color: s['status'] == 'graded' ? Colors.green
                                    : s['status'] == 'late' ? Colors.red : Colors.orange),
                            ),
                          ),
                        ]),
                        if (s['content'] != null && s['content'].toString().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
                            child: Text(s['content'], style: const TextStyle(fontSize: 13)),
                          ),
                        ],
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.grade_rounded, size: 16),
                          label: Text(s['status'] == 'graded' ? 'Update Grade' : 'Grade'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          onPressed: () => _showGradeDialog(s),
                        ),
                      ]),
                    );
                  },
                ),
    );
  }

  void _showGradeDialog(dynamic sub) {
    final marksCtrl = TextEditingController(text: sub['marksObtained']?.toString() ?? '');
    final feedbackCtrl = TextEditingController(text: sub['feedback'] ?? '');
    final commentsCtrl = TextEditingController(text: sub['comments'] ?? '');
    String selectedRubric = sub['rubricGrade'] ?? 'Satisfactory';
    int selectedStars = sub['stars'] ?? 3;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Grade Submission', style: TextStyle(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Marks
                TextField(
                  controller: marksCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Marks (out of ${widget.assignment['totalMarks']})',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.score_rounded),
                  ),
                ),
                const SizedBox(height: 16),

                // Rubric Dropdown
                const Text('Rubric Grade', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedRubric,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.assessment_rounded),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Excellent', child: Text('Excellent')),
                    DropdownMenuItem(value: 'Satisfactory', child: Text('Satisfactory')),
                    DropdownMenuItem(value: 'Average', child: Text('Average')),
                    DropdownMenuItem(value: 'Needs Improvement', child: Text('Needs Improvement')),
                  ],
                  onChanged: (value) => setState(() => selectedRubric = value!),
                ),
                const SizedBox(height: 16),

                // Star Rating
                const Text('Star Rating', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < selectedStars ? Icons.star_rounded : Icons.star_border_rounded,
                        color: index < selectedStars ? Colors.amber : Colors.grey,
                        size: 32,
                      ),
                      onPressed: () => setState(() => selectedStars = index + 1),
                    );
                  }),
                ),
                const SizedBox(height: 16),

                // Feedback
                TextField(
                  controller: feedbackCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Feedback',
                    hintText: 'Provide constructive feedback...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.feedback_rounded),
                  ),
                ),
                const SizedBox(height: 12),

                // Comments
                TextField(
                  controller: commentsCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Additional Comments (optional)',
                    hintText: 'Any additional notes...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.comment_rounded),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.check_rounded, size: 18),
              onPressed: () async {
                Navigator.pop(ctx);
                final marks = int.tryParse(marksCtrl.text);
                if (marks == null) return;

                await widget.lms.gradeSubmission(
                  sub['_id'],
                  marks,
                  feedback: feedbackCtrl.text.trim(),
                  rubricGrade: selectedRubric,
                  stars: selectedStars,
                  comments: commentsCtrl.text.trim(),
                );

                _load();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Graded successfully with rubric!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              label: const Text('Save Grade'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── GRADES TAB ───────────────────────────────────────────────────────────────
class _GradesTab extends StatefulWidget {
  final String courseId;
  final LmsService lms;
  final bool isInstructor;
  final Map<String, dynamic> course;
  final String? enrollmentId;
  const _GradesTab({required this.courseId, required this.lms, required this.isInstructor, required this.course, this.enrollmentId});

  @override
  State<_GradesTab> createState() => _GradesTabState();
}

class _GradesTabState extends State<_GradesTab> {
  List<dynamic> _grades = [];
  List<dynamic> _pendingCerts = [];
  bool _loading = true;
  bool _certLoading = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final futures = <Future>[
      widget.lms.getCourseGrades(widget.courseId).then((g) => _grades = g),
      if (widget.isInstructor) widget.lms.getPendingCertificates(widget.courseId).then((c) => _pendingCerts = c),
    ];
    await Future.wait(futures);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _approveCert(String certId, String studentName, String action) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(action == 'approve' ? 'Approve Certificate' : 'Reject Certificate'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${action == 'approve' ? 'Approve' : 'Reject'} certificate for $studentName?'),
          const SizedBox(height: 12),
          TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder()), maxLines: 2),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'approve' ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(action == 'approve' ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await widget.lms.approveCertificate(certId, action: action, note: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['success'] == true ? 'Done!' : result['message'] ?? 'Failed'),
        backgroundColor: result['success'] == true ? Colors.green : Colors.red,
      ));
      if (result['success'] == true) _load();
    }
  }

  double get _average {
    final graded = _grades.where((g) => g['submission']?['marksObtained'] != null);
    if (graded.isEmpty) return 0;
    final sum = graded.fold<double>(0, (s, g) {
      final m = (g['submission']['marksObtained'] as num).toDouble();
      final t = (g['assignment']['totalMarks'] as num).toDouble();
      return s + (t > 0 ? (m / t) * 100 : 0);
    });
    return sum / graded.length;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Overall grade card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryColor, Color(0xFF6366F1)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Overall Grade', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text('${_average.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                Text('${_grades.where((g) => g['submission'] != null).length}/${_grades.length} submitted',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
              Container(
                width: 70, height: 70,
                decoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                child: Center(child: Text(
                  _average >= 90 ? 'A' : _average >= 80 ? 'B' : _average >= 70 ? 'C' : _average >= 60 ? 'D' : 'F',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                )),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // Instructor: pending certificate approvals
          if (widget.isInstructor && _pendingCerts.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Text('Pending Certificate Approvals (${_pendingCerts.length})',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                ]),
                const SizedBox(height: 10),
                ..._pendingCerts.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    CircleAvatar(radius: 16, backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                      child: Text((c['studentName'] ?? 'S')[0].toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primaryColor))),
                    const SizedBox(width: 10),
                    Expanded(child: Text(c['studentName'] ?? 'Student',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                    TextButton(
                      onPressed: () => _approveCert(c['_id'].toString(), c['studentName'] ?? 'Student', 'reject'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red, minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 8)),
                      child: const Text('Reject', style: TextStyle(fontSize: 12)),
                    ),
                    ElevatedButton(
                      onPressed: () => _approveCert(c['_id'].toString(), c['studentName'] ?? 'Student', 'approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, foregroundColor: Colors.white,
                        minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: const Text('Approve'),
                    ),
                  ]),
                )),
              ]),
            ),
          ],

          // Certificate Button (show if released by instructor and average >= 70%)
          if (!widget.isInstructor && widget.course['certificateReleased'] == true && _average >= 70)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: ElevatedButton.icon(
                onPressed: _certLoading ? null : () async {
                  setState(() => _certLoading = true);
                  try {
                    final user = await SharedPref().getUserData();
                    final userId = user?.id;
                    if (userId == null || !context.mounted) return;
                    final result = await widget.lms.generateCertificate(
                      courseId: widget.courseId,
                      studentId: userId,
                      enrollmentId: widget.enrollmentId,
                      template: widget.course['certificateTemplate']?.toString(),
                    );
                    if (!context.mounted) return;
                    final cert = result['certificate'];
                    if (cert == null) throw Exception('Certificate not found');
                    CertificateTemplate tpl;
                    switch ((cert['template']?.toString() ?? '').toLowerCase()) {
                      case 'modern':      tpl = CertificateTemplate.modern; break;
                      case 'elegant':     tpl = CertificateTemplate.elegant; break;
                      case 'achievement': tpl = CertificateTemplate.achievement; break;
                      default:            tpl = CertificateTemplate.classic;
                    }
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => LmsCertificateScreen(
                        studentName: cert['studentName']?.toString() ?? user?.name ?? 'Student',
                        courseTitle: cert['courseName']?.toString() ?? widget.course['title']?.toString() ?? 'Course',
                        instructorName: cert['instructorName']?.toString() ?? 'Instructor',
                        template: tpl,
                        completionDate: cert['completionDate'] != null ? DateTime.tryParse(cert['completionDate'].toString()) : null,
                        enrollmentId: cert['enrollmentId']?.toString() ?? widget.enrollmentId ?? '',
                        courseId: widget.courseId,
                      ),
                    ));
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Could not load certificate: ${e.toString().replaceAll("Exception: ", "")}'),
                        backgroundColor: Colors.red,
                      ));
                    }
                  } finally {
                    if (mounted) setState(() => _certLoading = false);
                  }
                },
                icon: _certLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.workspace_premium_rounded, size: 20),
                label: Text(_certLoading ? 'Loading...' : 'View Certificate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade600,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

          if (_grades.isEmpty) _EmptyState(icon: Icons.grade_outlined, text: 'No assignments yet'),
          ..._grades.map((g) {
            final a = g['assignment'];
            final s = g['submission'];
            final graded = s != null && s['marksObtained'] != null;
            final percent = graded ? ((s['marksObtained'] as num) / (a['totalMarks'] as num) * 100) : null;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a['title'] ?? 'Assignment', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text('Max: ${a['totalMarks']} marks', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    if (a['passingMarks'] != null) ...[
                      const Text(' · ', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      Text('Pass: ${a['passingMarks']}', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    ],
                  ]),
                  if (s == null) const Text('Not submitted', style: TextStyle(fontSize: 12, color: Colors.red)),
                  if (s != null && !graded) const Text('Submitted — Awaiting grade', style: TextStyle(fontSize: 12, color: Colors.orange)),
                  if (graded && (s['stars'] ?? 0) > 0)
                    Row(children: List.generate(5, (i) => Icon(
                      i < (s['stars'] as num) ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: Colors.amber, size: 16,
                    ))),
                  if (graded && s['feedback'] != null && s['feedback'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('Feedback: ${s['feedback']}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ),
                ])),
                if (graded)
                  Column(children: [
                    Text('${s['marksObtained']}/${a['totalMarks']}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.primaryColor)),
                    Text('${percent!.toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 12,
                        color: percent >= 70 ? Colors.green : percent >= 50 ? Colors.orange : Colors.red)),
                  ])
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Text(s == null ? '—' : 'Pending', style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                  ),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

// ─── PEOPLE TAB ───────────────────────────────────────────────────────────────
class _PeopleTab extends StatefulWidget {
  final String courseId;
  final LmsService lms;
  final Map<String, dynamic> course;
  final bool isInstructor;
  const _PeopleTab({required this.courseId, required this.lms, required this.course, required this.isInstructor});

  @override
  State<_PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends State<_PeopleTab> {
  List<dynamic> _students = [];
  List<dynamic> _coInstructors = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final futures = <Future>[];
    if (widget.isInstructor) {
      futures.add(widget.lms.getEnrolledStudents(widget.courseId).then((s) => _students = s));
      futures.add(widget.lms.getCourseInstructors(widget.courseId).then((i) => _coInstructors = i));
    }
    await Future.wait(futures);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _showInviteTeacherDialog() async {
    final emailCtrl = TextEditingController();
    String selectedRole = 'normal';
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) => AlertDialog(
        title: const Text('Invite Teacher', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Teacher Email *', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 14),
          const Align(alignment: Alignment.centerLeft, child: Text('Role', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _roleChip('Lead Instructor', 'lead', selectedRole, (v) => setDlg(() => selectedRole = v))),
            const SizedBox(width: 8),
            Expanded(child: _roleChip('Normal Instructor', 'normal', selectedRole, (v) => setDlg(() => selectedRole = v))),
          ]),
          const SizedBox(height: 8),
          Text(
            selectedRole == 'lead'
                ? 'Full permissions including certificate approval.'
                : 'Limited: cannot approve certificates.',
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(ctx);
              final result = await widget.lms.inviteTeacher(courseId: widget.courseId, email: email, role: selectedRole);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(result['message'] ?? (result['success'] == true ? 'Invitation sent!' : 'Failed to send invite')),
                  backgroundColor: result['success'] == true ? Colors.green : Colors.red,
                ));
                if (result['success'] == true) _load();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white),
            child: const Text('Send Invite'),
          ),
        ],
      )),
    );
  }

  Widget _roleChip(String label, String value, String selected, void Function(String) onTap) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryColor.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppColors.primaryColor : const Color(0xFFE2E8F0)),
        ),
        child: Center(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
          color: isSelected ? AppColors.primaryColor : const Color(0xFF64748B)))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Instructors section
        Row(children: [
          Expanded(child: _SectionHeader(title: 'Instructors', icon: Icons.school_rounded)),
          if (widget.isInstructor)
            TextButton.icon(
              onPressed: _showInviteTeacherDialog,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
              label: const Text('Invite Teacher'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primaryColor),
            ),
        ]),
        const SizedBox(height: 8),
        _PersonTile(name: widget.course['instructorName'] ?? 'Instructor', role: 'Lead Instructor', isInstructor: true, badge: 'Lead'),
        ..._coInstructors.map((t) => _PersonTile(
          name: t['name'] ?? 'Instructor',
          role: t['email'] ?? '',
          isInstructor: true,
          badge: t['role'] == 'lead' ? 'Lead' : 'Normal',
        )),
        const SizedBox(height: 20),
        // ── Students section
        _SectionHeader(title: 'Students (${_students.length})', icon: Icons.group_rounded),
        const SizedBox(height: 8),
        if (!widget.isInstructor)
          _EmptyState(icon: Icons.group_outlined, text: 'Enroll to see classmates'),
        if (widget.isInstructor && _students.isEmpty)
          _EmptyState(icon: Icons.group_outlined, text: 'No students enrolled yet'),
        ..._students.map((s) => _PersonTile(
          name: s['name'] ?? 'Student',
          role: s['email'] ?? '',
          isInstructor: false,
          progress: s['progress'],
        )),
      ],
    );
  }
}

class _PersonTile extends StatelessWidget {
  final String name;
  final String role;
  final bool isInstructor;
  final dynamic progress;
  final String? badge;
  const _PersonTile({required this.name, required this.role, required this.isInstructor, this.progress, this.badge});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: isInstructor ? AppColors.primaryColor : const Color(0xFFE2E8F0),
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(color: isInstructor ? Colors.white : const Color(0xFF64748B), fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          Text(role, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        ])),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badge == 'Lead' ? AppColors.primaryColor.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(badge!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
              color: badge == 'Lead' ? AppColors.primaryColor : const Color(0xFF64748B))),
          ),
        if (badge == null && progress != null && progress['completed'] == true)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Text('Completed', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }
}

// ─── ATTENDANCE TAB ───────────────────────────────────────────────────────────
class _AttendanceTab extends StatefulWidget {
  final String courseId;
  final LmsService lms;
  final bool isInstructor;
  const _AttendanceTab({required this.courseId, required this.lms, required this.isInstructor});

  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab> {
  bool _loading = true;
  List<dynamic> _sessions = [];
  Map<String, dynamic> _myAttendance = {};

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    setState(() => _loading = true);
    if (widget.isInstructor) {
      final sessions = await widget.lms.getCourseAttendance(widget.courseId);
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _loading = false;
        });
      }
    } else {
      final data = await widget.lms.getMyAttendance(widget.courseId);
      if (mounted) {
        setState(() {
          _myAttendance = data;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.isInstructor) {
      return _buildInstructorView();
    } else {
      return _buildStudentView();
    }
  }

  Widget _buildStudentView() {
    final attendance = _myAttendance['attendance'] as List? ?? [];
    final total = _myAttendance['total'] ?? 0;
    final present = _myAttendance['present'] ?? 0;
    final percentage = _myAttendance['percentage'] ?? 0;

    if (attendance.isEmpty) {
      return const _EmptyState(icon: Icons.event_available, text: 'No attendance records yet');
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryColor, AppColors.primaryColor.withValues(alpha: 0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: AppColors.primaryColor.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard('Total', total.toString(), Icons.calendar_today),
              Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3)),
              _buildStatCard('Present', present.toString(), Icons.check_circle),
              Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3)),
              _buildStatCard('Attendance', '$percentage%', Icons.trending_up),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: attendance.length,
            itemBuilder: (ctx, i) {
              final record = attendance[i];
              final status = record['status'] ?? 'absent';
              final isPresent = status == 'present';
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isPresent ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isPresent ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isPresent ? Icons.check_circle : Icons.cancel,
                        color: isPresent ? Colors.green : Colors.red,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record['sessionTitle'] ?? 'Class Session',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(record['sessionDate']),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: status == 'present' ? Colors.green : status == 'late' ? Colors.orange : Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status == 'present' ? 'Present' : status == 'late' ? 'Late' : 'Absent',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12)),
      ],
    );
  }

  Widget _buildInstructorView() {
    if (_sessions.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _EmptyState(icon: Icons.event_available, text: 'No attendance sessions yet'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showCreateSessionDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create Session'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_sessions.length} Sessions', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ElevatedButton.icon(
                onPressed: _showCreateSessionDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Session'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _sessions.length,
            itemBuilder: (ctx, i) {
              final session = _sessions[i];
              final records = session['records'] as List? ?? [];
              final presentCount = records.where((r) => r['status'] == 'present').length;
              final lateCount = records.where((r) => r['status'] == 'late').length;
              final marked = records.isNotEmpty;
              return InkWell(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _MarkAttendanceScreen(
                        session: session,
                        courseId: widget.courseId,
                        lms: widget.lms,
                      ),
                    ),
                  );
                  _loadAttendance();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: marked ? AppColors.primaryColor.withValues(alpha: 0.2) : const Color(0xFFE2E8F0)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.how_to_reg_rounded, color: AppColors.primaryColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session['sessionTitle'] ?? 'Class Session',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _formatDate(session['sessionDate']),
                              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            ),
                            if (marked) ...[
                              const SizedBox(height: 6),
                              Row(children: [
                                _miniChip('$presentCount Present', Colors.green),
                                const SizedBox(width: 6),
                                if (lateCount > 0) _miniChip('$lateCount Late', Colors.orange),
                                const SizedBox(width: 6),
                                _miniChip('${records.length - presentCount - lateCount} Absent', Colors.red),
                              ]),
                            ] else
                              const Text('Tap to mark attendance', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showCreateSessionDialog() {
    final titleController = TextEditingController();
    final dateController = TextEditingController(text: DateTime.now().toIso8601String().split('T')[0]);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Attendance Session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Session Title', hintText: 'e.g., Lecture 1'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: dateController,
              decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isEmpty) return;
              Navigator.pop(ctx);
              final result = await widget.lms.createAttendanceSession(
                courseId: widget.courseId,
                sessionTitle: titleController.text,
                sessionDate: dateController.text,
              );
              if (result['success'] == true) {
                _loadAttendance();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Widget _miniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dt = DateTime.parse(date.toString());
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (e) {
      return date.toString();
    }
  }
}

// ─── MARK ATTENDANCE SCREEN ───────────────────────────────────────────────────
class _MarkAttendanceScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  final String courseId;
  final LmsService lms;
  const _MarkAttendanceScreen({required this.session, required this.courseId, required this.lms});

  @override
  State<_MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<_MarkAttendanceScreen> {
  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _students = [];
  // studentId → status
  final Map<String, String> _statusMap = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final students = await widget.lms.getCourseStudents(widget.courseId);
      final existing = List<Map<String, dynamic>>.from(widget.session['records'] ?? []);
      final statusMap = <String, String>{};
      for (final r in existing) {
        final id = r['studentId']?.toString() ?? '';
        if (id.isNotEmpty) statusMap[id] = r['status']?.toString() ?? 'absent';
      }
      if (mounted) {
        setState(() {
          _students = List<Map<String, dynamic>>.from(students);
          // Pre-fill from existing records; default absent
          for (final s in _students) {
            final id = s['_id']?.toString() ?? '';
            _statusMap[id] = statusMap[id] ?? 'absent';
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final records = _students.map((s) {
      final id = s['_id']?.toString() ?? '';
      return {'studentId': id, 'status': _statusMap[id] ?? 'absent'};
    }).toList();

    final sessionId = widget.session['_id']?.toString() ?? '';
    final result = await widget.lms.updateSessionAttendance(sessionId: sessionId, records: records);
    if (mounted) {
      setState(() => _saving = false);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance saved'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to save'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _markAll(String status) {
    setState(() {
      for (final s in _students) {
        final id = s['_id']?.toString() ?? '';
        _statusMap[id] = status;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.session['sessionTitle'] ?? 'Class Session';
    final date = _formatDate(widget.session['sessionDate']);

    final presentCount = _statusMap.values.where((v) => v == 'present').length;
    final lateCount = _statusMap.values.where((v) => v == 'late').length;
    final absentCount = _statusMap.values.where((v) => v == 'absent').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 16)),
            Text(date, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          ],
        ),
        actions: [
          if (_saving)
            const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
          else
            TextButton.icon(
              onPressed: _students.isEmpty ? null : _save,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
              style: TextButton.styleFrom(foregroundColor: AppColors.primaryColor),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary bar
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _summaryChip('Present', presentCount, Colors.green),
                      _summaryChip('Late', lateCount, Colors.orange),
                      _summaryChip('Absent', absentCount, Colors.red),
                    ],
                  ),
                ),
                // Quick mark all
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    const Text('Mark all:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    _quickMarkBtn('Present', Colors.green),
                    const SizedBox(width: 8),
                    _quickMarkBtn('Late', Colors.orange),
                    const SizedBox(width: 8),
                    _quickMarkBtn('Absent', Colors.red),
                  ]),
                ),
                const SizedBox(height: 12),
                // Student list
                Expanded(
                  child: _students.isEmpty
                      ? const Center(child: Text('No enrolled students', style: TextStyle(color: Color(0xFF94A3B8))))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _students.length,
                          itemBuilder: (ctx, i) {
                            final student = _students[i];
                            final id = student['_id']?.toString() ?? '';
                            final name = student['name']?.toString() ?? 'Student';
                            final email = student['email']?.toString() ?? '';
                            final status = _statusMap[id] ?? 'absent';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _borderColor(status).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: _borderColor(status).withValues(alpha: 0.15),
                                    radius: 22,
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                                      style: TextStyle(fontWeight: FontWeight.w800, color: _borderColor(status), fontSize: 16),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                        if (email.isNotEmpty)
                                          Text(email, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                      ],
                                    ),
                                  ),
                                  // Status toggle buttons
                                  Row(children: [
                                    _statusBtn(id, 'present', Icons.check_circle_rounded, Colors.green, status),
                                    const SizedBox(width: 6),
                                    _statusBtn(id, 'late', Icons.watch_later_rounded, Colors.orange, status),
                                    const SizedBox(width: 6),
                                    _statusBtn(id, 'absent', Icons.cancel_rounded, Colors.red, status),
                                  ]),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _summaryChip(String label, int count, Color color) {
    return Column(children: [
      Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
      Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
    ]);
  }

  Widget _quickMarkBtn(String label, Color color) {
    return GestureDetector(
      onTap: () => _markAll(label.toLowerCase()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ),
    );
  }

  Widget _statusBtn(String studentId, String status, IconData icon, Color color, String current) {
    final selected = current == status;
    return GestureDetector(
      onTap: () => setState(() => _statusMap[studentId] = status),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? color : const Color(0xFFE2E8F0)),
        ),
        child: Icon(icon, size: 20, color: selected ? color : const Color(0xFFCBD5E1)),
      ),
    );
  }

  Color _borderColor(String status) {
    switch (status) {
      case 'present': return Colors.green;
      case 'late': return Colors.orange;
      default: return Colors.red;
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final dt = DateTime.parse(date.toString());
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return date.toString(); }
  }
}

// ─── RECORDINGS TAB ──────────────────────────────────────────────────────────
class _RecordingsTab extends StatefulWidget {
  final String courseId;
  final LmsService lms;
  const _RecordingsTab({required this.courseId, required this.lms});

  @override
  State<_RecordingsTab> createState() => _RecordingsTabState();
}

class _RecordingsTabState extends State<_RecordingsTab> {
  List<Map<String, dynamic>> _recordings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sessions = await widget.lms.getCourseSessions(widget.courseId);
      final recs = <Map<String, dynamic>>[];
      for (final s in sessions) {
        final base = Map<String, dynamic>.from(s as Map);
        // Handle array of recordings per session (if backend supports it)
        final urlList = (s['recordingUrls'] as List?)?.cast<dynamic>() ?? [];
        if (urlList.isNotEmpty) {
          for (int i = 0; i < urlList.length; i++) {
            final u = urlList[i]?.toString() ?? '';
            if (u.isNotEmpty) {
              final entry = Map<String, dynamic>.from(base);
              entry['recordingUrl'] = u;
              // Prefer per-entry date if available
              if (urlList[i] is Map) {
                entry['scheduledAt'] = (urlList[i] as Map)['recordedAt'] ?? base['scheduledAt'];
              }
              recs.add(entry);
            }
          }
        } else {
          final url = s['recordingUrl']?.toString() ?? '';
          if (url.isNotEmpty) recs.add(base);
        }
      }
      // Most recent first
      recs.sort((a, b) {
        final da = DateTime.tryParse(a['scheduledAt']?.toString() ?? '') ?? DateTime(2000);
        final db = DateTime.tryParse(b['scheduledAt']?.toString() ?? '') ?? DateTime(2000);
        return db.compareTo(da);
      });
      if (mounted) setState(() { _recordings = recs; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openVideo(String url) async {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Recording', style: TextStyle(color: Colors.white)),
        ),
        body: Center(child: VideoPlayerWidget(videoUrl: url)),
      ),
    ));
  }

  String _formatDuration(dynamic seconds) {
    if (seconds == null) return '';
    final s = int.tryParse(seconds.toString()) ?? 0;
    final m = s ~/ 60;
    final rem = s % 60;
    return '${m}m ${rem}s';
  }

  String _formatDate(dynamic raw) {
    try {
      final dt = DateTime.parse(raw?.toString() ?? '').toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) { return raw?.toString() ?? ''; }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_recordings.isEmpty) {
      return const Center(
        child: _EmptyState(icon: Icons.videocam_off_outlined, text: 'No recordings yet.\nRecordings appear here after a live session ends.'),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _recordings.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final rec = _recordings[i];
          final url = rec['recordingUrl']?.toString() ?? '';
          final title = rec['title']?.toString() ?? 'Live Session';
          final date = _formatDate(rec['scheduledAt'] ?? rec['recordingEndedAt']);
          final dur = _formatDuration(rec['recordingDuration']);
          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              leading: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E40AF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF1E40AF), size: 28),
              ),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (date.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(date, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                  if (dur.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('Duration: $dur', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ],
              ),
              trailing: TextButton.icon(
                onPressed: () => _openVideo(url),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Watch'),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF1E40AF)),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── SHARED WIDGETS ───────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 56, color: Colors.grey[300]),
        const SizedBox(height: 12),
        Text(text, style: TextStyle(fontSize: 14, color: Colors.grey[400]), textAlign: TextAlign.center),
      ]),
    );
  }
}
