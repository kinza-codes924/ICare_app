import 'package:flutter/material.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';

class AssessmentsScreen extends StatefulWidget {
  const AssessmentsScreen({super.key});

  @override
  State<AssessmentsScreen> createState() => _AssessmentsScreenState();
}

class _AssessmentsScreenState extends State<AssessmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final LmsService _lms = LmsService();
  List<dynamic> _assignments = [];
  List<dynamic> _quizzes = [];
  bool _loadingAssignments = true;
  bool _loadingQuizzes = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    _loadAssignments();
    _loadQuizzes();
  }

  Future<void> _loadAssignments() async {
    setState(() => _loadingAssignments = true);
    try {
      final data = await _lms.getMyAssessmentAssignments();
      if (mounted) setState(() { _assignments = data; _loadingAssignments = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingAssignments = false);
    }
  }

  Future<void> _loadQuizzes() async {
    setState(() => _loadingQuizzes = true);
    try {
      final data = await _lms.getMyAssessmentQuizzes();
      if (mounted) setState(() { _quizzes = data; _loadingQuizzes = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingQuizzes = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        leading: const CustomBackButton(color: Colors.white),
        title: const Text('Assessments',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Assignments'),
            Tab(text: 'Quizzes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAssignmentsTab(),
          _buildQuizzesTab(),
        ],
      ),
    );
  }

  Widget _buildAssignmentsTab() {
    if (_loadingAssignments) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_assignments.isEmpty) {
      return _buildEmpty('No assignments found', Icons.assignment_outlined);
    }
    return RefreshIndicator(
      onRefresh: _loadAssignments,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _assignments.length,
        itemBuilder: (_, i) => _buildAssignmentCard(_assignments[i]),
      ),
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> a) {
    final submission = a['submission'];
    final status = submission == null
        ? 'Pending'
        : submission['status'] == 'graded'
            ? 'Graded'
            : 'Submitted';
    final obtained = submission?['marksObtained'];
    final total = a['totalMarks'] ?? 100;
    final passing = a['passingMarks'] ?? 50;
    final feedback = submission?['feedback']?.toString() ?? '';
    final stars = submission?['stars'];
    final starCount = stars != null ? (stars as num).toInt() : 0;
    final dueDate = a['dueDate'];
    final isOverdue = dueDate != null &&
        DateTime.tryParse(dueDate.toString())?.isBefore(DateTime.now()) == true &&
        submission == null;

    Color statusColor;
    IconData statusIcon;
    if (status == 'Graded') {
      final passed = obtained != null && (obtained as num) >= (passing as num);
      statusColor = passed ? const Color(0xFF059669) : const Color(0xFFDC2626);
      statusIcon = passed ? Icons.check_circle_rounded : Icons.cancel_rounded;
    } else if (status == 'Submitted') {
      statusColor = const Color(0xFF0369A1);
      statusIcon = Icons.hourglass_top_rounded;
    } else {
      statusColor = isOverdue ? const Color(0xFFDC2626) : const Color(0xFF6B7280);
      statusIcon = isOverdue ? Icons.warning_rounded : Icons.pending_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(statusIcon, size: 22, color: statusColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a['title']?.toString() ?? 'Assignment',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text(a['courseName']?.toString() ?? '',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                if (dueDate != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.schedule_rounded, size: 12,
                        color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(_fmtDate(dueDate),
                        style: TextStyle(fontSize: 11,
                            color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF94A3B8))),
                  ]),
                ],
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(status,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
              ),
              if (obtained != null) ...[
                const SizedBox(height: 4),
                Text('$obtained / $total',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              ],
            ]),
          ]),
        ),
        if (starCount > 0 || feedback.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 10),
              if (starCount > 0) ...[
                Row(children: List.generate(5, (i) => Icon(
                  i < starCount ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 18,
                  color: i < starCount ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                ))),
                const SizedBox(height: 6),
              ],
              if (feedback.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.comment_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(feedback,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
                  ]),
                ),
            ]),
          ),
      ]),
    );
  }

  Widget _buildQuizzesTab() {
    if (_loadingQuizzes) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_quizzes.isEmpty) {
      return _buildEmpty('No quizzes found', Icons.quiz_outlined);
    }
    return RefreshIndicator(
      onRefresh: _loadQuizzes,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _quizzes.length,
        itemBuilder: (_, i) => _buildQuizCard(_quizzes[i]),
      ),
    );
  }

  Widget _buildQuizCard(Map<String, dynamic> q) {
    final attempted = q['attempted'] == true;
    final passed = q['passed'] == true;
    final score = q['score'];
    final total = q['totalMarks'];
    final attemptCount = (q['attemptCount'] as num?)?.toInt() ?? 0;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    if (!attempted) {
      statusColor = const Color(0xFF6B7280);
      statusLabel = 'Not Attempted';
      statusIcon = Icons.radio_button_unchecked_rounded;
    } else if (passed) {
      statusColor = const Color(0xFF059669);
      statusLabel = 'Passed';
      statusIcon = Icons.check_circle_rounded;
    } else {
      statusColor = const Color(0xFFDC2626);
      statusLabel = 'Failed';
      statusIcon = Icons.cancel_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(statusIcon, size: 22, color: statusColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(q['quizTitle']?.toString() ?? 'Quiz',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            const SizedBox(height: 2),
            Text(q['courseName']?.toString() ?? '',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            if (attempted && attemptCount > 0) ...[
              const SizedBox(height: 2),
              Text('$attemptCount attempt${attemptCount > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ],
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(statusLabel,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
          ),
          if (score != null) ...[
            const SizedBox(height: 4),
            Text('${(score as num).toStringAsFixed(0)} / $total',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          ],
        ]),
      ]),
    );
  }

  Widget _buildEmpty(String msg, IconData icon) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 64, color: const Color(0xFFCBD5E1)),
        const SizedBox(height: 16),
        Text(msg, style: const TextStyle(fontSize: 16, color: Color(0xFF94A3B8))),
      ]),
    );
  }

  String _fmtDate(dynamic d) {
    try { return 'Due: ${DateFormat('MMM d, yyyy').format(DateTime.parse(d.toString()))}'; }
    catch (_) { return ''; }
  }
}
