import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/screens/courses.dart';
import 'package:icare/screens/instructor_filters.dart';
import 'package:icare/screens/instructor_courses_management.dart';
import 'package:icare/screens/instructor_create_course.dart';
import 'package:icare/screens/instructor_dashboard.dart';
import 'package:icare/screens/laboratories.dart';
import 'package:icare/screens/labb_details.dart';
import 'package:icare/screens/view_course.dart';
import 'package:icare/services/instructor_service.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/courses_list.dart';
import 'package:icare/widgets/custom_text_input.dart';
import 'package:icare/widgets/laboratory.dart';
import 'package:icare/widgets/section_header.dart';
import 'package:icare/widgets/svg_wrapper.dart';

class InstructorHome extends StatefulWidget {
  const InstructorHome({super.key});

  @override
  State<InstructorHome> createState() => _InstructorHomeState();
}

class _InstructorHomeState extends State<InstructorHome> {
  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Utils.windowWidth(context) > 900;

    // ── MOBILE: original layout (untouched) ────────────────────────────────
    if (!isDesktop) {
      return Center(
        child: Column(
          children: [
            SizedBox(height: ScallingConfig.scale(10)),
            // Dashboard Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => const InstructorDashboardScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.dashboard_rounded, size: 20),
                label: const Text(
                  'View Dashboard',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: Size(Utils.windowWidth(context) * 0.9, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            SizedBox(height: ScallingConfig.scale(20)),
            CustomInputField(
              width: Utils.windowWidth(context) * 0.9,
              hintText: "Search",
              trailingIcon: SvgWrapper(
                assetPath: ImagePaths.filters,
                onPress: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => InstructorFiltersScreen(),
                    ),
                  );
                },
              ),
              leadingIcon: SvgWrapper(assetPath: ImagePaths.search),
            ),
            SizedBox(height: ScallingConfig.scale(20)),
            SectionHeader(
              title: "My Courses",
              width: Utils.windowWidth(context) * 0.9,
              onActionTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (ctx) => Courses()));
              },
            ),
            CoursesList(
              numOfCourses: 2,
              constraintHeight: Utils.windowHeight(context) * 0.3,
            ),
            SizedBox(height: ScallingConfig.scale(20)),
            SectionHeader(
              title: "Laboratories",
              width: Utils.windowWidth(context) * 0.9,
              onActionTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (ctx) => LaboratoriesScreen()),
                );
              },
            ),
            SizedBox(height: ScallingConfig.scale(20)),
            Laboratory(),
          ],
        ),
      );
    }

    // ── WEB: premium dashboard layout ──────────────────────────────────────
    return _InstructorWebDashboard();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WEB DASHBOARD
// ═══════════════════════════════════════════════════════════════════════════
class _InstructorWebDashboard extends StatefulWidget {
  const _InstructorWebDashboard();

  @override
  State<_InstructorWebDashboard> createState() =>
      _InstructorWebDashboardState();
}

