import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/screens/courses.dart';
import 'package:icare/screens/instructor_filters.dart';
import 'package:icare/screens/laboratories.dart';
import 'package:icare/screens/labb_details.dart';
import 'package:icare/screens/my_learning.dart';
import 'package:icare/screens/view_course.dart';
import 'package:icare/services/course_service.dart';
import 'package:icare/services/laboratory_service.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/courses_list.dart';
import 'package:icare/widgets/custom_text_input.dart';
import 'package:icare/widgets/laboratory.dart';
import 'package:icare/widgets/section_header.dart';
import 'package:icare/widgets/svg_wrapper.dart';

class StudentHome extends ConsumerStatefulWidget {
  const StudentHome({super.key});

  @override
  ConsumerState<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends ConsumerState<StudentHome> {
  final CourseService _courseService = CourseService();
  final LaboratoryService _labService = LaboratoryService();

  List<dynamic> _courses = [];
  List<dynamic> _labs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final results = await Future.wait([
        _courseService.listPublicCourses(),
        _labService.getAllLaboratories(),
      ]);

      if (mounted) {
        setState(() {
          _courses = results[0];
          _labs = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching student home data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Utils.windowWidth(context) > 900;
    final role = ref.read(authProvider).userRole.toLowerCase();
    final isPatient = role == 'patient';

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // ── MOBILE: original layout (untouched) ────────────────────────────────
    if (!isDesktop) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
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
                title: isPatient ? "Health Programs" : "Courses",
                width: Utils.windowWidth(context) * 0.9,
                onActionTap: () {
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (ctx) => const Courses()));
                },
              ),
              CoursesList(
                numOfCourses: _courses.length > 2 ? 2 : _courses.length,
                constraintHeight: Utils.windowHeight(context) * 0.35,
              ),
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
              Laboratory(labData: _labs.isNotEmpty ? _labs.first : null),
            ],
          ),
        ),
      );
    }

    // ── WEB: premium stunning layout ───────────────────────────────────────
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ═══════════════════════════════════════════════════
          //  HERO BANNER
          // ═══════════════════════════════════════════════════
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(56, 44, 56, 50),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryColor, Color(0xFF1E3A8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                // Decorative circles
                Positioned(
                  right: -10,
                  top: -30,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                Positioned(
                  right: 100,
                  bottom: -40,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPatient ? "PATIENT PORTAL" : "STUDENT PORTAL",
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Welcome back 👋",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isPatient
                          ? "Explore your health programs and care plans."
                          : "Explore your courses and nearby laboratories.",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Quick Actions Row
                    Row(
                      children: [
                        // Search bar
                        Expanded(
                          child: Container(
                            height: 52,
                            constraints: const BoxConstraints(maxWidth: 580),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 16),
                                const Icon(
                                  Icons.search_rounded,
                                  color: Color(0xFF94A3B8),
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    decoration: InputDecoration(
                                      hintText: isPatient
                                          ? "Search programs, labs..."
                                          : "Search courses, labs...",
                                      hintStyle: const TextStyle(
                                        color: Color(0xFFADB5BD),
                                        fontSize: 14,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (ctx) =>
                                          InstructorFiltersScreen(),
                                    ),
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryColor,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      "Filter",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // My Learning Button
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => const MyLearningScreen(),
                            ),
                          ),
                          child: Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.school_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  isPatient
                                      ? 'My Health Journey'
                                      : 'My Learning',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ═══════════════════════════════════════════════════
          //  COURSES SECTION
          // ═══════════════════════════════════════════════════
          Container(
            color: const Color(0xFFF8FAFD),
            padding: const EdgeInsets.fromLTRB(56, 48, 56, 52),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  title: isPatient ? "Health Programs" : "Courses",
                  subtitle: isPatient
                      ? "Your assigned care plans"
                      : "Browse available courses",
                  accentColor: AppColors.primaryColor,
                  onViewAll: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (ctx) => const Courses())),
                ),
                const SizedBox(height: 28),

                // Premium course cards grid
                _courses.isEmpty
                    ? const Center(child: Text("No courses available"))
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _courses.length > 4 ? 4 : _courses.length,
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 520,
                              mainAxisExtent: 380,
                              crossAxisSpacing: 28,
                              mainAxisSpacing: 28,
                            ),
                        itemBuilder: (ctx, i) {
                          final c = _courses[i];
                          return _CoursePremiumCard(course: c);
                        },
                      ),
              ],
            ),
          ),

          // ═══════════════════════════════════════════════════
          //  LABORATORIES SECTION
          // ═══════════════════════════════════════════════════
          Container(
            color: const Color(0xFFF0F4FF),
            padding: const EdgeInsets.fromLTRB(56, 48, 56, 64),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  title: "Laboratories",
                  subtitle: "Nearby diagnostic centers",
                  accentColor: const Color(0xFF6366F1),
                  accentGradient: const [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  onViewAll: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => LaboratoriesScreen()),
                  ),
                ),
                const SizedBox(height: 28),

                // Premium lab cards row
                _labs.isEmpty
                    ? const Center(child: Text("No laboratories found"))
                    : Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        children: _labs.take(3).map((lab) {
                          return SizedBox(
                            width:
                                (Utils.windowWidth(context) - 112 - 48) /
                                3, // Roughly 1/3 of available width
                            child: _LabPremiumCard(lab: lab),
                          );
                        }).toList(),
                      ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─── Shared section header ───────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accentColor;
  final List<Color>? accentGradient;
  final VoidCallback onViewAll;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.accentColor,
    this.accentGradient,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
          ],
        ),
        GestureDetector(
          onTap: onViewAll,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    accentGradient ??
                    [accentColor, accentColor.withValues(alpha: 0.8)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "View All",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Premium course card ─────────────────────────────────────────────────────
class _CoursePremiumCard extends StatelessWidget {
  final Map<String, dynamic> course;

  const _CoursePremiumCard({required this.course});

  static String _extractInstructorName(dynamic instructor) {
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

  Widget _buildImage(BuildContext context) {
    String? rawPath = course['image'] ?? course['thumbnail'];
    String imagePath = (rawPath != null && rawPath.toString().trim().isNotEmpty)
        ? rawPath.toString().trim()
        : ImagePaths.coursePremium;

    final bool isNetwork = imagePath.startsWith('http');
    final double height = 180;

    // WEB FIX: Prevent trying to load "assets/" or empty paths as assets
    final bool isValidAsset =
        !isNetwork &&
        imagePath.contains('assets/') &&
        (imagePath.endsWith('.png') ||
            imagePath.endsWith('.jpg') ||
            imagePath.endsWith('.jpeg') ||
            imagePath.endsWith('.svg'));

    if (isNetwork) {
      return Image.network(
        imagePath,
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(height),
      );
    } else if (isValidAsset) {
      return Image.asset(
        imagePath,
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(height),
      );
    } else {
      return _buildPlaceholder(height);
    }
  }

  Widget _buildPlaceholder(double height) {
    return Image.asset(
      ImagePaths.coursePremium,
      width: double.infinity,
      height: height,
      fit: BoxFit.cover,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (ctx) => ViewCourse(courseData: course)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with gradient overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: _buildImage(context),
                ),
                // Bottom gradient overlay on image
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.4),
                        ],
                      ),
                    ),
                  ),
                ),
                // Tag chip
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      course['tag'] ?? 'Health',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                // Rating badge
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFF59E0B),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "${course['rating'] ?? 4.5}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Card info
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (course['title'] is String
                        ? course['title']
                        : (course['name'] is String
                              ? course['name']
                              : 'Untitled Course')),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (course['caption'] is String
                        ? course['caption']
                        : (course['desc'] is String
                              ? course['desc']
                              : 'No description available')),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 15,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _extractInstructorName(course['instructor']),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.group_outlined,
                        size: 15,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "${course['students'] ?? 0} students",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
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
  }
}

