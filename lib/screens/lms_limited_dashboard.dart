import 'package:flutter/material.dart';
import 'package:icare/screens/courses.dart';
import 'package:icare/screens/lms_course_page.dart';
import 'package:icare/screens/lms_document_upload.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/utils/theme.dart';

/// Limited LMS Dashboard - Shows only purchased course
/// Displayed after purchase, before document verification
/// Shows verification status banner
/// After admin approval, user gets full LMS access
class LmsLimitedDashboard extends StatefulWidget {
  final String courseId;

  const LmsLimitedDashboard({super.key, required this.courseId});

  @override
  State<LmsLimitedDashboard> createState() => _LmsLimitedDashboardState();
}

class _LmsLimitedDashboardState extends State<LmsLimitedDashboard> {
  final ApiService _api = ApiService();
  
  Map<String, dynamic>? _course;
  Map<String, dynamic>? _enrollment;
  String _verificationStatus = 'not_submitted'; // not_submitted, pending, approved, rejected
  String _verificationLevel = 'limited'; // limited, full
  bool _isLoading = true;

  bool get _hasFullAccess => _verificationLevel == 'full';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load course details
      final courseResponse = await _api.get('/courses/${widget.courseId}');
      if (courseResponse.data['success'] == true) {
        _course = courseResponse.data['course'];
      }
      
      // Load enrollment
      final enrollmentResponse = await _api.get('/courses/enrollments/my');
      if (enrollmentResponse.data['success'] == true) {
        final enrollments = enrollmentResponse.data['enrollments'] as List;
        _enrollment = enrollments.firstWhere(
          (e) => e['courseId'] == widget.courseId,
          orElse: () => null,
        );
      }
      
