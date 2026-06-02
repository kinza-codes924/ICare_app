import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icare/screens/view_course.dart';
import 'package:icare/services/course_service.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/certificates_list.dart';

class MyLearningScreen extends ConsumerStatefulWidget {
  const MyLearningScreen({super.key});

  @override
  ConsumerState<MyLearningScreen> createState() => _MyLearningScreenState();
}

class _MyLearningScreenState extends ConsumerState<MyLearningScreen>
    with SingleTickerProviderStateMixin {
  final CourseService _courseService = CourseService();
  late TabController _tabController;

  List<dynamic> _enrolledCourses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final courses = await _courseService.myPurchases();

      if (mounted) {
        setState(() {
          _enrolledCourses = courses;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading my learning data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.read(authProvider).userRole.toLowerCase();
    final isPatient = role == 'patient';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'My Learning'.tr(),
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryColor,
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: AppColors.primaryColor,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          tabs: [
            Tab(text: isPatient ? 'Assigned Programs' : 'My Courses'),
            Tab(text: isPatient ? 'My Progress' : 'Certificates'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildCoursesTab(), _buildCertificatesTab()],
            ),
    );
  }

  Widget _buildCoursesTab() {
    final role = ref.read(authProvider).userRole.toLowerCase();
    final isPatient = role == 'patient';

    if (_enrolledCourses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPatient
                  ? Icons.health_and_safety_outlined
                  : Icons.school_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              isPatient
                  ? 'No assigned programs yet'
                  : 'No enrolled courses yet',
              style: const TextStyle(fontSize: 16, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _enrolledCourses.length,
      itemBuilder: (context, index) {
        final enrollment = _enrolledCourses[index];
        final course = enrollment['course'];

        // Handle progress - it's a Map with percent field
        int progress = 0;
        final progressData = enrollment['progress'];
        if (progressData is int) {
          progress = progressData;
        } else if (progressData is Map)
          progress = (progressData['percent'] ?? 0).toInt();

        final status = enrollment['status'] ?? 'active';
        final enrollmentId = enrollment['_id'] ?? enrollment['id'];

        return _buildCourseCard(course, progress, status, enrollmentId);
      },
    );
  }

  Widget _buildCourseCard(
    Map<String, dynamic> course,
    int progress,
    String status,
    String? enrollmentId,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) =>
                ViewCourse(courseData: course, enrollmentId: enrollmentId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Course Image
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  child: Builder(builder: (_) {
                    final img = course['image'] ?? course['thumbnail'] ?? course['coverImage'];
                    if (img is String && img.startsWith('http')) {
                      return Image.network(
                        img,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 120,
                          height: 120,
                          color: Colors.grey[200],
                          child: const Icon(Icons.book, size: 40, color: Colors.grey),
                        ),
                      );
                    }
                    return Container(
                      width: 120,
                      height: 120,
                      color: AppColors.primaryColor.withValues(alpha: 0.08),
                      child: Icon(Icons.health_and_safety_outlined, size: 40, color: AppColors.primaryColor.withValues(alpha: 0.5)),
                    );
                  }),
                ),
                // Course Info
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course['title'] ??
                              course['name'] ??
                              'Untitled Course',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: status == 'completed'
                                    ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                    : AppColors.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status == 'completed'
                                    ? 'Completed'
                                    : 'In Progress',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: status == 'completed'
                                      ? const Color(0xFF10B981)
                                      : AppColors.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Progress Bar
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Progress',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '$progress%',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress / 100,
                                backgroundColor: const Color(0xFFE2E8F0),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  status == 'completed'
                                      ? const Color(0xFF10B981)
                                      : AppColors.primaryColor,
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificatesTab() {
    final role = ref.read(authProvider).userRole.toLowerCase();
    final isPatient = role == 'patient';

    if (!isPatient) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: CertificatesList(),
      );
    }

    // Patient: show learning progress summary
    final total = _enrolledCourses.length;
    final completed = _enrolledCourses.where((e) => e['status'] == 'completed').length;
    final inProgress = total - completed;

    int totalProgress = 0;
    for (final e in _enrolledCourses) {
      final p = e['progress'];
      if (p is int) totalProgress += p;
      else if (p is Map) totalProgress += ((p['percent'] ?? 0) as num).toInt();
    }
    final avgProgress = total > 0 ? (totalProgress / total).round() : 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary cards
        Row(
          children: [
            _buildStatCard('Total Programs', '$total', Icons.library_books_outlined, const Color(0xFF0036BC)),
            const SizedBox(width: 12),
            _buildStatCard('Completed', '$completed', Icons.check_circle_outline, const Color(0xFF10B981)),
            const SizedBox(width: 12),
            _buildStatCard('In Progress', '$inProgress', Icons.timelapse_outlined, const Color(0xFFF59E0B)),
          ],
        ),
        const SizedBox(height: 16),
        // Overall progress
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Overall Progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Average completion', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  Text('$avgProgress%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0036BC))),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: avgProgress / 100,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0036BC)),
                  minHeight: 10,
                ),
              ),
            ],
          ),
        ),
        if (_enrolledCourses.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Program Progress', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          ..._enrolledCourses.map((e) {
            final course = e['course'] ?? {};
            int prog = 0;
            final p = e['progress'];
            if (p is int) prog = p;
            else if (p is Map) prog = ((p['percent'] ?? 0) as num).toInt();
            final title = course['title'] ?? course['name'] ?? 'Untitled';
            final isDone = e['status'] == 'completed';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8ECF5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis)),
                      Text('$prog%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDone ? const Color(0xFF10B981) : const Color(0xFF0036BC))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: prog / 100,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(isDone ? const Color(0xFF10B981) : const Color(0xFF0036BC)),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
