import 'package:flutter/material.dart';
import 'package:icare/screens/classroom_course_view.dart';
import 'package:icare/screens/instructor_lms_create_course.dart';
import 'package:icare/screens/instructor_student_progress_screen.dart';
import 'package:icare/screens/instructor_course_analytics_screen.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/theme.dart';

/// Instructor Courses Management - Moodle style course list
class InstructorLmsCoursesScreen extends StatefulWidget {
  const InstructorLmsCoursesScreen({super.key});

  @override
  State<InstructorLmsCoursesScreen> createState() => _InstructorLmsCoursesScreenState();
}

class _InstructorLmsCoursesScreenState extends State<InstructorLmsCoursesScreen> {
  final LmsService _lmsService = LmsService();
  final TextEditingController _searchController = TextEditingController();
  
  List<dynamic> _courses = [];
  List<dynamic> _filteredCourses = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, published, draft

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    setState(() => _isLoading = true);
    try {
      final response = await _lmsService.getInstructorCourses();
      setState(() {
        _courses = response['courses'] ?? [];
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredCourses = _courses.where((course) {
        // Status filter
        if (_selectedFilter == 'published' && course['isPublished'] != true) {
          return false;
        }
        if (_selectedFilter == 'draft' && course['isPublished'] == true) {
          return false;
        }
        
        // Search filter
        final searchQuery = _searchController.text.toLowerCase();
        if (searchQuery.isNotEmpty) {
          final title = (course['title'] ?? '').toString().toLowerCase();
          if (!title.contains(searchQuery)) {
            return false;
          }
        }
        
        return true;
      }).toList();
    });
  }

  Future<void> _deleteCourse(String courseId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Course'),
        content: const Text('Are you sure you want to delete this course? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _lmsService.deleteCourse(courseId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Course deleted successfully')),
          );
          _loadCourses();
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

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Courses',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InstructorLmsCreateCourseScreen()),
            ).then((_) => _loadCourses()),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filters & Search
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(isDesktop ? 24 : 16),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  onChanged: (_) => _applyFilters(),
                  decoration: InputDecoration(
                    hintText: 'Search courses...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Filter chips
                Row(
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('All Courses', 'all'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Published', 'published'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Drafts', 'draft'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_filteredCourses.length} courses',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Courses list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCourses.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadCourses,
                        child: ListView.builder(
                          padding: EdgeInsets.all(isDesktop ? 24 : 16),
                          itemCount: _filteredCourses.length,
                          itemBuilder: (context, index) {
                            return _buildCourseCard(_filteredCourses[index], isDesktop);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
          _applyFilters();
        });
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'No courses yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first course to get started',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const InstructorLmsCreateCourseScreen()))
              .then((_) => _loadCourses()),
            icon: const Icon(Icons.add),
            label: const Text('Create Course'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course, bool isDesktop) {
    final isPublished = course['isPublished'] == true;
    final enrolledCount = course['enrolledCount'] ?? 0;
    final modulesCount = (course['modules'] as List?)?.length ?? 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClassroomCourseView(
              course: Map<String, dynamic>.from(course),
              isInstructor: true,
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: isDesktop
              ? Row(
                  children: [
                    _buildCourseThumbnail(course),
                    const SizedBox(width: 20),
                    Expanded(child: _buildCourseInfo(course, enrolledCount, modulesCount)),
                    _buildCourseActions(course, isPublished),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCourseThumbnail(course),
                    const SizedBox(height: 16),
                    _buildCourseInfo(course, enrolledCount, modulesCount),
                    const SizedBox(height: 16),
                    _buildCourseActions(course, isPublished),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCourseThumbnail(Map<String, dynamic> course) {
    return Container(
      width: 120,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppColors.primaryColor.withValues(alpha: 0.1),
        image: course['thumbnail'] != null
            ? DecorationImage(
                image: NetworkImage(course['thumbnail']),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: course['thumbnail'] == null
          ? const Icon(
              Icons.menu_book_rounded,
              size: 40,
              color: AppColors.primaryColor,
            )
          : null,
    );
  }

  Widget _buildCourseInfo(Map<String, dynamic> course, int enrolledCount, int modulesCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                course['title'] ?? 'Untitled Course',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: course['isPublished'] == true
                    ? const Color(0xFF10B981).withValues(alpha: 0.1)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                course['isPublished'] == true ? 'Published' : 'Draft',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: course['isPublished'] == true
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          course['description'] ?? 'No description',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildInfoChip(Icons.people_outline, '$enrolledCount students'),
            const SizedBox(width: 16),
            _buildInfoChip(Icons.folder_outlined, '$modulesCount modules'),
            const SizedBox(width: 16),
            _buildInfoChip(Icons.access_time, '${course['duration'] ?? 0} weeks'),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildCourseActions(Map<String, dynamic> course, bool isPublished) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.open_in_new_rounded),
          tooltip: 'Open Class',
          onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => ClassroomCourseView(
              course: Map<String, dynamic>.from(course),
              isInstructor: true,
            ),
          )).then((_) => _loadCourses()),
        ),
        IconButton(
          icon: const Icon(Icons.people_outline),
          tooltip: 'Students',
          onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => InstructorStudentProgressScreen(
              courseId: course['_id']?.toString() ?? '',
              courseTitle: course['title']?.toString() ?? 'Course',
            ),
          )),
        ),
        IconButton(
          icon: const Icon(Icons.analytics_outlined),
          tooltip: 'Analytics',
          onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => InstructorCourseAnalyticsScreen(
              courseId: course['_id']?.toString() ?? '',
              courseTitle: course['title']?.toString() ?? 'Course',
            ),
          )),
        ),
        PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => <PopupMenuEntry>[
            PopupMenuItem(
              child: const Row(
                children: [
                  Icon(Icons.copy, size: 20),
                  SizedBox(width: 12),
                  Text('Duplicate'),
                ],
              ),
              onTap: () {
                // TODO: Implement duplicate
              },
            ),
            PopupMenuItem(
              child: Row(
                children: [
                  Icon(
                    isPublished ? Icons.unpublished : Icons.publish,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(isPublished ? 'Unpublish' : 'Publish'),
                ],
              ),
              onTap: () {
                // TODO: Implement publish/unpublish
              },
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              child: const Row(
                children: [
                  Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
              onTap: () => Future.delayed(
                const Duration(milliseconds: 100),
                () => _deleteCourse(course['_id']),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
