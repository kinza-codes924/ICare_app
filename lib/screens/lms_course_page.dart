import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/screens/lesson_detail_page.dart';
import 'package:icare/screens/certificate_page.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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
            _GradesTab(courseId: _courseId, lms: _lms, isInstructor: widget.isInstructor),
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
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final a = await widget.lms.getCourseAssignments(widget.courseId);
    if (mounted) setState(() { _assignments = a; _loading = false; });
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
            _CourseLessons(course: widget.course, enrollmentId: widget.enrollmentId, lms: widget.lms),
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
  const _CourseLessons({required this.course, this.enrollmentId, required this.lms});

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
    return Column(children: modules.asMap().entries.map((me) {
      final m = me.value;
      final moduleId = m['_id']?.toString() ?? '';
      final lessons = (m['lessons'] as List?) ?? [];
      final quizzes = (m['quizzes'] as List?) ?? [];
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]),
        child: ExpansionTile(
          leading: CircleAvatar(radius: 16, backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
            child: Text('${me.key + 1}', style: TextStyle(color: AppColors.primaryColor, fontWeight: FontWeight.w700, fontSize: 12))),
          title: Text(m['title'] ?? 'Module ${me.key + 1}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          subtitle: Text('${lessons.length} lessons · ${quizzes.length} quizzes', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          children: [
            ...lessons.map((l) => ListTile(
              leading: const Icon(Icons.play_circle_outline_rounded, color: AppColors.primaryColor, size: 20),
              title: Text(l['title'] ?? 'Lesson', style: const TextStyle(fontSize: 13)),
              dense: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LessonDetailPage(
                    lesson: l,
                    courseId: course['_id']?.toString() ?? '',
                    moduleId: moduleId,
                  ),
                ),
              ),
            )),
            ...quizzes.map((q) => ListTile(
              leading: const Icon(Icons.quiz_outlined, color: Colors.orange, size: 20),
              title: Text(q['title'] ?? 'Quiz', style: const TextStyle(fontSize: 13)),
              dense: true,
            )),
            // Mark as Complete button
            if (moduleId.isNotEmpty)
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
  const _GradesTab({required this.courseId, required this.lms, required this.isInstructor});

  @override
  State<_GradesTab> createState() => _GradesTabState();
}

class _GradesTabState extends State<_GradesTab> {
  List<dynamic> _grades = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final g = await widget.lms.getCourseGrades(widget.courseId);
    if (mounted) setState(() { _grades = g; _loading = false; });
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

          // Certificate Button (show if average >= 70%)
          if (!widget.isInstructor && _average >= 70)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: ElevatedButton.icon(
                onPressed: () async {
                  final user = await SharedPref().getUserData();
                  final userId = user?.id;
                  if (userId != null && context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CertificatePage(
                          courseId: widget.courseId,
                          studentId: userId,
                          courseName: 'Course Name', // TODO: Pass actual course name
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.workspace_premium_rounded, size: 20),
                label: const Text('View Certificate'),
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
                  Text('Total: ${a['totalMarks']} marks', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  if (s == null) const Text('Not submitted', style: TextStyle(fontSize: 12, color: Colors.red)),
                  if (s != null && !graded) const Text('Submitted — Awaiting grade', style: TextStyle(fontSize: 12, color: Colors.orange)),
                  if (graded && s['feedback'] != null && s['feedback'].toString().isNotEmpty)
                    Text('Feedback: ${s['feedback']}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (widget.isInstructor) {
      final s = await widget.lms.getEnrolledStudents(widget.courseId);
      if (mounted) setState(() { _students = s; _loading = false; });
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(title: 'Instructor', icon: Icons.school_rounded),
        const SizedBox(height: 8),
        _PersonTile(name: widget.course['instructorName'] ?? 'Instructor', role: 'Course Instructor', isInstructor: true),
        const SizedBox(height: 20),
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
  const _PersonTile({required this.name, required this.role, required this.isInstructor, this.progress});

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
          child: Text(name[0].toUpperCase(),
            style: TextStyle(color: isInstructor ? Colors.white : const Color(0xFF64748B), fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          Text(role, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        ])),
        if (progress != null && progress['completed'] == true)
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
                        color: isPresent ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isPresent ? 'Present' : 'Absent',
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
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session['sessionTitle'] ?? 'Class Session',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(session['sessionDate']),
                                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$presentCount/${records.length} Present',
                            style: TextStyle(color: AppColors.primaryColor, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
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
      final recs = sessions
          .where((s) {
            final url = s['recordingUrl']?.toString() ?? '';
            return url.isNotEmpty;
          })
          .map<Map<String, dynamic>>((s) => Map<String, dynamic>.from(s))
          .toList();
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
    if (kIsWeb) {
      // Open in new browser tab on web
      final uri = Uri.tryParse(url);
      if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      final uri = Uri.tryParse(url);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
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