      // Load real verification status
      try {
        final verificationResponse = await _api.get('/verification/my-status');
        if (verificationResponse.data['success'] == true) {
          final v = verificationResponse.data['verification'];
          _verificationStatus = v['status'] ?? 'not_submitted';
          _verificationLevel = v['verificationLevel'] ?? 'limited';
        }
      } catch (_) {}

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
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
        title: Text(
          _hasFullAccess ? 'My Learning' : 'Course Verification',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (_hasFullAccess)
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Color(0xFF0F172A)),
              onPressed: () {
                // TODO: Show notifications
              },
            )
          else
            TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              icon: const Icon(Icons.login_rounded, size: 18, color: AppColors.primaryColor),
              label: const Text(
                'Login',
                style: TextStyle(color: AppColors.primaryColor, fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Verification Status Banner
                  _buildVerificationBanner(),
                  const SizedBox(height: 24),

                  if (_hasFullAccess) ...[
                    // Welcome Message
                    _buildWelcomeMessage(),
                    const SizedBox(height: 24),
                  ],

                  // Course preview — always visible (title/description/curriculum),
                  // but content stays locked until _hasFullAccess is true.
                  if (_course != null) _buildCourseCard(),
                  const SizedBox(height: 24),

                  // Quick Actions
                  _buildQuickActions(),
                  const SizedBox(height: 24),

                  // What's Next
                  _buildWhatsNext(),
                ],
              ),
            ),
    );
  }

  Widget _buildVerificationBanner() {
    final Color bannerColor;
    final IconData bannerIcon;
    final String bannerTitle;
    final String bannerMessage;
    
    switch (_verificationStatus) {
      case 'approved':
        bannerColor = const Color(0xFF10B981);
        bannerIcon = Icons.check_circle;
        bannerTitle = 'Verification Approved!';
        bannerMessage = 'You now have full access to all LMS features';
        break;
      case 'rejected':
        bannerColor = const Color(0xFFEF4444);
        bannerIcon = Icons.cancel;
        bannerTitle = 'Verification Rejected';
        bannerMessage = 'Please upload valid documents to continue';
        break;
      case 'pending':
        bannerColor = const Color(0xFFF59E0B);
        bannerIcon = Icons.pending;
        bannerTitle = 'Verification Pending';
        bannerMessage = 'Your documents are under review. Course access will unlock once an admin approves your verification.';
        break;
      default:
        bannerColor = const Color(0xFFF59E0B);
        bannerIcon = Icons.upload_file;
        bannerTitle = 'Verification Required';
        bannerMessage = 'Upload your documents to request full LMS access';
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bannerColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bannerColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(bannerIcon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bannerTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: bannerColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  bannerMessage,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          if (_hasFullAccess)
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const Courses(browse: true)),
                );
              },
              child: Text(
                'Browse Courses',
                style: TextStyle(color: bannerColor, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWelcomeMessage() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryColor,
            AppColors.primaryColor.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🎉 Welcome to Your Learning Journey!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'You\'ve successfully enrolled in your first course. Start learning now and unlock your potential!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              if (_course != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LmsCoursePage(
                      course: _course!,
                      enrollmentId: _enrollment?['_id'],
                      isInstructor: false,
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Start Learning',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard() {
    final modules = (_course!['modules'] as List?) ?? [];
    final lessonCount = modules.fold<int>(
      0,
      (sum, module) => sum + ((module['lessons'] as List?) ?? []).length,
    );
    final progress = _enrollment?['progress']?['completedVideos'] ?? 0;
    final progressPercent = lessonCount > 0 ? (progress / lessonCount * 100).toInt() : 0;
    final locked = !_hasFullAccess;

    void openCourse() {
      if (locked) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LmsCoursePage(
            course: _course!,
            enrollmentId: _enrollment?['_id'],
            isInstructor: false,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: openCourse,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryColor,
                    AppColors.primaryColor.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _course!['category'] ?? 'Course',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (locked)
                        const Icon(Icons.lock, color: Colors.white70, size: 18),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _course!['title'] ?? 'Untitled',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((_course!['description'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _course!['description'].toString(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (locked) ...[
                    // Locked notice + curriculum outline only (titles, no content access)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lock_outline, color: Color(0xFFB45309), size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Content locked until admin approves your verification',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _StatChip(
                          icon: Icons.library_books,
                          label: '${modules.length} modules',
                        ),
                        const SizedBox(width: 12),
                        _StatChip(
                          icon: Icons.play_circle_outline,
                          label: '$lessonCount lessons',
                        ),
                      ],
                    ),
                    if (modules.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Curriculum',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...modules.map((m) => _LockedModuleOutline(module: m as Map)),
                    ],
                  ] else ...[
                    // Progress Bar
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progressPercent / 100,
                              minHeight: 8,
                              backgroundColor: const Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$progressPercent%',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Stats
                    Row(
                      children: [
                        _StatChip(
                          icon: Icons.library_books,
                          label: '${modules.length} modules',
                        ),
                        const SizedBox(width: 12),
                        _StatChip(
                          icon: Icons.play_circle_outline,
                          label: '$lessonCount lessons',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Continue Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: openCourse,
                        icon: const Icon(Icons.play_arrow, size: 20),
                        label: const Text('Continue Learning'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (_verificationStatus == 'not_submitted' || _verificationStatus == 'rejected') ...[
              Expanded(
                child: _ActionCard(
                  icon: Icons.upload_file,
                  label: 'Upload Documents',
                  color: const Color(0xFF6366F1),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LmsDocumentUpload(courseId: widget.courseId),
                      ),
                    );
                    _loadData();
                  },
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: _ActionCard(
                icon: Icons.help_outline,
                label: 'Get Help',
                color: const Color(0xFF10B981),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contact support at support@icare.com.co')),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWhatsNext() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What\'s Next?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          _NextStepItem(
            number: '1',
            title: 'Complete your course',
            description: 'Watch all lessons and complete assignments',
            isDone: false,
          ),
          _NextStepItem(
            number: '2',
            title: 'Get verified',
            description: _verificationStatus == 'approved'
                ? 'Your documents were approved'
                : _verificationStatus == 'pending'
                    ? 'Documents submitted — awaiting admin review'
                    : 'Upload documents for full LMS access',
            isDone: _verificationStatus == 'approved',
          ),
          _NextStepItem(
            number: '3',
            title: 'Earn your certificate',
            description: 'Complete the course to get certified',
            isDone: false,
          ),
        ],
      ),
    );
  }
}

class _LockedModuleOutline extends StatelessWidget {
  final Map module;

  const _LockedModuleOutline({required this.module});

  @override
  Widget build(BuildContext context) {
    final lessons = (module['lessons'] as List?) ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            module['title']?.toString() ?? 'Module',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          if (lessons.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...lessons.map((l) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      const Icon(Icons.lock, size: 13, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          (l as Map)['title']?.toString() ?? 'Lesson',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6366F1)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextStepItem extends StatelessWidget {
  final String number;
  final String title;
  final String description;
  final bool isDone;

  const _NextStepItem({
    required this.number,
    required this.title,
    required this.description,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDone
                  ? const Color(0xFF10B981)
                  : const Color(0xFF6366F1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : Text(
                      number,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6366F1),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
