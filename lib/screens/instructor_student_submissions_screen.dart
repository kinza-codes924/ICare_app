import 'package:flutter/material.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:intl/intl.dart';

/// Shows one student's assignment submissions or quiz attempts across a
/// course — opened from the Student Progress screen's "Assignments"/
/// "Quizzes" chips.
class InstructorStudentSubmissionsScreen extends StatefulWidget {
  final String courseId;
  final String studentId;
  final String studentName;
  final bool showQuizzes; // false = assignments tab, true = quizzes tab

  const InstructorStudentSubmissionsScreen({
    super.key,
    required this.courseId,
    required this.studentId,
    required this.studentName,
    this.showQuizzes = false,
  });

  @override
  State<InstructorStudentSubmissionsScreen> createState() => _InstructorStudentSubmissionsScreenState();
}

class _InstructorStudentSubmissionsScreenState extends State<InstructorStudentSubmissionsScreen>
    with SingleTickerProviderStateMixin {
  final LmsService _lms = LmsService();
  late TabController _tabController;
  List<dynamic> _assignments = [];
  List<dynamic> _quizzes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.showQuizzes ? 1 : 0);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _lms.getStudentAssignments(widget.courseId, widget.studentId),
      _lms.getStudentQuizzes(widget.courseId, widget.studentId),
    ]);
    if (mounted) {
      setState(() {
        _assignments = results[0];
        _quizzes = results[1];
        _loading = false;
      });
    }
  }

  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try { return DateFormat('MMM d, yyyy').format(DateTime.parse(raw)); } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.studentName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryColor,
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: AppColors.primaryColor,
          tabs: const [Tab(text: 'Assignments'), Tab(text: 'Quizzes')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildAssignmentsTab(), _buildQuizzesTab()],
            ),
    );
  }

  Widget _buildAssignmentsTab() {
    if (_assignments.isEmpty) {
      return const Center(child: Text('No assignments in this course yet', style: TextStyle(color: Color(0xFF94A3B8))));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _assignments.length,
      itemBuilder: (context, i) {
        final a = _assignments[i] as Map;
        final sub = a['submission'] as Map?;
        final status = sub == null ? 'not_submitted' : (sub['status']?.toString() ?? 'submitted');
        final marks = sub?['marksObtained'];
        final totalMarks = a['totalMarks'] ?? 100;

        Color statusColor;
        String statusLabel;
        switch (status) {
          case 'graded':
            statusColor = const Color(0xFF10B981);
            statusLabel = marks != null ? 'Graded — $marks/$totalMarks' : 'Graded';
            break;
          case 'late':
            statusColor = const Color(0xFFF59E0B);
            statusLabel = 'Submitted late';
            break;
          case 'submitted':
            statusColor = const Color(0xFF6366F1);
            statusLabel = 'Submitted — pending review';
            break;
          default:
            statusColor = const Color(0xFFEF4444);
            statusLabel = 'Not submitted';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a['title']?.toString() ?? 'Assignment',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    if (a['dueDate'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('Due ${_fmtDate(a['dueDate']?.toString())}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(statusLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuizzesTab() {
    if (_quizzes.isEmpty) {
      return const Center(child: Text('No quizzes in this course yet', style: TextStyle(color: Color(0xFF94A3B8))));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _quizzes.length,
      itemBuilder: (context, i) {
        final q = _quizzes[i] as Map;
        final attempts = (q['attempts'] as List?) ?? [];
        final hasAttempts = attempts.isNotEmpty;
        final best = hasAttempts
            ? attempts.reduce((a, b) => ((a['percentage'] ?? 0) as num) >= ((b['percentage'] ?? 0) as num) ? a : b)
            : null;
        final passingScore = q['passingScore'] ?? 70;
        final passed = best != null && ((best['percentage'] ?? 0) as num) >= (passingScore as num);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q['title']?.toString() ?? 'Quiz',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    if (hasAttempts)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('${attempts.length} attempt${attempts.length == 1 ? '' : 's'}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (hasAttempts ? (passed ? const Color(0xFF10B981) : const Color(0xFFEF4444)) : const Color(0xFF94A3B8))
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  hasAttempts ? 'Best: ${((best!['percentage'] ?? 0) as num).round()}%' : 'Not attempted',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: hasAttempts ? (passed ? const Color(0xFF10B981) : const Color(0xFFEF4444)) : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
