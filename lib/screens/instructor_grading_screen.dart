import 'package:flutter/material.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:intl/intl.dart';

/// Assignment Grading Screen - Google Classroom style
class InstructorGradingScreen extends StatefulWidget {
  final String assignmentId;
  final String assignmentTitle;

  const InstructorGradingScreen({
    super.key,
    required this.assignmentId,
    required this.assignmentTitle,
  });

  @override
  State<InstructorGradingScreen> createState() => _InstructorGradingScreenState();
}

class _InstructorGradingScreenState extends State<InstructorGradingScreen> {
  final LmsService _lmsService = LmsService();

  List<dynamic> _submissions = [];
  bool _isLoading = true;
  String _filterStatus = 'all'; // all, submitted, graded, late

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    setState(() => _isLoading = true);
    try {
      final submissions = await _lmsService.getSubmissions(widget.assignmentId);
      if (mounted) {
        setState(() {
          _submissions = submissions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  List<dynamic> get _filteredSubmissions {
    if (_filterStatus == 'all') return _submissions;
    return _submissions.where((s) => s['status'] == _filterStatus).toList();
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Grade Submissions',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            Text(
              widget.assignmentTitle,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildFilterChip('All', 'all', _submissions.length),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Submitted',
                  'submitted',
                  _submissions.where((s) => s['status'] == 'submitted').length,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Graded',
                  'graded',
                  _submissions.where((s) => s['status'] == 'graded').length,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Late',
                  'late',
                  _submissions.where((s) => s['status'] == 'late').length,
                ),
              ],
            ),
          ),

          // Submissions list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredSubmissions.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadSubmissions,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredSubmissions.length,
                          itemBuilder: (context, index) {
                            return _buildSubmissionCard(_filteredSubmissions[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterStatus = value);
      },
      backgroundColor: Colors.white,
      selectedColor: AppColors.primaryColor.withValues(alpha: 0.1),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primaryColor : const Color(0xFF64748B),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primaryColor : const Color(0xFFE2E8F0),
      ),
    );
  }

  Widget _buildSubmissionCard(Map<String, dynamic> submission) {
    final student = submission['studentId'] as Map<String, dynamic>?;
    final studentName = student?['name'] ?? student?['username'] ?? 'Unknown Student';
    final status = submission['status'] ?? 'submitted';
    final submittedAt = submission['submittedAt'];
    final marksObtained = submission['marksObtained'];
    final isGraded = status == 'graded';

    String submittedLabel = '';
    if (submittedAt != null) {
      try {
        final date = DateTime.parse(submittedAt.toString());
        submittedLabel = DateFormat('MMM dd, yyyy - hh:mm a').format(date);
      } catch (_) {}
    }

    Color statusColor;
    switch (status) {
      case 'graded':
        statusColor = const Color(0xFF10B981);
        break;
      case 'late':
        statusColor = const Color(0xFFEF4444);
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _openGradingDialog(submission),
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
                    child: Text(
                      studentName[0].toUpperCase(),
                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          studentName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (submittedLabel.isNotEmpty)
                          Text(
                            submittedLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isGraded)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$marksObtained pts',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status == 'late' ? 'Late' : 'Pending',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                ],
              ),
              if (submission['content'] != null && submission['content'].toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    submission['content'].toString(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (submission['fileUrl'] != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.attach_file, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        submission['fileName'] ?? 'Attached file',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => _openGradingDialog(submission),
                  icon: Icon(isGraded ? Icons.edit : Icons.grade, size: 16),
                  label: Text(isGraded ? 'Edit Grade' : 'Grade'),
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

  void _openGradingDialog(Map<String, dynamic> submission) {
    showDialog(
      context: context,
      builder: (context) => _GradingDialog(
        submission: submission,
        onGraded: () {
          _loadSubmissions();
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_turned_in_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'No submissions yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Students haven\'t submitted their work yet',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

// Grading Dialog
class _GradingDialog extends StatefulWidget {
  final Map<String, dynamic> submission;
  final VoidCallback onGraded;

  const _GradingDialog({
    required this.submission,
    required this.onGraded,
  });

  @override
  State<_GradingDialog> createState() => _GradingDialogState();
}

class _GradingDialogState extends State<_GradingDialog> {
  final LmsService _lmsService = LmsService();
  final _marksController = TextEditingController();
  final _feedbackController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.submission['marksObtained'] != null) {
      _marksController.text = widget.submission['marksObtained'].toString();
    }
    if (widget.submission['feedback'] != null) {
      _feedbackController.text = widget.submission['feedback'].toString();
    }
  }

  @override
  void dispose() {
    _marksController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitGrade() async {
    final marks = num.tryParse(_marksController.text);
    if (marks == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid marks')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _lmsService.gradeSubmission(
        widget.submission['_id'].toString(),
        marks,
        feedback: _feedbackController.text,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grade submitted successfully!')),
        );
        widget.onGraded();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.submission['studentId'] as Map<String, dynamic>?;
    final studentName = student?['name'] ?? student?['username'] ?? 'Unknown Student';

    return AlertDialog(
      title: Text('Grade - $studentName'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Submission content
              if (widget.submission['content'] != null &&
                  widget.submission['content'].toString().isNotEmpty) ...[
                const Text(
                  'Submission:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    widget.submission['content'].toString(),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // File attachment
              if (widget.submission['fileUrl'] != null) ...[
                const Text(
                  'Attached File:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_file, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.submission['fileName'] ?? 'Attached file',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // TODO: Open file
                        },
                        child: const Text('View'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Marks input
              TextField(
                controller: _marksController,
                decoration: const InputDecoration(
                  labelText: 'Marks Obtained *',
                  border: OutlineInputBorder(),
                  hintText: 'Enter marks',
                ),
                keyboardType: TextInputType.number,
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitGrade,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Submit Grade'),
        ),
      ],
    );
  }
}

