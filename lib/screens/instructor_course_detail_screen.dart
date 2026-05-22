import 'package:flutter/material.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:go_router/go_router.dart';

/// Comprehensive Course Detail Screen - Hub for all course activities
class InstructorCourseDetailScreen extends StatefulWidget {
  final String courseId;

  const InstructorCourseDetailScreen({
    super.key,
    required this.courseId,
  });

  @override
  State<InstructorCourseDetailScreen> createState() => _InstructorCourseDetailScreenState();
}

class _InstructorCourseDetailScreenState extends State<InstructorCourseDetailScreen> with SingleTickerProviderStateMixin {
  final LmsService _lmsService = LmsService();
  late TabController _tabController;

  Map<String, dynamic>? _course;
  List<dynamic> _students = [];
  List<dynamic> _assignments = [];
  List<dynamic> _quizzes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadCourseData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCourseData() async {
    setState(() => _isLoading = true);
    try {
      final courseResponse = await _lmsService.getCourseDetails(widget.courseId);
      final students = await _lmsService.getCourseStudents(widget.courseId);
      final assignments = await _lmsService.getCourseAssignments(widget.courseId);
      final quizzes = await _lmsService.getCourseQuizzes(widget.courseId);

      if (mounted) {
        setState(() {
          _course = courseResponse['course'];
          _students = students;
          _assignments = assignments;
          _quizzes = quizzes;
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
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final courseTitle = _course?['title'] ?? 'Course';
    final isPublished = _course?['isPublished'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.primaryColor,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () {
                  context.push('/instructor/lms/edit-course/${widget.courseId}');
                },
              ),
              PopupMenuButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: Row(
                      children: [
                        Icon(isPublished ? Icons.unpublished : Icons.publish, size: 20),
                        const SizedBox(width: 12),
                        Text(isPublished ? 'Unpublish' : 'Publish'),
                      ],
                    ),
                    onTap: () => _togglePublish(),
                  ),
                  const PopupMenuItem(
                    child: Row(
                      children: [
                        Icon(Icons.settings, size: 20),
                        SizedBox(width: 12),
                        Text('Settings'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryColor, AppColors.primaryColor.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      courseTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildStatPill(Icons.people_outline, '${_students.length} students'),
                        const SizedBox(width: 12),
                        _buildStatPill(Icons.assignment_outlined, '${_assignments.length} assignments'),
                        const SizedBox(width: 12),
                        _buildStatPill(Icons.quiz_outlined, '${_quizzes.length} quizzes'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Stream'),
                Tab(text: 'Content'),
                Tab(text: 'Students'),
                Tab(text: 'Assessments'),
                Tab(text: 'Analytics'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildStreamTab(),
            _buildContentTab(),
            _buildStudentsTab(),
            _buildAssessmentsTab(),
            _buildAnalyticsTab(),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildStatPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.campaign_outlined, size: 64, color: Color(0xFF94A3B8)),
          const SizedBox(height: 16),
          const Text(
            'Course Stream',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Post announcements and updates',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              context.push('/instructor/lms/course/${widget.courseId}/stream?title=${_course?['title']}');
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open Stream'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentTab() {
    final modules = List<Map<String, dynamic>>.from(_course?['modules'] ?? []);

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${modules.length} modules',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  context.push('/instructor/lms/course/${widget.courseId}/content');
                },
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Manage Content'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: modules.isEmpty
              ? const Center(child: Text('No content yet'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: modules.length,
                  itemBuilder: (context, index) {
                    final module = modules[index];
                    final lessons = List.from(module['lessons'] ?? []);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryColor,
                          child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(module['title'] ?? 'Module ${index + 1}'),
                        subtitle: Text('${lessons.length} lessons'),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStudentsTab() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_students.length} enrolled students',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  context.push('/instructor/lms/course/${widget.courseId}/students?title=${_course?['title']}');
                },
                icon: const Icon(Icons.analytics, size: 18),
                label: const Text('View Progress'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _students.isEmpty
              ? const Center(child: Text('No students enrolled yet'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _students.length,
                  itemBuilder: (context, index) {
                    final student = _students[index];
                    final name = student['name'] ?? 'Student';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                          child: Text(
                            name[0].toUpperCase(),
                            style: TextStyle(color: AppColors.primaryColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(name),
                        subtitle: Text(student['email'] ?? ''),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAssessmentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Assignments section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Assignments',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: () {
                  context.push('/instructor/lms/create-assignment?courseId=${widget.courseId}');
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_assignments.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No assignments yet')),
              ),
            )
          else
            ..._assignments.map((assignment) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.assignment, color: Color(0xFF6366F1)),
                  title: Text(assignment['title'] ?? 'Assignment'),
                  subtitle: Text('${assignment['totalMarks'] ?? 0} marks'),
                  trailing: ElevatedButton(
                    onPressed: () {
                      context.push('/instructor/lms/assignment/${assignment['_id']}/grade?title=${assignment['title']}');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Grade'),
                  ),
                ),
              );
            }),

          const SizedBox(height: 24),

          // Quizzes section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quizzes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: () {
                  context.push('/instructor/lms/create-quiz?courseId=${widget.courseId}');
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_quizzes.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No quizzes yet')),
              ),
            )
          else
            ..._quizzes.map((quiz) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.quiz, color: Color(0xFF10B981)),
                  title: Text(quiz['title'] ?? 'Quiz'),
                  subtitle: Text('${(quiz['questions'] as List?)?.length ?? 0} questions'),
                  trailing: const Icon(Icons.chevron_right),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.analytics_outlined, size: 64, color: Color(0xFF94A3B8)),
          const SizedBox(height: 16),
          const Text(
            'Course Analytics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'View detailed insights and reports',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              context.push('/instructor/lms/course/${widget.courseId}/analytics?title=${_course?['title']}');
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('View Analytics'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildFAB() {
    final currentTab = _tabController.index;

    switch (currentTab) {
      case 0: // Stream
        return FloatingActionButton.extended(
          onPressed: () {
            context.push('/instructor/lms/course/${widget.courseId}/stream?title=${_course?['title']}');
          },
          icon: const Icon(Icons.campaign),
          label: const Text('Post Announcement'),
          backgroundColor: AppColors.primaryColor,
        );
      case 3: // Assessments
        return FloatingActionButton(
          onPressed: () {
            _showCreateAssessmentDialog();
          },
          backgroundColor: AppColors.primaryColor,
          child: const Icon(Icons.add),
        );
      default:
        return null;
    }
  }

  void _showCreateAssessmentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Assessment'),
        content: const Text('What would you like to create?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/instructor/lms/create-quiz?courseId=${widget.courseId}');
            },
            child: const Text('Quiz'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/instructor/lms/create-assignment?courseId=${widget.courseId}');
            },
            child: const Text('Assignment'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/instructor/lms/schedule-session?courseId=${widget.courseId}');
            },
            child: const Text('Live Session'),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePublish() async {
    final isPublished = _course?['isPublished'] == true;
    try {
      if (isPublished) {
        await _lmsService.unpublishCourse(widget.courseId);
      } else {
        await _lmsService.publishCourse(widget.courseId);
      }
      _loadCourseData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Course ${isPublished ? 'unpublished' : 'published'} successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }
}
