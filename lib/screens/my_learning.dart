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
          isPatient ? 'My Health Journey' : 'My Learning',
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
                  child: course['image'] is String
                      ? Image.asset(
                          course['image'] as String,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 120,
                          height: 120,
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.book,
                            size: 40,
                            color: Colors.grey,
                          ),
                        ),
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
    return const Padding(
      padding: EdgeInsets.all(16),
      child: CertificatesList(),
    );
  }
}
