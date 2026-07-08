import 'package:flutter/material.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';

/// Course feedback — student → instructor ratings + written reviews,
/// aggregated across all of the instructor's courses.
class InstructorFeedbackScreen extends StatefulWidget {
  const InstructorFeedbackScreen({super.key});

  @override
  State<InstructorFeedbackScreen> createState() => _InstructorFeedbackScreenState();
}

class _InstructorFeedbackScreenState extends State<InstructorFeedbackScreen> {
  final LmsService _lms = LmsService();
  List<dynamic> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final reviews = await _lms.getMyCourseReviews();
      if (mounted) setState(() { _reviews = reviews; _isLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load feedback: $e')),
        );
      }
    }
  }

  double get _averageRating {
    if (_reviews.isEmpty) return 0;
    final sum = _reviews.fold<num>(0, (s, r) => s + (r['rating'] as num? ?? 0));
    return sum / _reviews.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const CustomBackButton(),
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Student Feedback',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildSummaryCard(),
                  const SizedBox(height: 20),
                  if (_reviews.isEmpty)
                    _buildEmptyState()
                  else
                    ..._reviews.map((r) => _ReviewCard(review: r)),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryColor, AppColors.primaryColor.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text(
            _reviews.isEmpty ? '—' : _averageRating.toStringAsFixed(1),
            style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(5, (i) {
                  final filled = i < _averageRating.round();
                  return Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                '${_reviews.length} review${_reviews.length == 1 ? '' : 's'} across your courses',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.rate_review_outlined, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No feedback yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Reviews from your students will appear here',
              style: TextStyle(color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final rating = (review['rating'] as num? ?? 0).toInt();
    final comment = (review['comment'] ?? '').toString();
    final studentName = review['studentName']?.toString() ?? 'Student';
    final courseTitle = review['courseTitle']?.toString() ?? 'Course';
    String dateLabel = '';
    try {
      final d = DateTime.parse(review['createdAt'].toString()).toLocal();
      dateLabel = DateFormat('MMM dd, yyyy').format(d);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                child: Text(
                  studentName.isNotEmpty ? studentName[0].toUpperCase() : '?',
                  style: TextStyle(color: AppColors.primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(studentName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    Text(courseTitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              if (dateLabel.isNotEmpty)
                Text(dateLabel, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(5, (i) => Icon(
                  i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 16,
                  color: const Color(0xFFF59E0B),
                )),
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(comment, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4)),
          ],
        ],
      ),
    );
  }
}