class _InstructorWebDashboardState extends State<_InstructorWebDashboard> {
  final InstructorService _instructorService = InstructorService();
  List<dynamic> _courses = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _instructorService.getMyCourses(),
        _instructorService.getStats(),
      ]);

      if (mounted) {
        setState(() {
          _courses = results[0] as List;
          _stats = results[1] as Map<String, dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading instructor data: $e');
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

    final statsData = [
      {
        "label": "Total Courses",
        "value": "${_stats['totalCourses'] ?? 0}",
        "icon": Icons.menu_book_rounded,
        "color": const Color(0xFF6366F1),
      },
      {
        "label": "Active Students",
        "value": "${_stats['totalStudents'] ?? 0}",
        "icon": Icons.group_rounded,
        "color": const Color(0xFF10B981),
      },
      {
        "label": "Avg. Rating",
        "value": "${_stats['avgRating'] ?? 0}★",
        "icon": Icons.star_rounded,
        "color": const Color(0xFFF59E0B),
      },
      {
        "label": "Health Tips",
        "value": "${_stats['totalPrecautions'] ?? 0}",
        "icon": Icons.health_and_safety_rounded,
        "color": const Color(0xFF3B82F6),
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          _buildHeader(context),
          const SizedBox(height: 36),

          // ── Stats Row ───────────────────────────────────────────────────
          _buildStatsRow(statsData),
          const SizedBox(height: 40),

          // ── Courses Section ─────────────────────────────────────────────
          _buildSectionTitle(context, "My Courses", () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => const InstructorCoursesManagementScreen(),
              ),
            );
          }),
          const SizedBox(height: 20),
          _courses.isEmpty ? _buildEmptyState() : _buildCoursesGrid(context),
          const SizedBox(height: 40),

          // ── Laboratories Section ─────────────────────────────────────────
          _buildSectionTitle(context, "Nearby Laboratories", () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (ctx) => LaboratoriesScreen()));
          }),
          const SizedBox(height: 20),
          _buildLaboratoriesRow(context),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.school_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'No courses yet',
            style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => const InstructorCreateCourseScreen(),
                ),
              );
              _loadData();
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Your First Course'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header with search ──────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Instructor Dashboard",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Manage your courses, students and laboratories",
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Search bar
        Container(
          width: 320,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const TextField(
            decoration: InputDecoration(
              hintText: "Search courses, labs...",
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: Color(0xFF94A3B8),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 15),
              hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            ),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => const InstructorCreateCourseScreen(),
              ),
            );
            _loadData();
          },
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text(
            "New Course",
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 8,
            shadowColor: AppColors.primaryColor.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }

  // ── Stats row ────────────────────────────────────────────────────────────
  Widget _buildStatsRow(List<Map<String, dynamic>> statsData) {
    return Row(
      children: statsData.map((stat) {
        return Expanded(
          child: Container(
            margin: statsData.indexOf(stat) < statsData.length - 1
                ? const EdgeInsets.only(right: 20)
                : EdgeInsets.zero,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (stat['color'] as Color).withValues(alpha: 0.07),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: (stat['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    stat['icon'] as IconData,
                    color: stat['color'] as Color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat['value'] as String,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      stat['label'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Section title ────────────────────────────────────────────────────────
  Widget _buildSectionTitle(
    BuildContext context,
    String title,
    VoidCallback onViewAll,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        GestureDetector(
          onTap: onViewAll,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "View All",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Courses grid ─────────────────────────────────────────────────────────
  Widget _buildCoursesGrid(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 380,
        mainAxisExtent: 300,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
      ),
      itemCount: _courses.length > 4 ? 4 : _courses.length,
      itemBuilder: (ctx, i) {
        final course = _courses[i];
        final videoCount = (course['videos'] as List?)?.length ?? 0;

        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (ctx) => ViewCourse(courseData: course)),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Course image placeholder
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.school_rounded,
                      size: 60,
                      color: AppColors.primaryColor.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course['title'] ?? 'Untitled Course',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        course['caption'] ?? 'No description',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.play_circle_outline,
                            size: 14,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$videoCount videos',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: course['visibility'] == 'public'
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              course['visibility'] ?? 'public',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: course['visibility'] == 'public'
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Laboratories row ─────────────────────────────────────────────────────
  Widget _buildLaboratoriesRow(BuildContext context) {
    final labs = [
      {
        "name": "Quantum Spar Lab",
        "location": "4915 Muller Radial, 84904, USA",
        "open": "Open at 9:00am",
        "image": ImagePaths.lab3,
      },
      {
        "name": "MedTech Laboratory",
        "location": "221B Baker Street, London, UK",
        "open": "Open at 8:30am",
        "image": ImagePaths.lab3,
      },
      {
        "name": "BioSci Research Lab",
        "location": "500 Innovation Drive, NY, USA",
        "open": "Open at 10:00am",
        "image": ImagePaths.lab3,
      },
    ];

    return Row(
      children: labs.asMap().entries.map((entry) {
        final i = entry.key;
        final lab = entry.value;
        return Expanded(
          child: GestureDetector(
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (ctx) => LabDetails())),
            child: Container(
              margin: i < labs.length - 1
                  ? const EdgeInsets.only(right: 24)
                  : EdgeInsets.zero,
              height: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: DecorationImage(
                  image: AssetImage(lab['image']!),
                  fit: BoxFit.cover,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Dark gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.72),
                        ],
                      ),
                    ),
                  ),
                  // Content
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lab['name']!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              color: Colors.white70,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                lab['location']!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              color: Colors.white70,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              lab['open']!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (ctx) => LabDetails()),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primaryColor,
                            elevation: 0,
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            "Visit Lab",
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
