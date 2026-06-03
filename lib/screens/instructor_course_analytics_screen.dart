import 'package:flutter/material.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/theme.dart';

/// Course Analytics Dashboard - Google Classroom/Moodle style
class InstructorCourseAnalyticsScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  const InstructorCourseAnalyticsScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<InstructorCourseAnalyticsScreen> createState() => _InstructorCourseAnalyticsScreenState();
}

class _InstructorCourseAnalyticsScreenState extends State<InstructorCourseAnalyticsScreen> {
  final LmsService _lmsService = LmsService();

  bool _isLoading = true;
  Map<String, dynamic> _analytics = {};

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    try {
      // Load various analytics data
      final students = await _lmsService.getCourseStudents(widget.courseId);
      final assignments = await _lmsService.getCourseAssignments(widget.courseId);
      final quizzes = await _lmsService.getCourseQuizzes(widget.courseId);

      // Calculate statistics
      int totalStudents = students.length;
      int activeStudents = students.where((s) {
        final progress = s['progress'];
        if (progress is int) return progress > 0;
        if (progress is Map) return (progress['percent'] ?? 0) > 0;
        return false;
      }).length;

      int totalAssignments = assignments.length;
      int totalQuizzes = quizzes.length;

      // Calculate average progress
      double avgProgress = 0;
      if (students.isNotEmpty) {
        int total = 0;
        for (final student in students) {
          final progress = student['progress'];
          if (progress is int) {
            total += progress;
          } else if (progress is Map) {
            total += (progress['percent'] ?? 0) as int;
          }
        }
        avgProgress = total / students.length;
      }

      // Calculate completion rate
      int completedStudents = students.where((s) {
        final progress = s['progress'];
        if (progress is int) return progress >= 100;
        if (progress is Map) return (progress['percent'] ?? 0) >= 100;
        return false;
      }).length;
      double completionRate = totalStudents > 0 ? (completedStudents / totalStudents * 100) : 0;

      if (mounted) {
        setState(() {
          _analytics = {
            'totalStudents': totalStudents,
            'activeStudents': activeStudents,
            'avgProgress': avgProgress,
            'completionRate': completionRate,
            'totalAssignments': totalAssignments,
            'totalQuizzes': totalQuizzes,
            'students': students,
          };
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
              'Course Analytics',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            Text(
              widget.courseTitle,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overview Stats
                    const Text(
                      'Overview',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStatsGrid(),

                    const SizedBox(height: 32),

                    // Progress Distribution
                    const Text(
                      'Student Progress Distribution',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildProgressDistribution(),

                    const SizedBox(height: 32),

                    // Engagement Metrics
                    const Text(
                      'Engagement Metrics',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildEngagementMetrics(),

                    const SizedBox(height: 32),

                    // Top Performers
                    const Text(
                      'Top Performers',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTopPerformers(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 0.9,
      children: [
        _buildStatCard(
          'Total Students',
          '${_analytics['totalStudents'] ?? 0}',
          Icons.people_rounded,
          const Color(0xFF6366F1),
          '${_analytics['activeStudents'] ?? 0} active',
        ),
        _buildStatCard(
          'Avg Progress',
          '${(_analytics['avgProgress'] ?? 0).toStringAsFixed(1)}%',
          Icons.trending_up_rounded,
          const Color(0xFF10B981),
          'Course completion',
        ),
        _buildStatCard(
          'Completion Rate',
          '${(_analytics['completionRate'] ?? 0).toStringAsFixed(1)}%',
          Icons.check_circle_rounded,
          const Color(0xFF8B5CF6),
          'Students completed',
        ),
        _buildStatCard(
          'Assessments',
          '${(_analytics['totalAssignments'] ?? 0) + (_analytics['totalQuizzes'] ?? 0)}',
          Icons.assignment_rounded,
          const Color(0xFFF59E0B),
          '${_analytics['totalAssignments'] ?? 0} assignments, ${_analytics['totalQuizzes'] ?? 0} quizzes',
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressDistribution() {
    final students = List<Map<String, dynamic>>.from(_analytics['students'] ?? []);

    // Categorize students by progress
    int range0_25 = 0;
    int range26_50 = 0;
    int range51_75 = 0;
    int range76_100 = 0;

    for (final student in students) {
      final progress = student['progress'];
      int progressValue = 0;
      if (progress is int) {
        progressValue = progress;
      } else if (progress is Map) {
        progressValue = (progress['percent'] ?? 0) as int;
      }

      if (progressValue <= 25) {
        range0_25++;
      } else if (progressValue <= 50) {
        range26_50++;
      } else if (progressValue <= 75) {
        range51_75++;
      } else {
        range76_100++;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildProgressBar('0-25%', range0_25, students.length, const Color(0xFFEF4444)),
          const SizedBox(height: 12),
          _buildProgressBar('26-50%', range26_50, students.length, const Color(0xFFF59E0B)),
          const SizedBox(height: 12),
          _buildProgressBar('51-75%', range51_75, students.length, const Color(0xFF3B82F6)),
          const SizedBox(height: 12),
          _buildProgressBar('76-100%', range76_100, students.length, const Color(0xFF10B981)),
        ],
      ),
    );
  }

  Widget _buildProgressBar(String label, int count, int total, Color color) {
    final percentage = total > 0 ? (count / total) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              '$count students (${(percentage * 100).toStringAsFixed(0)}%)',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildEngagementMetrics() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildEngagementRow(
            Icons.assignment_turned_in_rounded,
            'Assignment Submissions',
            'Coming soon',
            const Color(0xFF6366F1),
          ),
          const Divider(height: 24),
          _buildEngagementRow(
            Icons.quiz_rounded,
            'Quiz Attempts',
            'Coming soon',
            const Color(0xFF10B981),
          ),
          const Divider(height: 24),
          _buildEngagementRow(
            Icons.video_call_rounded,
            'Live Session Attendance',
            'Coming soon',
            const Color(0xFFEC4899),
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementRow(IconData icon, String title, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopPerformers() {
    final students = List<Map<String, dynamic>>.from(_analytics['students'] ?? []);

    // Sort by progress
    students.sort((a, b) {
      int progressA = 0;
      int progressB = 0;

      if (a['progress'] is int) {
        progressA = a['progress'];
      } else if (a['progress'] is Map) progressA = (a['progress']['percent'] ?? 0) as int;

      if (b['progress'] is int) {
        progressB = b['progress'];
      } else if (b['progress'] is Map) progressB = (b['progress']['percent'] ?? 0) as int;

      return progressB.compareTo(progressA);
    });

    final topStudents = students.take(5).toList();

    if (topStudents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'No student data available',
            style: TextStyle(color: Color(0xFF94A3B8)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: topStudents.length,
        separatorBuilder: (_, _) => const Divider(height: 24),
        itemBuilder: (context, index) {
          final student = topStudents[index];
          final name = student['name'] ?? 'Unknown Student';
          final progress = student['progress'];
          int progressValue = 0;
          if (progress is int) {
            progressValue = progress;
          } else if (progress is Map) {
            progressValue = (progress['percent'] ?? 0) as int;
          }

          IconData medalIcon;
          Color medalColor;
          if (index == 0) {
            medalIcon = Icons.emoji_events;
            medalColor = const Color(0xFFFBBF24);
          } else if (index == 1) {
            medalIcon = Icons.emoji_events;
            medalColor = const Color(0xFF94A3B8);
          } else if (index == 2) {
            medalIcon = Icons.emoji_events;
            medalColor = const Color(0xFFCD7F32);
          } else {
            medalIcon = Icons.star;
            medalColor = const Color(0xFF6366F1);
          }

          return Row(
            children: [
              Icon(medalIcon, color: medalColor, size: 28),
              const SizedBox(width: 12),
              CircleAvatar(
                backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                child: Text(
                  name[0].toUpperCase(),
                  style: TextStyle(
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$progressValue%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

