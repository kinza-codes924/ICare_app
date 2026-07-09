import 'package:flutter/material.dart';
import 'package:icare/services/course_service.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/course_card.dart';

class CoursesList extends StatefulWidget {
  const CoursesList({
    super.key,
    this.numOfCourses,
    this.constraintHeight,
    this.mypurchased = false,
    this.searchQuery = "",
    this.priceFilter = 'all',
  });

  final String searchQuery;
  final bool mypurchased;
  final double? constraintHeight;
  final int? numOfCourses;
  final String priceFilter; // 'all' | 'paid' | 'free'

  @override
  State<CoursesList> createState() => _CoursesListState();
}

class _CoursesListState extends State<CoursesList> {
  final CourseService _courseService = CourseService();
  List<dynamic> _courses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCourses();
  }

  String _extractInstructorName(dynamic instructor) {
    if (instructor == null) return 'Instructor';

    if (instructor is String) return instructor;

    if (instructor is Map) {
      // Try to get name from nested user object
      final user = instructor['user'];
      if (user is Map && user['name'] is String) {
        return user['name'] as String;
      }

      // Try to get name directly from instructor object
      if (instructor['name'] is String) {
        return instructor['name'] as String;
      }
    }

    return 'Instructor';
  }

  Future<void> _fetchCourses() async {
    try {
      final List<dynamic> data;
      if (widget.mypurchased) {
        data = await _courseService.myPurchases();
      } else {
        data = await _courseService.listPublicCourses();
      }

      if (mounted) {
        setState(() {
          _courses = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching courses list: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final List<dynamic> filteredCourses = _courses.where((item) {
      final Map<String, dynamic> courseData = widget.mypurchased
          ? (item['course'] as Map<String, dynamic>? ?? {})
          : (item as Map<String, dynamic>? ?? {});

      // Only show CRP course in browse mode
      if (!widget.mypurchased) {
        final title = (courseData['title'] ?? courseData['name'] ?? '').toString().toLowerCase();
        if (!title.contains('certificate in research') && !title.contains('crp')) return false;
      }

      // Price filter (Browse Courses: Paid / Free tabs)
      if (widget.priceFilter != 'all') {
        final price = (courseData['price'] is num)
            ? (courseData['price'] as num)
            : 0;
        if (widget.priceFilter == 'paid' && price <= 0) return false;
        if (widget.priceFilter == 'free' && price > 0) return false;
      }

      if (widget.searchQuery.isEmpty) return true;

      final title = (courseData["title"] ?? courseData["name"] ?? "")
          .toString()
          .toLowerCase();
      final desc = (courseData["caption"] ?? courseData["desc"] ?? "")
          .toString()
          .toLowerCase();
      final query = widget.searchQuery.toLowerCase();

      return title.contains(query) || desc.contains(query);
    }).toList();

    if (filteredCourses.isEmpty) {
      return const Center(child: Text("No health programs found"));
    }

    final displayCount = widget.numOfCourses != null
        ? (widget.numOfCourses! < filteredCourses.length
              ? widget.numOfCourses!
              : filteredCourses.length)
        : filteredCourses.length;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: widget.constraintHeight ?? Utils.windowHeight(context) * 0.7,
      ),
      child: GridView.builder(
        itemCount: displayCount,
        padding: const EdgeInsets.all(20),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: Utils.windowHeight(context) * 0.35,
          childAspectRatio: 3 / 2,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
        ),
        itemBuilder: (ctx, i) {
          final course = filteredCourses[i];
          // Handle both direct course objects and enrollment objects (which have a 'course' field)
          final Map<String, dynamic> courseData = widget.mypurchased
              ? Map<String, dynamic>.from(course['course'] as Map? ?? {})
              : Map<String, dynamic>.from(course as Map? ?? {});

          if (widget.mypurchased) {
            courseData['isPurchased'] = true;
          }

          // Pick the first non-empty thumbnail field the backend might return
          final thumbRaw = courseData["thumbnail_url"] ??
              courseData["thumbnail"] ??
              courseData["image"];
          final thumbStr = (thumbRaw is String && thumbRaw.trim().isNotEmpty)
              ? thumbRaw.trim()
              : ImagePaths.course1;

          return CourseCard(
            image: thumbStr,
            title: (courseData["title"] is String)
                ? (courseData["title"] as String)
                : ((courseData["name"] is String)
                      ? (courseData["name"] as String)
                      : 'Untitled Program'),
            desc: (courseData["caption"] is String)
                ? (courseData["caption"] as String)
                : ((courseData["desc"] is String)
                      ? (courseData["desc"] as String)
                      : 'No description available'),
            instructor: _extractInstructorName(courseData["instructor"]),
            courseData: courseData,
          );
        },
      ),
    );
  }
}
