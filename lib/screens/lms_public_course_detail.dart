import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:icare/screens/lms_purchase_flow.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';

/// Public Course Detail Page - View full course details without login
/// Shows curriculum, instructor info, reviews, and "Buy Now" button
class LmsPublicCourseDetail extends StatefulWidget {
  final String courseId;

  const LmsPublicCourseDetail({super.key, required this.courseId});

  @override
  State<LmsPublicCourseDetail> createState() => _LmsPublicCourseDetailState();
}

class _LmsPublicCourseDetailState extends State<LmsPublicCourseDetail>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;
  
  Map<String, dynamic>? _course;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCourseDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCourseDetails() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    
    try {
      // Try public endpoint first (no auth)
      final response = await _api.get('/courses/public');
      final courses = response.data['courses'] as List;
      final course = courses.firstWhere(
        (c) => c['_id'] == widget.courseId,
        orElse: () => null,
      );
      
      if (course != null) {
        setState(() {
          _course = course;
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: const CustomBackButton(),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_hasError || _course == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const CustomBackButton(),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Course not found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // Hero Header
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.primaryColor,
            leading: const CustomBackButton(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeroSection(),
            ),
          ),
          
          // Content
          SliverToBoxAdapter(
            child: Column(
              children: [
                if (isDesktop)
                  _buildDesktopLayout()
                else
                  _buildMobileLayout(),
              ],
            ),
          ),
        ],
      ),
      
      // Floating Buy Button
      bottomNavigationBar: _buildBuyButton(),
    );
  }

  Widget _buildHeroSection() {
    final thumbnail = _course!['thumbnail'] ?? _course!['thumbnail_url'];
    
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Image or Gradient
        if (thumbnail != null)
          Image.network(
            thumbnail,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildGradientBackground(),
          )
        else
          _buildGradientBackground(),
        
        // Overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.3),
                Colors.black.withValues(alpha: 0.7),
              ],
            ),
          ),
        ),
        
        // Content
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Category Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _course!['category'] ?? 'General',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // Title
              Text(
                _course!['title'] ?? 'Untitled Course',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              
              // Stats Row
              Row(
                children: [
                  if ((_course!['rating'] ?? 0) > 0) ...[
                    const Icon(Icons.star, color: Color(0xFFF59E0B), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${_course!['rating']} (${_course!['total_reviews'] ?? 0} reviews)',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    const SizedBox(width: 16),
                  ],
                  const Icon(Icons.people, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${_course!['enrolled_count'] ?? 0} students',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGradientBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryColor,
            AppColors.primaryColor.withValues(alpha: 0.7),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildTabBar(),
        SizedBox(
          height: 600,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(),
              _buildCurriculumTab(),
              _buildInstructorTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Tabs Content
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _buildTabBar(),
                SizedBox(
                  height: 800,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildCurriculumTab(),
                      _buildInstructorTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          
          // Right: Course Info Card
          SizedBox(
            width: 350,
            child: _buildCourseInfoCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.primaryColor,
        labelColor: AppColors.primaryColor,
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Curriculum'),
          Tab(text: 'Instructor'),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'About this course',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _course!['description'] ?? 'No description available',
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF475569),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            
            // What you'll learn
            const Text(
              'What you\'ll learn',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            _buildLearningOutcomes(),
            
            const SizedBox(height: 32),
            
            // Course Stats
            _buildCourseStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildLearningOutcomes() {
    // Extract learning outcomes from course data or use defaults
    final outcomes = [
      'Master the core concepts and fundamentals',
      'Apply knowledge through practical exercises',
      'Complete hands-on projects and assignments',
      'Earn a certificate upon completion',
    ];
    
    return Column(
      children: outcomes.map((outcome) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFF10B981),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  outcome,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCourseStats() {
    final modules = (_course!['modules'] as List?) ?? [];
    final lessonCount = modules.fold<int>(
      0,
      (sum, module) => sum + ((module['lessons'] as List?) ?? []).length,
    );
    final duration = _course!['duration'] ?? 0;
    final difficulty = _course!['difficulty'] ?? 'Beginner';
    
    return Row(
      children: [
        _StatChip(
          icon: Icons.library_books,
          label: '${modules.length} modules',
          color: const Color(0xFF6366F1),
        ),
        const SizedBox(width: 12),
        _StatChip(
          icon: Icons.play_circle_outline,
          label: '$lessonCount lessons',
          color: const Color(0xFF3B82F6),
        ),
        const SizedBox(width: 12),
        _StatChip(
          icon: Icons.schedule,
          label: '${duration}h',
          color: const Color(0xFF10B981),
        ),
      ],
    );
  }

  Widget _buildCurriculumTab() {
    final modules = (_course!['modules'] as List?) ?? [];
    
    if (modules.isEmpty) {
      return const Center(
        child: Text('No curriculum available'),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        return _ModuleCard(module: modules[index], moduleNumber: index + 1);
      },
    );
  }

  Widget _buildInstructorTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Color(0xFF6366F1),
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'Instructor Name',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Healthcare Professional',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Experienced healthcare professional with years of expertise in patient education and medical training.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF475569),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This course includes:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _InfoRow(icon: Icons.ondemand_video, text: 'On-demand video lessons'),
          _InfoRow(icon: Icons.assignment, text: 'Assignments and quizzes'),
          _InfoRow(icon: Icons.workspace_premium, text: 'Certificate of completion'),
          _InfoRow(icon: Icons.phone_android, text: 'Access on mobile and desktop'),
          _InfoRow(icon: Icons.all_inclusive, text: 'Lifetime access'),
        ],
      ),
    );
  }

  Widget _buildBuyButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LmsPurchaseFlow(course: _course!),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Buy Now',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final Map<String, dynamic> module;
  final int moduleNumber;

  const _ModuleCard({required this.module, required this.moduleNumber});

  @override
  Widget build(BuildContext context) {
    final lessons = (module['lessons'] as List?) ?? [];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          'Module $moduleNumber: ${module['title'] ?? 'Untitled'}',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${lessons.length} lessons',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        children: lessons.map<Widget>((lesson) {
          return ListTile(
            dense: true,
            leading: const Icon(Icons.play_circle_outline, size: 20),
            title: Text(
              lesson['title'] ?? 'Untitled Lesson',
              style: const TextStyle(fontSize: 14),
            ),
            trailing: Text(
              '${lesson['duration'] ?? 0} min',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6366F1)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
            ),
          ),
        ],
      ),
    );
  }
}
