import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:icare/screens/lms_public_course_detail.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';

/// Public LMS Course Catalog - Browse courses without login
/// Inspired by Moodle & Coursera course marketplace
class LmsPublicCatalog extends StatefulWidget {
  /// Optional audience filter: 'patient' or 'doctor'/'professional'
  final String? audienceFilter;
  const LmsPublicCatalog({super.key, this.audienceFilter});

  @override
  State<LmsPublicCatalog> createState() => _LmsPublicCatalogState();
}

class _LmsPublicCatalogState extends State<LmsPublicCatalog> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _courses = [];
  List<dynamic> _filteredCourses = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  final String _selectedDifficulty = 'All';
  
  final List<String> _categories = [
    'All',
    'HealthProgram',
    'Medical Training',
    'Wellness',
    'Nutrition',
    'Mental Health',
    'Fitness',
    'Professional Development'
  ];
  

  @override
  void initState() {
    super.initState();
    _loadPublicCourses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPublicCourses() async {
    setState(() => _isLoading = true);
    try {
      // Call public endpoint (no auth required)
      final response = await _api.get('/courses/public');
      if (response.data['success'] == true) {
        setState(() {
          _courses = response.data['courses'] ?? [];
          _isLoading = false;
        });
        // Apply audience filter immediately after loading
        _applyFilters();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load courses')),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredCourses = _courses.where((course) {
        // Audience filter from navigation param
        if (widget.audienceFilter != null && widget.audienceFilter!.isNotEmpty) {
          final courseAudience = (course['targetAudience'] ?? 'Patient').toString().toLowerCase();
          final filterAudience = widget.audienceFilter!.toLowerCase();
          // 'patient' → show only patient courses
          // 'doctor' or 'professional' → show doctor/professional courses
          if (filterAudience == 'patient' && !courseAudience.contains('patient')) return false;
          if ((filterAudience == 'doctor' || filterAudience == 'professional') &&
              courseAudience.contains('patient')) {
            return false;
          }
        }

        // Category filter
        if (_selectedCategory != 'All' && course['category'] != _selectedCategory) {
          return false;
        }

        // Difficulty filter
        if (_selectedDifficulty != 'All' && course['difficulty'] != _selectedDifficulty) {
          return false;
        }

        // Search filter
        final searchQuery = _searchController.text.toLowerCase();
        if (searchQuery.isNotEmpty) {
          final title = (course['title'] ?? '').toString().toLowerCase();
          final description = (course['description'] ?? '').toString().toLowerCase();
          if (!title.contains(searchQuery) && !description.contains(searchQuery)) {
            return false;
          }
        }

        return true;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // Hero banner (like Coursera/Udemy)
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: AppColors.primaryColor,
            leading: const CustomBackButton(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.login_rounded, color: Colors.white),
                onPressed: () => Navigator.pushNamed(context, '/login'),
                tooltip: 'Login',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 72, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      widget.audienceFilter == 'patient'
                          ? 'Diet Plan & Health Courses'
                          : widget.audienceFilter == 'doctor'
                              ? 'Healthcare Professional Training'
                              : 'iCare Academy',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.audienceFilter == 'patient'
                          ? 'Courses for patients — manage your health'
                          : widget.audienceFilter == 'doctor'
                              ? 'Training programs for healthcare professionals'
                              : 'Learn health, wellness, and medical skills online',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    // Search bar inline in banner
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search for courses...',
                          hintStyle: TextStyle(
                              fontSize: 13, color: Color(0xFF94A3B8)),
                          prefixIcon: Icon(Icons.search_rounded,
                              size: 18, color: Color(0xFF94A3B8)),
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (_) => _applyFilters(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Category chips (horizontal scroll)
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: _categories.map((cat) {
                    final selected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedCategory = cat);
                          _applyFilters();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primaryColor
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primaryColor
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // Results count
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  isDesktop ? 24 : 16, 16, isDesktop ? 24 : 16, 4),
              child: Text(
                '${_filteredCourses.length} course${_filteredCourses.length != 1 ? 's' : ''} found',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B)),
              ),
            ),
          ),

          // Course grid
          _isLoading
              ? const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                )
              : _filteredCourses.isEmpty
                  ? SliverToBoxAdapter(child: _buildEmptyState())
                  : SliverPadding(
                      padding: EdgeInsets.all(isDesktop ? 24 : 16),
                      sliver: SliverGrid(
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isDesktop
                              ? 3
                              : (MediaQuery.of(context).size.width > 600
                                  ? 2
                                  : 1),
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: isDesktop ? 0.78 : 0.85,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (ctx, index) => _CourseCard(
                            course: _filteredCourses[index],
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LmsPublicCourseDetail(
                                  courseId: _filteredCourses[index]['_id'],
                                ),
                              ),
                            ),
                          ),
                          childCount: _filteredCourses.length,
                        ),
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'No courses found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your filters',
            style: TextStyle(color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

/// Course Card Widget
class _CourseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final VoidCallback onTap;

  const _CourseCard({required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final thumbnail = course['thumbnail'] ?? course['thumbnail_url'];
    final title = course['title'] ?? 'Untitled Course';
    final description = course['description'] ?? '';
    final category = course['category'] ?? 'General';
    final difficulty = course['difficulty'] ?? 'Beginner';
    final rating = (course['rating'] ?? 0.0).toDouble();
    final totalReviews = course['total_reviews'] ?? 0;
    
    // Count modules and lessons
    final modules = (course['modules'] as List?) ?? [];
    final lessonCount = modules.fold<int>(
      0,
      (sum, module) => sum + ((module['lessons'] as List?) ?? []).length,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: thumbnail != null
                  ? Image.network(
                      thumbnail,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
            ),
            
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category & Difficulty
                    Row(
                      children: [
                        _Badge(label: category, color: const Color(0xFF6366F1)),
                        const SizedBox(width: 8),
                        _Badge(label: difficulty, color: const Color(0xFF10B981)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Title
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    
                    // Description
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    
                    // Stats Row
                    Row(
                      children: [
                        if (rating > 0) ...[
                          const Icon(Icons.star, size: 14, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                          Text(
                            '$rating ($totalReviews)',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 12),
                        ],
                        const Icon(Icons.play_circle_outline, size: 14, color: Color(0xFF6366F1)),
                        const SizedBox(width: 4),
                        Text(
                          '$lessonCount lessons',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // View Details Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'View Details',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryColor.withValues(alpha: 0.7),
            AppColors.primaryColor,
          ],
        ),
      ),
      child: const Icon(Icons.school, size: 60, color: Colors.white70),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
