import 'package:flutter/material.dart';
import 'package:icare/models/course.dart';
import 'package:icare/screens/doctor_notifications.dart';
import 'package:icare/screens/instructor_create_course.dart';
import 'package:icare/screens/lms_course_page.dart';
import 'package:icare/services/instructor_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/instructor_sidebar.dart';

class InstructorCoursesManagementScreen extends StatefulWidget {
  const InstructorCoursesManagementScreen({super.key});

  @override
  State<InstructorCoursesManagementScreen> createState() =>
      _InstructorCoursesManagementScreenState();
}

class _InstructorCoursesManagementScreenState
    extends State<InstructorCoursesManagementScreen> {
  final InstructorService _instructorService = InstructorService();
  List<dynamic> _courses = [];
  bool _isLoading = true;
  String _filter = 'all'; // all, published, unpublished

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() => _isLoading = true);
    try {
      final courses = await _instructorService.getMyCourses();
      if (mounted) {
        // Debug: Print course data to see isPublished values
        for (var course in courses) {
          print('Course: ${course['title']}, isPublished: ${course['isPublished']}, type: ${course['isPublished'].runtimeType}');
        }
        setState(() {
          _courses = courses;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: const Text('Unable to load data. Please try again.')));
      }
    }
  }

  List<dynamic> get _filteredCourses {
    if (_filter == 'published') {
      return _courses.where((c) {
        final visibility = c['visibility'];
        final isPublished = c['isPublished'];
        // Backend uses visibility field: 'public' means published
        return visibility == 'public' || isPublished == true || isPublished == 'true';
      }).toList();
    } else if (_filter == 'unpublished') {
      return _courses.where((c) {
        final visibility = c['visibility'];
        final isPublished = c['isPublished'];
        // private/students = unpublished
        return visibility == 'private' || visibility == 'students' ||
            isPublished == false || isPublished == 'false' || isPublished == null;
      }).toList();
    }
    return _courses;
  }

  Future<void> _deleteCourse(dynamic course) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Program'),
        content: Text('Are you sure you want to delete "${course['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _instructorService.deleteCourse(course['_id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Course deleted successfully')),
          );
          _loadCourses();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: const Text('Something went wrong. Please try again.')));
        }
      }
    }
  }

  Future<void> _togglePublishStatus(dynamic course) async {
    try {
      final isPublic = course['visibility'] == 'public';
      await _instructorService.updateCourse(
        course['_id'],
        {'visibility': isPublic ? 'private' : 'public'},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPublic
                  ? 'Course unpublished successfully'
                  : 'Course published successfully',
            ),
            backgroundColor: isPublic ? Colors.orange : Colors.green,
          ),
        );
      }
      _loadCourses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: const Text('Something went wrong. Please try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredCourses = _filteredCourses;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: Navigator.of(context).canPop()
            ? const CustomBackButton()
            : Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Color(0xFF0F172A)),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Manage Health Programs',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Color(0xFF0F172A)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DoctorNotifications())),
            tooltip: 'Notifications',
          ),
        ],
      ),
      drawer: const InstructorSidebar(currentRoute: 'programs'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => const InstructorCreateCourseScreen(),
            ),
          );
          if (result == true) _loadCourses();
        },
        backgroundColor: AppColors.primaryColor,
        icon: const Icon(Icons.add),
        label: const Text('New Program'),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Published', 'published'),
                const SizedBox(width: 8),
                _buildFilterChip('Unpublished', 'unpublished'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredCourses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _filter == 'all'
                              ? 'No programs yet'
                              : 'No $_filter programs',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create your first health program to get started',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadCourses,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: filteredCourses.length,
                      itemBuilder: (ctx, i) {
                        return _buildCourseCard(filteredCourses[i]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filter = value);
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

  Widget _buildCourseCard(dynamic course) {
    final modules = course['modules'] as List? ?? [];
    final moduleCount = modules.length;
    final lessonCount = modules.fold<int>(
      0,
      (sum, m) => sum + ((m['lessons'] as List? ?? []).length),
    );
    final isPublished = course['visibility'] == 'public';
    final title = course['title'] ?? 'Untitled';
    final description = course['description'] ?? course['caption'] ?? '';
    final category = course['category'] ?? 'HealthProgram';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.health_and_safety_rounded,
                    color: AppColors.primaryColor,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildBadge(
                            category,
                            Icons.category_outlined,
                            const Color(0xFF8B5CF6),
                          ),
                          _buildBadge(
                            '$moduleCount modules',
                            Icons.library_books_outlined,
                            const Color(0xFF6366F1),
                          ),
                          _buildBadge(
                            '$lessonCount lessons',
                            Icons.play_circle_outline,
                            const Color(0xFF3B82F6),
                          ),
                          _buildBadge(
                            isPublished ? 'Published' : 'Draft',
                            isPublished
                                ? Icons.public
                                : Icons.lock_outline,
                            isPublished
                                ? const Color(0xFF10B981)
                                : const Color(0xFF64748B),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              runSpacing: 4,
              children: [
                // ── Open LMS ───────────────────────────────────────────────
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LmsCoursePage(
                        course: Map<String, dynamic>.from(course),
                        isInstructor: true,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Open LMS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _togglePublishStatus(course),
                  icon: Icon(isPublished ? Icons.unpublished : Icons.publish, size: 16),
                  label: Text(isPublished ? 'Unpublish' : 'Publish'),
                  style: TextButton.styleFrom(
                    foregroundColor: isPublished ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => InstructorCreateCourseScreen(course: Course.fromJson(course)),
                      ),
                    );
                    if (result == true) _loadCourses();
                  },
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primaryColor),
                ),
                TextButton.icon(
                  onPressed: () => _deleteCourse(course),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
