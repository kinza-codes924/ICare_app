import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/models/course.dart';
import 'package:icare/screens/lesson_player.dart';
import 'package:icare/screens/lms_course_page.dart';
import 'package:icare/screens/lms_purchase_flow.dart';
import 'package:icare/screens/quiz_screen.dart';
import 'package:icare/services/course_service.dart';
import 'package:icare/services/course_question_service.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';

class ViewCourse extends ConsumerStatefulWidget {
  final String? enrollmentId;
  final Map<String, dynamic>? courseData;

  const ViewCourse({super.key, this.courseData, this.enrollmentId});

  @override
  ConsumerState<ViewCourse> createState() => _ViewCourseState();
}

class _ViewCourseState extends ConsumerState<ViewCourse> {
  final CourseService _courseService = CourseService();
  final LmsService _lms = LmsService();
  final TextEditingController _questionController = TextEditingController();
  bool _isPurchased = false;
  String? _currentEnrollmentId;
  bool _isPurchasing = false;
  List<dynamic> _questions = [];
  bool _loadingQuestions = false;
  bool _isInstructor = false;
  final Set<String> _completedModuleIds = {};
  final Set<String> _completedLessonIds = {};

  @override
  void initState() {
    super.initState();
    _isPurchased =
        (widget.courseData?['isPurchased'] == true) ||
        widget.enrollmentId != null;
    _currentEnrollmentId = widget.enrollmentId;
    _loadQuestions();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final role = await SharedPref().getUserRole();
    if (mounted) {
      final isInstr = role != null &&
          (role.toLowerCase() == 'instructor' || role.toLowerCase() == 'doctor');
      setState(() {
        _isInstructor = isInstr;
        if (isInstr) _isPurchased = true; // instructors always have access
      });
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    final courseId = widget.courseData?['_id'] ?? widget.courseData?['id'];
    if (courseId == null) return;

    setState(() => _loadingQuestions = true);
    try {
      final questions = await CourseQuestionService.getCourseQuestions(
        courseId,
      );
      setState(() {
        _questions = questions;
        _loadingQuestions = false;
      });
    } catch (e) {
      setState(() => _loadingQuestions = false);
    }
  }

  Future<void> _postQuestion() async {
    final courseId = widget.courseData?['_id'] ?? widget.courseData?['id'];
    if (courseId == null || _questionController.text.trim().isEmpty) return;

    try {
      await CourseQuestionService.askQuestion(
        courseId: courseId,
        question: _questionController.text.trim(),
      );
      _questionController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question posted successfully!')),
        );
        _loadQuestions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: const Text('Something went wrong. Please try again.')));
      }
    }
  }

  Future<void> _enrollInCourse(String courseId) async {
    if (_isPurchasing) return;
    final course = widget.courseData ?? {};
    final price = course['discountedPrice'] ?? course['price'] ?? course['cost'] ?? 0;
    final amount = (price is num) ? price.toDouble() : double.tryParse(price.toString()) ?? 0.0;

    // Free courses → enroll directly without payment
    if (amount <= 0) {
      setState(() => _isPurchasing = true);
      try {
        final result = await _courseService.buyCourse(courseId);
        if (mounted) {
          setState(() {
            _isPurchased = true;
            _currentEnrollmentId = result['enrollment']?['_id'];
            _isPurchasing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Enrolled successfully!")),
          );
        }
      } catch (e) {
        if (mounted) {
          final errorStr = e.toString();
          if (errorStr.contains('Already purchased')) {
            setState(() { _isPurchased = true; _isPurchasing = false; });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("You are already enrolled.")),
            );
          } else {
            setState(() => _isPurchasing = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Enrollment failed: $e")));
          }
        }
      }
      return;
    }

    // Paid courses → go through full purchase/payment flow
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LmsPurchaseFlow(course: course),
      ),
    ).then((_) {
      // On return, re-check enrollment status
      if (mounted) {
        setState(() {
          _isPurchased = widget.courseData?['isPurchased'] == true || _currentEnrollmentId != null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 900;

    final dynamic titleVal =
        widget.courseData?['title'] ?? widget.courseData?['name'];
    final String name = (titleVal is String) ? titleVal : "Untitled Course";

    String instructor = "Health Professional";
    final dynamic instrVal = widget.courseData?['instructor'];
    if (instrVal is String) {
      instructor = instrVal;
    } else if (instrVal is Map) {
      final user = instrVal['user'];
      if (user is Map && user['name'] is String) {
        instructor = user['name'] as String;
      } else if (instrVal['name'] is String) {
        instructor = instrVal['name'] as String;
      }
    }

    final dynamic descVal =
        widget.courseData?['caption'] ??
        widget.courseData?['desc'] ??
        widget.courseData?['description'];
    final String desc = (descVal is String)
        ? descVal
        : "No description available.";

    final dynamic imageVal =
        widget.courseData?['image'] ?? widget.courseData?['thumbnail'];
    String image = ImagePaths.course1;
    if (imageVal is String && imageVal.trim().isNotEmpty) {
      image = imageVal;
    }

    final String courseId =
        widget.courseData?['_id'] ?? widget.courseData?['id'] ?? "";

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: Text(
          name,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isWeb)
              _buildWebView(
                context,
                name,
                instructor,
                desc,
                image,
                _isPurchased,
                courseId,
              )
            else
              _buildMobileView(
                context,
                name,
                instructor,
                desc,
                image,
                _isPurchased,
                courseId,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseImage(String? image, double height) {
    String imagePath = (image != null && image.trim().isNotEmpty)
        ? image.trim()
        : ImagePaths.course1;

    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => Image.asset(
          ImagePaths.course1,
          width: double.infinity,
          height: height,
          fit: BoxFit.cover,
        ),
      );
    }

    // Check if it's a valid local asset path
    if (imagePath.contains('assets/')) {
      return Image.asset(
        imagePath,
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => Image.asset(
          ImagePaths.coursePremium,
          width: double.infinity,
          height: height,
          fit: BoxFit.cover,
        ),
      );
    }

    return Image.asset(
      ImagePaths.coursePremium,
      width: double.infinity,
      height: height,
      fit: BoxFit.cover,
    );
  }

  Widget _buildWebView(
    BuildContext context,
    String name,
    String instructor,
    String desc,
    String image,
    bool isPurchased,
    String courseId,
  ) {
    return DefaultTabController(
      length: 2,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: AppColors.primaryColor,
                  labelColor: AppColors.primaryColor,
                  unselectedLabelColor: const Color(0xFF64748B),
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  tabs: const [
                    Tab(text: "Program Content"),
                    Tab(text: "Discussion & Q&A"),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 800,
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionLabel("Description"),
                            const SizedBox(height: 16),
                            Text(
                              desc,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.6,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 32),
                            _sectionLabel("Program Curriculum"),
                            const SizedBox(height: 16),
                            _buildCurriculumList(
                              context,
                              widget.courseData?['modules'] ?? [],
                              isPurchased,
                              courseId,
                            ),
                          ],
                        ),
                      ),
                      _buildQASection(courseId),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 40),
          Expanded(
            child: _buildSidebar(context, image, isPurchased, name, courseId),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileView(
    BuildContext context,
    String name,
    String instructor,
    String desc,
    String image,
    bool isPurchased,
    String courseId,
  ) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _buildCourseImage(image, 200),
          ),
          const SizedBox(height: 24),
          Text(
            name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "By $instructor",
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          TabBar(
            indicatorColor: AppColors.primaryColor,
            labelColor: AppColors.primaryColor,
            unselectedLabelColor: const Color(0xFF64748B),
            dividerColor: const Color(0xFFE2E8F0),
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: "Curriculum"),
              Tab(text: "Q&A"),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 500,
            child: TabBarView(
              children: [
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel("Description"),
                      const SizedBox(height: 12),
                      Text(
                        desc,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 32),
                      _sectionLabel("Modules"),
                      const SizedBox(height: 16),
                      _buildCurriculumList(
                        context,
                        widget.courseData?['modules'] ?? [],
                        isPurchased,
                        courseId,
                      ),
                    ],
                  ),
                ),
                _buildQASection(courseId),
              ],
            ),
          ),
          const SizedBox(height: 40),
          if (!isPurchased) _buildEnrollmentCard(courseId),
        ],
      ),
    );
  }

  Widget _buildQASection(String courseId) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _questionController,
                  decoration: InputDecoration(
                    hintText: "Ask a question about this program...",
                    prefixIcon: const Icon(
                      Icons.help_outline_rounded,
                      color: Color(0xFF64748B),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _postQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(16),
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingQuestions
              ? const Center(child: CircularProgressIndicator())
              : _questions.isEmpty
              ? const Center(
                  child: Text(
                    'No questions yet. Be the first to ask!',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                )
              : ListView.builder(
                  itemCount: _questions.length,
                  itemBuilder: (context, index) {
                    final q = _questions[index];
                    final student = q['student'];
                    final isAnswered = q['isAnswered'] ?? false;
                    final answer = q['answer'];
                    final createdAt = DateTime.tryParse(q['createdAt'] ?? '');
                    final timeAgo = createdAt != null
                        ? _getTimeAgo(createdAt)
                        : 'Recently';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                radius: 16,
                                backgroundColor: Color(0xFFE2E8F0),
                                child: Icon(
                                  Icons.person,
                                  size: 20,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                student?['name'] ?? 'Student',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                timeAgo,
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            q['question'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          if (isAnswered && answer != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.verified_user_rounded,
                                    color: AppColors.primaryColor,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Instructor: $answer',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildSidebar(
    BuildContext context,
    String image,
    bool isPurchased,
    String name,
    String courseId,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _buildCourseImage(image, 180),
          ),
          const SizedBox(height: 24),
          _buildEnrollmentCard(courseId),
        ],
      ),
    );
  }

  Widget _buildEnrollmentCard(String courseId) {
    if (_isPurchased) {
      return Column(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 48),
          const SizedBox(height: 12),
          const Text('Enrolled', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
          const SizedBox(height: 8),
          const Text('You have active access to this course.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
              label: const Text('Open Course', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => LmsCoursePage(
                  course: widget.courseData ?? {},
                  enrollmentId: _currentEnrollmentId,
                  isInstructor: _isInstructor,
                ),
              )),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      );
    }

    final price = widget.courseData?['price'];
    final isFree = price == null || price == 0;

    return Column(
      children: [
        Text(
          isFree ? 'Free' : 'PKR ${price.toString()}',
          style: TextStyle(
            fontSize: 32, fontWeight: FontWeight.w900,
            color: isFree ? const Color(0xFF10B981) : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isPurchasing ? null : () => _enrollInCourse(courseId),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _isPurchasing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Enroll Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildCurriculumList(
    BuildContext context,
    List<dynamic> modules,
    bool isPurchased,
    String courseId,
  ) {
    if (modules.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            "Curriculum is being updated.",
            style: TextStyle(color: Color(0xFF94A3B8)),
          ),
        ),
      );
    }

    // Flatten all lessons to detect the last one for certificate
    final allLessons = modules.expand((m) => (m['lessons'] as List? ?? [])).toList();
    final lastLessonId = allLessons.isNotEmpty
        ? (allLessons.last['_id'] ?? allLessons.last['id'])?.toString()
        : null;
    // Get course meta for certificate
    final dynamic titleVal2 = widget.courseData?['title'] ?? widget.courseData?['name'];
    final courseTitle = (titleVal2 is String) ? titleVal2 : 'Course';
    String instructorName = 'Instructor';
    final dynamic instrVal2 = widget.courseData?['instructor'];
    if (instrVal2 is Map) {
      instructorName = instrVal2['name']?.toString() ?? instructorName;
    } else if (instrVal2 is String) instructorName = instrVal2;

    // Course type + lock metadata from backend
    final courseType = widget.courseData?['courseType']?.toString() ?? 'self-paced';
    final startDateRaw = widget.courseData?['startDate'];
    DateTime? courseStartDate;
    if (startDateRaw != null) {
      try { courseStartDate = DateTime.parse(startDateRaw.toString()); } catch (_) {}
    }
    // Backend-provided completed module IDs (for self-paced sequential lock)
    final completedModuleIds = <String>{
      ...((widget.courseData?['completedModuleIds'] as List?) ?? []).map((e) => e.toString()),
      ..._completedModuleIds,
    };

    return Column(
      children: modules.asMap().entries.map((mEntry) {
        final mIndex = mEntry.key;
        final module = mEntry.value;
        final lessons = module['lessons'] as List? ?? [];

        // Prefer backend-computed isLocked + unlockDate fields, fall back to client-side
        bool isModuleLocked = module['isLocked'] == true;
        String? moduleLockLabel;

        if (isPurchased && !_isInstructor) {
          if (isModuleLocked) {
            // Use backend-provided unlock date if available
            final unlockRaw = module['unlockDate']?.toString() ?? '';
            if (unlockRaw.isNotEmpty) {
              try {
                final unlockDate = DateTime.parse(unlockRaw);
                moduleLockLabel = 'Unlocks ${unlockDate.day}/${unlockDate.month}/${unlockDate.year}';
              } catch (_) {}
            } else if (courseType == 'pragmatic' && courseStartDate != null) {
              final unlockDays = (module['unlockAfterDays'] as num?)?.toInt() ?? 0;
              final unlockDate = courseStartDate.add(Duration(days: unlockDays));
              moduleLockLabel = 'Unlocks ${unlockDate.day}/${unlockDate.month}/${unlockDate.year}';
            } else if (courseType == 'self-paced' && mIndex > 0) {
              moduleLockLabel = 'Complete the previous module first';
            }
          } else if (!isModuleLocked && courseType == 'pragmatic') {
            // Client-side fallback for pragmatic if backend didn't set isLocked
            final unlockDays = (module['unlockAfterDays'] as num?)?.toInt() ?? 0;
            if (unlockDays > 0 && courseStartDate != null) {
              final unlockDate = courseStartDate.add(Duration(days: unlockDays));
              if (DateTime.now().isBefore(unlockDate)) {
                isModuleLocked = true;
                moduleLockLabel = 'Unlocks ${unlockDate.day}/${unlockDate.month}/${unlockDate.year}';
              }
            }
          } else if (!isModuleLocked && courseType == 'self-paced' && mIndex > 0) {
            // Client-side fallback for self-paced sequential lock
            final prevModule = modules[mIndex - 1];
            final prevId = prevModule['_id']?.toString() ?? '';
            if (prevId.isNotEmpty && !completedModuleIds.contains(prevId)) {
              isModuleLocked = true;
              moduleLockLabel = 'Complete the previous module first';
            }
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isModuleLocked ? const Color(0xFFF8FAFC) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isModuleLocked ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0)),
          ),
          child: ExpansionTile(
            initiallyExpanded: mIndex == 0 && !isModuleLocked,
            leading: isModuleLocked
                ? const Icon(Icons.lock_rounded, color: Color(0xFF94A3B8), size: 20)
                : null,
            title: Row(
              children: [
                Expanded(child: Text(
                  module['title'] ?? "Module ${mIndex + 1}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isModuleLocked ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                  ),
                )),
                if (moduleLockLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                    child: Text(moduleLockLabel, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            children: [
              if (isModuleLocked)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_rounded, color: Color(0xFF94A3B8), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        moduleLockLabel ?? 'Locked',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                )
              else
              ...lessons.map((lesson) {
                return ListTile(
                  leading: const Icon(
                    Icons.play_circle_fill_rounded,
                    color: Color(0xFF3B82F6),
                    size: 24,
                  ),
                  title: Text(
                    lesson['title'] ?? "Untitled Lesson",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: lesson['description'] != null
                      ? Text(
                          lesson['description'],
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  trailing: isPurchased
                      ? const Icon(Icons.arrow_forward_ios_rounded, size: 12)
                      : const Icon(
                          Icons.lock_rounded,
                          size: 16,
                          color: Color(0xFF94A3B8),
                        ),
                  onTap: isPurchased
                      ? () {
                          final lessonId = (lesson['_id'] ?? lesson['id'])?.toString();
                          final isLast = lastLessonId != null && lessonId == lastLessonId;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => LessonPlayer(
                                lesson: lesson,
                                isLastLesson: isLast,
                                courseTitle: courseTitle,
                                instructorName: instructorName,
                                certificateReleased: widget.courseData?['certificateReleased'] == true,
                                enrollmentId: _currentEnrollmentId,
                                initialIsCompleted: lessonId != null && _completedLessonIds.contains(lessonId),
                                onLessonCompleted: (id) => setState(() => _completedLessonIds.add(id)),
                              ),
                            ),
                          );
                        }
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Please enroll to access this content",
                              ),
                            ),
                          );
                        },
                );
              }),
              // Mark Module Complete button (students, unlocked modules, enrolled)
              if (!isModuleLocked && isPurchased && !_isInstructor && _currentEnrollmentId != null) ...[
                const Divider(height: 1),
                Builder(builder: (ctx) {
                  final moduleId = module['_id']?.toString() ?? '';
                  final isDone = _completedModuleIds.contains(moduleId);
                  return ListTile(
                    leading: Icon(
                      isDone ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
                      color: isDone ? const Color(0xFF10B981) : const Color(0xFF64748B),
                    ),
                    title: Text(
                      isDone ? 'Module Completed' : 'Mark Module as Complete',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDone ? const Color(0xFF10B981) : const Color(0xFF14B1FF),
                      ),
                    ),
                    onTap: isDone ? null : () async {
                      if (moduleId.isEmpty) return;
                      final result = await _lms.markModuleComplete(
                        enrollmentId: _currentEnrollmentId!,
                        moduleId: moduleId,
                      );
                      if (mounted) {
                        if (result['success'] != false) {
                          setState(() => _completedModuleIds.add(moduleId));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Module marked as complete!'),
                            backgroundColor: Color(0xFF10B981),
                          ));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(result['message']?.toString() ?? 'Failed'),
                            backgroundColor: Colors.red,
                          ));
                        }
                      }
                    },
                  );
                }),
              ],
              if (!isModuleLocked && module['quiz'] != null) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.emoji_events_rounded,
                    color: Color(0xFFD97706),
                    size: 24,
                  ),
                  title: const Text(
                    'Module Quiz',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  subtitle: const Text(
                    'Test your understanding',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: isPurchased
                      ? const Icon(Icons.arrow_forward_ios_rounded, size: 12)
                      : const Icon(
                          Icons.lock_rounded,
                          size: 16,
                          color: Color(0xFF94A3B8),
                        ),
                  onTap: isPurchased
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => QuizScreen(
                                quiz: Quiz.fromJson(
                                  Map<String, dynamic>.from(module['quiz']),
                                ),
                                title: module['title'] ?? 'Module Quiz',
                                courseId: courseId,
                                enrollmentId: _currentEnrollmentId ?? '',
                              ),
                            ),
                          );
                        }
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Please enroll to take the quiz"),
                            ),
                          );
                        },
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}
