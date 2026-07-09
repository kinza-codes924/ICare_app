import 'package:flutter/material.dart';
import 'package:icare/screens/instructor_grading_screen.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:intl/intl.dart';

/// Full assignments management view for a course — shows every assignment
/// grouped as Completed (fully graded), Pending review (has ungraded
/// submissions), or Upcoming (due date in the future, nothing submitted
/// yet). Reached from the Classroom home "Upcoming > View all" link and
/// from tapping an "Instructor posted a new assignment" feed card.
class InstructorAssignmentsListScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  const InstructorAssignmentsListScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<InstructorAssignmentsListScreen> createState() => _InstructorAssignmentsListScreenState();
}

class _InstructorAssignmentsListScreenState extends State<InstructorAssignmentsListScreen> {
  final LmsService _lms = LmsService();
  List<dynamic> _assignments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final assignments = await _lms.getCourseAssignments(widget.courseId);
    if (mounted) setState(() { _assignments = assignments; _loading = false; });
  }

  String _bucketOf(Map a) {
    final submissionCount = ((a['submissionCount'] ?? 0) as num).toInt();
    final gradedCount = ((a['gradedCount'] ?? 0) as num).toInt();
    final dueStr = a['dueDate']?.toString() ?? '';
    final isUpcoming = dueStr.isNotEmpty && (DateTime.tryParse(dueStr)?.isAfter(DateTime.now()) ?? false);

    if (submissionCount > 0 && gradedCount >= submissionCount) return 'Completed';
    if (submissionCount > gradedCount) return 'Pending review';
    if (isUpcoming) return 'Upcoming';
    return 'No submissions yet';
  }

  @override
  Widget build(BuildContext context) {
    final buckets = <String, List<dynamic>>{
      'Pending review': [],
      'Upcoming': [],
      'Completed': [],
      'No submissions yet': [],
    };
    for (final a in _assignments) {
      buckets[_bucketOf(a as Map)]!.add(a);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Assignments', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _assignments.isEmpty
              ? const Center(child: Text('No assignments in this course yet', style: TextStyle(color: Color(0xFF94A3B8))))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final section in ['Pending review', 'Upcoming', 'Completed', 'No submissions yet'])
                        if (buckets[section]!.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8, top: 8),
                            child: Text(section,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5)),
                          ),
                          ...buckets[section]!.map((a) => _buildAssignmentTile(a as Map)),
                          const SizedBox(height: 12),
                        ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildAssignmentTile(Map a) {
    final title = a['title']?.toString() ?? 'Assignment';
    final dueStr = a['dueDate']?.toString() ?? '';
    String dueLabel = 'No due date';
    if (dueStr.isNotEmpty) {
      try { dueLabel = 'Due ${DateFormat('MMM d, yyyy').format(DateTime.parse(dueStr))}'; } catch (_) {}
    }
    final submissionCount = ((a['submissionCount'] ?? 0) as num).toInt();
    final gradedCount = ((a['gradedCount'] ?? 0) as num).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.assignment_outlined, color: AppColors.primaryColor),
        ),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        subtitle: Text('$dueLabel · $submissionCount submitted, $gradedCount graded',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => InstructorGradingScreen(
            assignmentId: a['_id']?.toString() ?? '',
            assignmentTitle: title,
          ),
        )).then((_) => _load()),
      ),
    );
  }
}