// ─── Premium lab card ─────────────────────────────────────────────────────────
class _LabPremiumCard extends StatelessWidget {
  final Map<String, dynamic> lab;

  const _LabPremiumCard({required this.lab});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (ctx) => LabDetails(labData: lab))),
      child: Container(
        height: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
          image: lab['image'] is String
              ? DecorationImage(
                  image: AssetImage(lab['image'] as String),
                  fit: BoxFit.cover,
                )
              : null,
          color: (lab['image'] is! String) ? Colors.blueGrey[100] : null,
        ),
        child: Stack(
          children: [
            // Dark gradient overlay
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.78)],
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
                    ((lab['labName'] is String)
                        ? (lab['labName'] as String)
                        : ((lab['name'] is String)
                              ? (lab['name'] as String)
                              : 'Laboratory')),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                          (lab['address'] is String)
                              ? (lab['address'] as String)
                              : ((lab['location'] is String)
                                    ? (lab['location'] as String)
                                    : 'Location not available'),
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
                        (lab['open'] is String
                            ? lab['open']
                            : 'Open 9:00 AM - 9:00 PM'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.home_rounded,
                        color: Colors.white70,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        (lab['homeSample'] == true)
                            ? 'Home Sample Available'
                            : (lab['homeSample'] == false
                                  ? 'No Home Sample'
                                  : (lab['homeSample']?.toString() ??
                                        'Home Sample Available')),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => LabDetails(labData: lab),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
