import 'package:flutter/material.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:intl/intl.dart';
import 'package:icare/widgets/back_button.dart';

/// Instructor view of all student attempts for a quiz — lets the instructor
/// add a rubric level, star rating, and written feedback per attempt
/// (auto-grading already sets score/percentage; this is the manual review layer).
class InstructorQuizAttemptsScreen extends StatefulWidget {
  final String quizId;
  final String quizTitle;

  const InstructorQuizAttemptsScreen({
    super.key,
    required this.quizId,
    required this.quizTitle,
  });

  @override
  State<InstructorQuizAttemptsScreen> createState() => _InstructorQuizAttemptsScreenState();
}

class _InstructorQuizAttemptsScreenState extends State<InstructorQuizAttemptsScreen> {
  final LmsService _lmsService = LmsService();
  List<dynamic> _attempts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAttempts();
  }

  Future<void> _loadAttempts() async {
    setState(() => _isLoading = true);
    final attempts = await _lmsService.getQuizAttempts(widget.quizId);
    if (mounted) {
      setState(() {
        _attempts = attempts;
        _isLoading = false;
      });
    }
  }

  void _openGradingDialog(Map<String, dynamic> attempt) {
    showDialog(
      context: context,
      builder: (context) => _QuizGradingDialog(
        attempt: attempt,
        onGraded: _loadAttempts,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => goBackOrHome(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quiz Attempts', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 18)),
            Text(widget.quizTitle, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.normal)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _attempts.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadAttempts,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _attempts.length,
                    itemBuilder: (context, index) => _buildAttemptCard(_attempts[index]),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.quiz_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No attempts yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          const Text('Students haven\'t taken this quiz yet', style: TextStyle(color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildAttemptCard(Map<String, dynamic> attempt) {
    final student = attempt['studentId'] as Map<String, dynamic>?;
    final studentName = student?['name'] ?? student?['username'] ?? 'Unknown Student';
    final marksObtained = attempt['marksObtained'] ?? attempt['score'] ?? 0;
    final maxMarks = attempt['maxMarks'] ?? attempt['totalPoints'] ?? 0;
    final passingMarks = attempt['passingMarks'] ?? 0;
    final passed = attempt['passed'] == true;
    final isGraded = attempt['gradedAt'] != null;

    String submittedLabel = '';
    if (attempt['submittedAt'] != null) {
      try {
        final date = DateTime.parse(attempt['submittedAt'].toString()).toLocal();
        submittedLabel = DateFormat('MMM dd, yyyy - hh:mm a').format(date);
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: () => _openGradingDialog(attempt),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                    child: Text(studentName[0].toUpperCase(),
                        style: TextStyle(color: AppColors.primaryColor, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(studentName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                        if (submittedLabel.isNotEmpty)
                          Text(submittedLabel, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (passed ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$marksObtained / $maxMarks',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: passed ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(children: [
                _pill('Passing: $passingMarks', const Color(0xFF64748B)),
                const SizedBox(width: 8),
                _pill(passed ? 'Passed' : 'Failed', passed ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                const SizedBox(width: 8),
                if (isGraded) _pill('Reviewed', AppColors.primaryColor),
              ]),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => _openGradingDialog(attempt),
                  icon: Icon(isGraded ? Icons.edit : Icons.rate_review_outlined, size: 16),
                  label: Text(isGraded ? 'Edit Review' : 'Add Review'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _QuizGradingDialog extends StatefulWidget {
  final Map<String, dynamic> attempt;
  final VoidCallback onGraded;

  const _QuizGradingDialog({required this.attempt, required this.onGraded});

  @override
  State<_QuizGradingDialog> createState() => _QuizGradingDialogState();
}

class _QuizGradingDialogState extends State<_QuizGradingDialog> {
  final LmsService _lmsService = LmsService();
  final _feedbackController = TextEditingController();
  bool _isSubmitting = false;
  int _starRating = 0;
  String? _rubricGrade;

  static const _rubricOptions = [
    {'value': 'excellent', 'label': 'Excellent'},
    {'value': 'satisfactory', 'label': 'Satisfactory'},
    {'value': 'average', 'label': 'Average'},
    {'value': 'needs_improvement', 'label': 'Needs Improvement'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.attempt['feedback'] != null) {
      _feedbackController.text = widget.attempt['feedback'].toString();
    }
    if (widget.attempt['stars'] != null) {
      _starRating = (widget.attempt['stars'] as num).toInt();
    }
    _rubricGrade = widget.attempt['rubricGrade']?.toString();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    setState(() => _isSubmitting = true);
    try {
      final result = await _lmsService.gradeQuizAttempt(
        widget.attempt['_id'].toString(),
        rubricGrade: _rubricGrade,
        stars: _starRating > 0 ? _starRating : null,
        feedback: _feedbackController.text,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['success'] == true ? 'Review submitted successfully!' : 'Error: ${result['message'] ?? 'Failed'}'),
          backgroundColor: result['success'] == true ? Colors.green : Colors.red,
        ));
        widget.onGraded();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.attempt['studentId'] as Map<String, dynamic>?;
    final studentName = student?['name'] ?? student?['username'] ?? 'Unknown Student';
    final marksObtained = widget.attempt['marksObtained'] ?? widget.attempt['score'] ?? 0;
    final maxMarks = widget.attempt['maxMarks'] ?? widget.attempt['totalPoints'] ?? 0;
    final passingMarks = widget.attempt['passingMarks'] ?? 0;

    return AlertDialog(
      title: Text('Review — $studentName'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  _scoreLabel('Marks Obtained', '$marksObtained'),
                  _scoreLabel('Maximum Marks', '$maxMarks'),
                  _scoreLabel('Passing Marks', '$passingMarks'),
                ]),
              ),
              const SizedBox(height: 16),

              // Rubric level
              const Text('Rubric Level', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _rubricOptions.map((opt) {
                  final selected = _rubricGrade == opt['value'];
                  return GestureDetector(
                    onTap: () => setState(() => _rubricGrade = selected ? null : opt['value']),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primaryColor.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: selected ? AppColors.primaryColor : const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        opt['label']!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected ? AppColors.primaryColor : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Star rating
              const Text('Star Rating (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
              const SizedBox(height: 8),
              Row(
                children: [
                  ...List.generate(5, (i) {
                    final filled = i < _starRating;
                    return GestureDetector(
                      onTap: () => setState(() => _starRating = _starRating == i + 1 ? 0 : i + 1),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          filled ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 32,
                          color: filled ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 8),
                  Text(
                    _starRating > 0 ? '$_starRating/5' : 'Tap to rate',
                    style: TextStyle(
                      fontSize: 13,
                      color: _starRating > 0 ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Feedback
              TextField(
                controller: _feedbackController,
                decoration: const InputDecoration(
                  labelText: 'Feedback (optional)',
                  border: OutlineInputBorder(),
                  hintText: 'Provide feedback to the student',
                ),
                maxLines: 4,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReview,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor),
          child: _isSubmitting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Submit Review'),
        ),
      ],
    );
  }

  Widget _scoreLabel(String label, String value) {
    return Column(children: [
      Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
    ]);
  }
}
