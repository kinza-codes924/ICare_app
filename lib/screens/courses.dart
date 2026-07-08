import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:icare/providers/auth_provider.dart';
import 'package:icare/screens/filters.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/certificates_list.dart';
import 'package:icare/widgets/courses_list.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/custom_text_input.dart';
import 'package:icare/widgets/svg_wrapper.dart';
import 'package:icare/services/course_service.dart';
import 'package:icare/screens/view_course.dart';
import 'package:icare/screens/certificate_templates_screen.dart';

class Courses extends ConsumerStatefulWidget {
  final bool myPurchased;
  final bool browse; // Student: browse-all-courses mode (All/Paid/Free tabs)
  const Courses({super.key, this.myPurchased = false, this.browse = false});

  @override
  ConsumerState<Courses> createState() => _CoursesState();
}

class _CoursesState extends ConsumerState<Courses>
    with SingleTickerProviderStateMixin {
  late TabController controller;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    final role = ref.read(authProvider).userRole;
    final isStudent = role == 'Student';
    final int len;
    if (role == "Instructor") {
      len = 1;
    } else if (isStudent) {
      // Browse mode: All / Paid / Free — My Courses mode: My Courses / My Progress
      len = widget.browse ? 3 : 2;
    } else {
      len = 3;
    }
    controller = TabController(
      length: len,
      vsync: this,
      initialIndex: (!isStudent && widget.myPurchased) ? 1 : 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.read(authProvider).userRole;
    final isStudent = role == 'Student';
    final isPatient = role == 'Patient';
    log(role ?? '');
    log(controller.length.toString());
    if (MediaQuery.of(context).size.width > 800) {
      return _WebCoursesScreen(
        controller: controller,
        role: role,
        browse: widget.browse,
        searchController: _searchController,
        onSearchChanged: (val) => setState(() => _searchQuery = val),
        searchQuery: _searchQuery,
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: CustomBackButton(),
        title: CustomText(
          text: isPatient
              ? "Health Programs"
              : (isStudent
                    ? (widget.browse ? "Browse Courses" : "My Courses")
                    : "Courses"),
          fontFamily: "Gilroy-Bold",
          fontSize: 16.78,
          color: AppColors.primary500,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.31,
          lineHeight: 1.0,
        ),
      ),
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CustomInputField(
              width: Utils.windowWidth(context) * 0.9,
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              hintText: "Search",
              trailingIcon: SvgWrapper(
                assetPath: ImagePaths.filters,
                onPress: () {
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (ctx) => FiltersScreen()));
                },
              ),
              leadingIcon: SvgWrapper(assetPath: ImagePaths.search),
            ),

            SizedBox(
              width: Utils.windowWidth(context),

              // height: Utils.windowHeight(context) * 0.06,
              child: TabBar(
                controller: controller,
                indicatorWeight: 6,
                indicatorColor: AppColors.themeBlack,
                tabs: [
                  if (isStudent && widget.browse) ...[
                    CustomText(
                      text: "All Courses",
                      padding: const EdgeInsets.only(bottom: 5),
                      width: Utils.windowWidth(context) * 0.33,
                      textAlign: TextAlign.center,
                    ),
                    CustomText(
                      text: "Paid",
                      padding: const EdgeInsets.only(bottom: 5),
                      width: Utils.windowWidth(context) * 0.33,
                      textAlign: TextAlign.center,
                    ),
                    CustomText(
                      text: "Free",
                      padding: const EdgeInsets.only(bottom: 5),
                      width: Utils.windowWidth(context) * 0.33,
                      textAlign: TextAlign.center,
                    ),
                  ] else if (isStudent) ...[
                    CustomText(
                      text: "My Courses",
                      padding: const EdgeInsets.only(bottom: 5),
                      width: Utils.windowWidth(context) * 0.45,
                      textAlign: TextAlign.center,
                    ),
                    CustomText(
                      text: "My Progress",
                      padding: const EdgeInsets.only(bottom: 5),
                      width: Utils.windowWidth(context) * 0.45,
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    CustomText(
                      text: isPatient ? "All Programs" : "All Courses",
                      padding: const EdgeInsets.only(bottom: 5),
                      width: Utils.windowWidth(context) * 0.33,
                      textAlign: TextAlign.center,
                    ),
                    if (role == "Instructor") ...[
                      SizedBox(width: Utils.windowWidth(context) * 0.33),
                      SizedBox(width: Utils.windowWidth(context) * 0.33),
                    ],
                    if (role != "Instructor") ...[
                      CustomText(
                        text: isPatient ? "My Health Journey" : "My Purchase",
                        padding: const EdgeInsets.only(bottom: 5),
                        width: Utils.windowWidth(context) * 0.33,
                        textAlign: TextAlign.center,
                      ),
                      CustomText(
                        padding: const EdgeInsets.only(bottom: 5),
                        width: Utils.windowWidth(context) * 0.33,
                        textAlign: TextAlign.center,
                        text: isPatient ? "Progress" : "Purchased",
                      ),
                    ],
                  ],
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: controller,
                children: [
                  if (isStudent && widget.browse) ...[
                    CoursesList(searchQuery: _searchQuery),
                    CoursesList(searchQuery: _searchQuery, priceFilter: 'paid'),
                    CoursesList(searchQuery: _searchQuery, priceFilter: 'free'),
                  ] else if (isStudent) ...[
                    CoursesList(mypurchased: true, searchQuery: _searchQuery),
                    _WebProgressList(searchQuery: _searchQuery),
                  ] else ...[
                    CoursesList(searchQuery: _searchQuery),
                    if (role != "Instructor") ...[
                      CoursesList(mypurchased: true, searchQuery: _searchQuery),
                      CertificatesList(),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// NEW STUNNING WEB VIEW
// ═══════════════════════════════════════════════════════════════════════════

class _WebCoursesScreen extends StatelessWidget {
  final TabController controller;
  final String role;
  final bool browse;
  final TextEditingController searchController;
  final Function(String) onSearchChanged;
  final String searchQuery;

  const _WebCoursesScreen({
    required this.controller,
    required this.role,
    this.browse = false,
    required this.searchController,
    required this.onSearchChanged,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final isPatient = role.toLowerCase() == 'patient';
    final isStudent = role == 'Student';
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: CustomBackButton(),
        title: CustomText(
          text: isPatient
              ? "All Programs"
              : (isStudent
                    ? (browse ? "Browse Courses" : "My Courses")
                    : "Courses"),
          fontFamily: "Gilroy-Bold",
          fontSize: 20,
          color: AppColors.primaryColor,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.31,
          lineHeight: 1.0,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              // Search & Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPatient
                              ? "Your Health Programs"
                              : (isStudent && !browse
                                    ? "Your Courses"
                                    : "Find Your Next Course"),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            fontFamily: "Gilroy-Bold",
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isPatient
                              ? "Discover programs assigned by your doctor to enhance your well-being."
                              : (isStudent && !browse
                                    ? "You can see and track your course progress here."
                                    : "Discover amazing topics to enhance your skills and career."),
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      width: 350,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x05000000),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: searchController,
                          onChanged: onSearchChanged,
                          decoration: InputDecoration(
                            hintText: isPatient
                                ? "Search programs..."
                                : "Search courses...",
                            hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                            ),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.all(12),
                              child: SvgWrapper(assetPath: ImagePaths.search),
                            ),
                            suffixIcon: IconButton(
                              icon: SvgWrapper(assetPath: ImagePaths.filters),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (ctx) => FiltersScreen(),
                                  ),
                                );
                              },
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  height: 48,
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F0), width: 2),
                    ),
                  ),
                  child: TabBar(
                    controller: controller,
                    indicatorWeight: 3,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorColor: AppColors.primaryColor,
                    labelColor: AppColors.primaryColor,
                    unselectedLabelColor: const Color(0xFF64748B),
                    labelStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: "Gilroy-SemiBold",
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      fontFamily: "Gilroy-Medium",
                    ),
                    tabs: [
                      if (isStudent && browse) ...[
                        const Tab(text: "All Courses"),
                        const Tab(text: "Paid Courses"),
                        const Tab(text: "Free Courses"),
                      ] else if (isStudent) ...[
                        const Tab(text: "My Courses"),
                        const Tab(text: "My Progress"),
                      ] else ...[
                        Tab(
                          text: isPatient ? "All Programs" : "All Courses",
                        ),
                        if (role != "Instructor")
                          Tab(
                            text: isPatient
                                ? "My Health Journey"
                                : "My Purchase",
                          ),
                        if (role != "Instructor")
                          Tab(
                            text: isPatient ? "Progress" : "Certificates",
                          ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Content
              Expanded(
                child: TabBarView(
                  controller: controller,
                  children: [
                    if (isStudent && browse) ...[
                      _WebCoursesList(searchQuery: searchQuery),
                      _WebCoursesList(
                        searchQuery: searchQuery,
                        priceFilter: 'paid',
                      ),
                      _WebCoursesList(
                        searchQuery: searchQuery,
                        priceFilter: 'free',
                      ),
                    ] else if (isStudent) ...[
                      _WebCoursesList(
                        myPurchased: true,
                        searchQuery: searchQuery,
                      ),
                      _WebProgressList(searchQuery: searchQuery),
                    ] else ...[
                      _WebCoursesList(searchQuery: searchQuery),
                      if (role != "Instructor") ...[
                        _WebCoursesList(
                          myPurchased: true,
                          searchQuery: searchQuery,
                        ),
                        const _WebCertificatesList(),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebCoursesList extends StatefulWidget {
  final bool myPurchased;
  final String searchQuery;
  final String priceFilter; // 'all' | 'paid' | 'free'
  const _WebCoursesList({
    this.myPurchased = false,
    this.searchQuery = "",
    this.priceFilter = 'all',
  });

  @override
  State<_WebCoursesList> createState() => _WebCoursesListState();
}

class _WebCoursesListState extends State<_WebCoursesList> {
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
      final data = widget.myPurchased
          ? await _courseService.myPurchases()
          : await _courseService.listPublicCourses();
      if (mounted) {
        setState(() {
          _courses = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching web courses: $e');
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

    final filteredCourses = _courses.where((item) {
      final course = widget.myPurchased ? item['course'] : item;
      if (course == null) return false;

      // Only show CRP course in browse mode
      if (!widget.myPurchased) {
        final title = (course['title'] ?? course['name'] ?? '').toString().toLowerCase();
        if (!title.contains('certificate in research') && !title.contains('crp')) return false;
      }

      // Price filter (Browse Courses: Paid / Free tabs)
      if (widget.priceFilter != 'all') {
        final price = (course['price'] is num) ? (course['price'] as num) : 0;
        if (widget.priceFilter == 'paid' && price <= 0) return false;
        if (widget.priceFilter == 'free' && price > 0) return false;
      }
      if (widget.searchQuery.isEmpty) return true;
      final title = (course["title"] ?? course["name"] ?? "")
          .toString()
          .toLowerCase();
      final desc = (course["caption"] ?? course["desc"] ?? "")
          .toString()
          .toLowerCase();
      return title.contains(widget.searchQuery.toLowerCase()) ||
          desc.contains(widget.searchQuery.toLowerCase());
    }).toList();

    if (filteredCourses.isEmpty) {
      return const Center(child: Text("No courses found"));
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      itemCount: filteredCourses.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (ctx, i) {
        final item = filteredCourses[i];
        final course = widget.myPurchased ? item['course'] : item;

        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => ViewCourse(
                  courseData: course,
                  enrollmentId: widget.myPurchased ? item['_id'] : null,
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF1F4F9), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  offset: Offset(0, 4),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: _buildCourseListImage(course["image"] ?? course["thumbnail"], 180),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                course["tag"] ?? "Health",
                                style: const TextStyle(
                                  color: AppColors.primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFF59E0B),
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              () {
                                final r = course["rating"];
                                if (r is Map) return "${r["average"] ?? 0}";
                                final num v = (r is num) ? r : 0;
                                return v > 0 ? "$v" : "New";
                              }(),
                              style: const TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          course["title"] ?? course["name"] ?? 'Untitled',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                            fontFamily: "Gilroy-Bold",
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          (course["desc"] ?? course["description"])?.toString() ?? 'No description',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        const Divider(color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline_rounded,
                              size: 16,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _extractInstructorName(course["instructor"]),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                                fontFamily: "Gilroy-SemiBold",
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
          ),
        );
      },
    );
  }

  Widget _buildCourseListImage(dynamic image, double height) {
    if (image == null || image.toString().trim().isEmpty) {
      return Image.asset(
        ImagePaths.coursePremium,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }

    final String imagePath = image.toString().trim();

    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Image.asset(
          ImagePaths.coursePremium,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    final bool isValidAsset =
        imagePath.contains('assets/') &&
        (imagePath.endsWith('.png') ||
            imagePath.endsWith('.jpg') ||
            imagePath.endsWith('.jpeg') ||
            imagePath.endsWith('.svg'));

    if (isValidAsset) {
      return Image.asset(
        imagePath,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Image.asset(
          ImagePaths.coursePremium,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    return Image.asset(
      ImagePaths.coursePremium,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
    );
  }
}

// ── My Progress — enrolled courses with progress bar + Open Course button ──
class _WebProgressList extends StatefulWidget {
  final String searchQuery;
  const _WebProgressList({this.searchQuery = ""});

  @override
  State<_WebProgressList> createState() => _WebProgressListState();
}

class _WebProgressListState extends State<_WebProgressList> {
  final CourseService _courseService = CourseService();
  List<dynamic> _enrollments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final data = await _courseService.myPurchases();
      if (mounted) {
        setState(() {
          _enrollments = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching progress list: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _progressOf(dynamic item) {
    final p = item['progress'];
    if (p is num) return (p.toDouble()).clamp(0, 100);
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = _enrollments.where((item) {
      final course = item['course'];
      if (course == null) return false;
      if (widget.searchQuery.isEmpty) return true;
      final title = (course["title"] ?? course["name"] ?? "")
          .toString()
          .toLowerCase();
      return title.contains(widget.searchQuery.toLowerCase());
    }).toList();

    if (items.isEmpty) {
      return const Center(child: Text("You have not enrolled in any course yet"));
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 500,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        childAspectRatio: 2.4,
      ),
      itemBuilder: (ctx, i) {
        final item = items[i];
        final course = item['course'] ?? {};
        final progress = _progressOf(item);
        final done = progress >= 100;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1F4F9), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x05000000),
                offset: Offset(0, 4),
                blurRadius: 16,
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: done
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      done
                          ? Icons.check_circle_rounded
                          : Icons.play_lesson_outlined,
                      color: done
                          ? const Color(0xFF10B981)
                          : AppColors.primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      course['title'] ?? course['name'] ?? 'Course',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                        fontFamily: "Gilroy-Bold",
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress / 100,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFF1F5F9),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          done ? const Color(0xFF10B981) : AppColors.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${progress.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: done ? const Color(0xFF10B981) : AppColors.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (done)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Completed',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => ViewCourse(
                            courseData: course,
                            enrollmentId: item['_id'],
                          ),
                        ),
                      ).then((_) => _fetch());
                    },
                    icon: Icon(
                      done ? Icons.visibility_rounded : Icons.play_arrow_rounded,
                      size: 16,
                    ),
                    label: Text(done ? 'View Course' : 'Open Course'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WebCertificatesList extends ConsumerStatefulWidget {
  const _WebCertificatesList();

  @override
  ConsumerState<_WebCertificatesList> createState() => _WebCertificatesListState();
}

class _WebCertificatesListState extends ConsumerState<_WebCertificatesList> {
  final CourseService _courseService = CourseService();
  List<dynamic> _certificates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCertificates();
  }

  Future<void> _fetchCertificates() async {
    try {
      final data = await _courseService.myCertificates();
      if (mounted) {
        setState(() {
          _certificates = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching web certificates: $e');
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

    if (_certificates.isEmpty) {
      return const Center(child: Text("No certificates available"));
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      itemCount: _certificates.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 500,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        childAspectRatio: 2.2,
      ),
      itemBuilder: (ctx, i) {
        final item = _certificates[i];
        final course = item['course'] ?? {};

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1F4F9), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x05000000),
                offset: Offset(0, 4),
                blurRadius: 16,
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      course['title'] ?? course['name'] ?? 'Course',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                        fontFamily: "Gilroy-Bold",
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '100% Completed',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            final user = ref.read(authProvider).user;
                            final courseTitle = course['title']?.toString() ?? course['name']?.toString() ?? 'Course';
                            final courseId = (item['courseId'] ?? course['_id'])?.toString() ?? '';
                            final enrollmentId = item['enrollmentId']?.toString() ?? '';
                            final studentName = item['studentName']?.toString() ?? user?.name ?? 'Student';
                            final instructorName = item['instructorName']?.toString() ?? 'Instructor';
                            final completionDate = item['completedAt'] != null ? DateTime.tryParse(item['completedAt'].toString()) : null;
                            CertificateTemplate tpl;
                            switch ((item['template']?.toString() ?? '').toLowerCase()) {
                              case 'modern':      tpl = CertificateTemplate.modern; break;
                              case 'elegant':     tpl = CertificateTemplate.elegant; break;
                              case 'achievement': tpl = CertificateTemplate.achievement; break;
                              default:            tpl = CertificateTemplate.classic;
                            }
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => LmsCertificateScreen(
                                studentName: studentName,
                                courseTitle: courseTitle,
                                instructorName: instructorName,
                                template: tpl,
                                completionDate: completionDate,
                                enrollmentId: enrollmentId,
                                courseId: courseId,
                              ),
                            ));
                          },
                          icon: const Icon(Icons.visibility_rounded, size: 16),
                          label: const Text("View"),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primaryColor,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                          ),
                        ),
                        const SizedBox(width: 16),
                        TextButton.icon(
                          onPressed: () {
                            final user = ref.read(authProvider).user;
                            final courseTitle = course['title']?.toString() ?? course['name']?.toString() ?? 'Course';
                            final courseId = (item['courseId'] ?? course['_id'])?.toString() ?? '';
                            final enrollmentId = item['enrollmentId']?.toString() ?? '';
                            final studentName = item['studentName']?.toString() ?? user?.name ?? 'Student';
                            final instructorName = item['instructorName']?.toString() ?? 'Instructor';
                            final completionDate = item['completedAt'] != null ? DateTime.tryParse(item['completedAt'].toString()) : null;
                            CertificateTemplate tpl;
                            switch ((item['template']?.toString() ?? '').toLowerCase()) {
                              case 'modern':      tpl = CertificateTemplate.modern; break;
                              case 'elegant':     tpl = CertificateTemplate.elegant; break;
                              case 'achievement': tpl = CertificateTemplate.achievement; break;
                              default:            tpl = CertificateTemplate.classic;
                            }
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => LmsCertificateScreen(
                                studentName: studentName,
                                courseTitle: courseTitle,
                                instructorName: instructorName,
                                template: tpl,
                                completionDate: completionDate,
                                enrollmentId: enrollmentId,
                                courseId: courseId,
                              ),
                            ));
                          },
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text("Download"),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
