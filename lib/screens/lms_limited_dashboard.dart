import 'package:flutter/material.dart';
import 'package:icare/screens/lms_course_page.dart';
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
  final String _verificationStatus = 'pending'; // pending, approved, rejected
  bool _isLoading = true;

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
      
      // TODO: Load verification status from backend
      // For now, keep as pending
      
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
        title: const Text(
          'My Learning',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Color(0xFF0F172A)),
            onPressed: () {
              // TODO: Show notifications
            },
          ),
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
                  
                  // Welcome Message
                  _buildWelcomeMessage(),
                  const SizedBox(height: 24),
                  
                  // Course Card
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
      default:
        bannerColor = const Color(0xFFF59E0B);
        bannerIcon = Icons.pending;
        bannerTitle = 'Verification Pending';
        bannerMessage = 'Your documents are being reviewed. You can start learning now!';
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
    
    return GestureDetector(
      onTap: () {
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
      },
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
              height: 120,
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
                  Text(
                    _course!['category'] ?? 'Course',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
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
                ],
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      onPressed: () {
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
                      },
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
            Expanded(
              child: _ActionCard(
                icon: Icons.upload_file,
                label: 'Upload Documents',
                color: const Color(0xFF6366F1),
                onTap: () {
                  // TODO: Navigate to document upload
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                icon: Icons.help_outline,
                label: 'Get Help',
                color: const Color(0xFF10B981),
                onTap: () {
                  // TODO: Navigate to help
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
            description: 'Upload documents for full LMS access',
            isDone: false,
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
