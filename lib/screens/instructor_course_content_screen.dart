import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:icare/screens/certificate_templates_screen.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/screens/lms_live_session_screen.dart';
import 'package:icare/screens/instructor_create_assignment_screen.dart';
import 'package:icare/screens/instructor_create_quiz_screen.dart';
import 'package:icare/screens/instructor_quiz_attempts_screen.dart';
import 'package:icare/screens/instructor_course_analytics_screen.dart';
import 'package:icare/screens/instructor_student_progress_screen.dart';
import 'package:icare/screens/instructor_voucher_screen.dart';
import 'package:icare/widgets/video_player_widget.dart';
import 'package:icare/widgets/attachment_viewer.dart';
import 'package:url_launcher/url_launcher.dart';

/// Course Content Management - Moodle/Udemy style
class InstructorCourseContentScreen extends StatefulWidget {
  final String courseId;
  final bool embedded; // when true, hides AppBar (rendered inside a tab)

  const InstructorCourseContentScreen({
    super.key,
    required this.courseId,
    this.embedded = false,
  });

  @override
  State<InstructorCourseContentScreen> createState() => InstructorCourseContentScreenState();
}

class InstructorCourseContentScreenState extends State<InstructorCourseContentScreen> {
  final LmsService _lmsService = LmsService();

  Map<String, dynamic>? _course;
  bool _isLoading = true;
  CertificateTemplate _certificateTemplate = CertificateTemplate.classic;
  String _courseType = 'self-paced';
  bool _isFreeDisplay = false;

  // Standalone assignments, quizzes, sessions (created outside modules)
  List<dynamic> _assignments = [];
  List<dynamic> _quizzes = [];
  List<dynamic> _liveSessions = [];

  @override
  void initState() {
    super.initState();
    _loadCourse();
  }

  Future<void> _loadCourse() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _lmsService.getCourseDetails(widget.courseId),
        _lmsService.getCourseAssignments(widget.courseId).catchError((_) => <dynamic>[]),
        _lmsService.getCourseQuizzes(widget.courseId).catchError((_) => <dynamic>[]),
        _lmsService.getCourseSessions(widget.courseId).catchError((_) => <dynamic>[]),
      ]);
      if (mounted) {
        setState(() {
          _course = (results[0] as Map)['course'];
          _courseType = _course?['courseType']?.toString() ?? 'self-paced';
          _isFreeDisplay = _course?['isFree'] == true;
          _assignments = results[1] as List;
          _quizzes = results[2] as List;
          _liveSessions = results[3] as List;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  /// Instructor starts a live class — launches iCare built-in LMS live session
  Future<void> _startLiveClass() async {
    final courseTitle = _course?['title']?.toString() ?? 'Live Class';
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LmsLiveSessionScreen(
          sessionId: '',  // empty — backend will create a fresh session with a real _id
          courseId: widget.courseId,
          sessionTitle: courseTitle,
          isInstructor: true,
        ),
      ),
    );
  }

  void addModule() => _addModule();

  Future<void> _addModule() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ModuleDialog(courseId: widget.courseId),
    );

    if (result != null) {
      // Add module to course
      final modules = List<Map<String, dynamic>>.from(_course?['modules'] ?? []);
      modules.add(result);

      // Optimistic update so the new module appears immediately in the UI
      if (mounted) setState(() { _course = { ...?_course, 'modules': modules }; });

      try {
        await _lmsService.updateCourse(widget.courseId, {'modules': modules});
        _loadCourse();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Module added successfully!')),
          );
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

  Future<void> _editModule(int index) async {
    final modules = List<Map<String, dynamic>>.from(_course?['modules'] ?? []);
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ModuleDialog(module: modules[index], courseId: widget.courseId),
    );

    if (result != null) {
      modules[index] = result;

      // Optimistic update — lesson tiles immediately reflect the new documentUrl/videoUrl
      // so the instructor can preview the uploaded content without waiting for _loadCourse.
      if (mounted) setState(() { _course = { ...?_course, 'modules': modules }; });

      try {
        await _lmsService.updateCourse(widget.courseId, {'modules': modules});
        _loadCourse();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Module updated successfully!')),
          );
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

  Future<void> _deleteModule(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Module'),
        content: const Text('Are you sure you want to delete this module?'),
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

    if (confirm == true) {
      final modules = List<Map<String, dynamic>>.from(_course?['modules'] ?? []);
      modules.removeAt(index);
      try {
        await _lmsService.updateCourse(widget.courseId, {'modules': modules});
        _loadCourse();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Module deleted successfully!')),
          );
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

  Future<void> _updateCourseType(String type) async {
    setState(() => _courseType = type);
    try {
      await _lmsService.updateCourse(widget.courseId, {'courseType': type});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Course type set to ${type == 'pragmatic' ? 'Pragmatic (Timeline)' : 'Self-paced'}'), backgroundColor: Colors.green),
        );
      }
    } catch (_) {}
  }

  // Worst-case fallback for vouchers: display the course as "Free" without
  // changing its real price — e.g. while a voucher rollout is still being
  // finalized. Toggled independently of the actual `price` field.
  Future<void> _toggleFreeDisplay(bool value) async {
    setState(() => _isFreeDisplay = value);
    try {
      await _lmsService.updateCourse(widget.courseId, {'isFree': value});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? 'Course now shows as Free to students' : 'Course now shows its real price'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isFreeDisplay = !value);
    }
  }

  void _showEditThumbnail() {
    final urlCtrl = TextEditingController(text: _course?['thumbnail']?.toString() ?? _course?['thumbnail_url']?.toString() ?? '');
    String? previewUrl = urlCtrl.text.isNotEmpty ? urlCtrl.text : null;
    bool uploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Edit Thumbnail', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              if (previewUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(previewUrl!, height: 160, width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(height: 160, color: Colors.grey[200], child: const Icon(Icons.broken_image, size: 48, color: Colors.grey))),
                ),
              if (previewUrl != null) const SizedBox(height: 12),
              // Upload from device
              OutlinedButton.icon(
                onPressed: uploading ? null : () async {
                  final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
                  if (result == null || result.files.isEmpty) return;
                  final file = result.files.first;
                  setSheetState(() => uploading = true);
                  try {
                    final sigRes = await ApiService().get('/upload/sign?folder=icare/thumbnails&resource_type=image');
                    final sig = sigRes.data;
                    final timestamp = sig['timestamp'].toString();
                    final apiKey = sig['api_key'].toString();
                    final signature = sig['signature'].toString();
                    final cloudName = sig['cloud_name'].toString();
                    final folder = (sig['folder'] ?? 'icare/thumbnails').toString();
                    final formData = FormData.fromMap({
                      'file': MultipartFile.fromBytes(file.bytes!, filename: file.name),
                      'api_key': apiKey,
                      'timestamp': timestamp,
                      'signature': signature,
                      'folder': folder,
                    });
                    final uploadRes = await Dio().post('https://api.cloudinary.com/v1_1/$cloudName/image/upload', data: formData);
                    final url = uploadRes.data['secure_url'] as String;
                    setSheetState(() { previewUrl = url; urlCtrl.text = url; uploading = false; });
                  } catch (e) {
                    setSheetState(() => uploading = false);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
                  }
                },
                icon: uploading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.upload_rounded),
                label: Text(uploading ? 'Uploading...' : 'Upload from Device'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                decoration: InputDecoration(
                  labelText: 'Or paste image URL',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  suffixIcon: IconButton(icon: const Icon(Icons.preview), onPressed: () => setSheetState(() => previewUrl = urlCtrl.text.isNotEmpty ? urlCtrl.text : null)),
                ),
                onChanged: (v) => setSheetState(() => previewUrl = v.isNotEmpty ? v : null),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: uploading ? null : () async {
                    final url = urlCtrl.text.trim();
                    if (url.isEmpty) return;
                    try {
                      await ApiService().put('/courses/${widget.courseId}', {'thumbnail': url, 'thumbnail_url': url});
                      if (mounted) Navigator.pop(context);
                      _loadCourse();
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thumbnail updated!'), backgroundColor: Colors.green));
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('Save Thumbnail', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCourseTypeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Course Type', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _courseTypeOption(ctx, 'self-paced', Icons.self_improvement_rounded, const Color(0xFF10B981),
              'Self-paced',
              'Students unlock the next module immediately when they mark current module as complete.'),
          const SizedBox(height: 12),
          _courseTypeOption(ctx, 'pragmatic', Icons.timeline_rounded, const Color(0xFF6366F1),
              'Pragmatic (Timeline)',
              'Modules unlock strictly on the scheduled dates regardless of completion. Instructor controls the timeline.'),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  Widget _courseTypeOption(BuildContext ctx, String type, IconData icon, Color color, String label, String desc) {
    final selected = _courseType == type;
    return GestureDetector(
      onTap: () { Navigator.pop(ctx); _updateCourseType(type); },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : const Color(0xFFE2E8F0), width: selected ? 2 : 1),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: selected ? color : const Color(0xFF0F172A))),
            const SizedBox(height: 3),
            Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ])),
          if (selected) Icon(Icons.check_circle_rounded, color: color, size: 20),
        ]),
      ),
    );
  }

  void _showModuleCompletions(Map<String, dynamic> module) {
    final completions = List<Map<String, dynamic>>.from(module['completions'] ?? []);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text('Completions — ${module['title'] ?? 'Module'}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
        ]),
        content: SizedBox(
          width: 400,
          child: completions.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No students have completed this module yet.', style: TextStyle(color: Color(0xFF94A3B8))),
                )
              : SizedBox(
                  height: 300,
                  child: ListView.separated(
                    itemCount: completions.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final c = completions[i];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(radius: 16, backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1), child: const Icon(Icons.person_rounded, size: 18, color: Color(0xFF10B981))),
                        title: Text(c['studentName']?.toString() ?? 'Student', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: Text(c['completedAt']?.toString() ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                          child: const Text('✓ Done', style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
                        ),
                      );
                    },
                  ),
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _startLiveSession(Map<String, dynamic> lesson) async {
    final meetingLink = lesson['meetingLink']?.toString() ?? '';
    final meetingId = lesson['meetingId']?.toString() ?? '';
    final meetingPassword = lesson['meetingPassword']?.toString() ?? '';
    // Auto-detect platform from the link — don't show "ZOOM" when a Google Meet link is set
    String platform = lesson['platform']?.toString() ?? 'zoom';
    if (meetingLink.contains('meet.google.com')) platform = 'Google Meet';
    else if (meetingLink.contains('zoom.us')) platform = 'Zoom';
    else if (meetingLink.contains('teams.microsoft.com')) platform = 'Microsoft Teams';

    if (meetingLink.isEmpty) {
      // No external link → launch iCare native live session
      final sessionId = lesson['_id']?.toString() ?? '';
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => LmsLiveSessionScreen(
          sessionId: sessionId,
          courseId: widget.courseId,
          sessionTitle: lesson['title']?.toString() ?? 'Live Session',
          isInstructor: true,
          lessonId: lesson['_id']?.toString(),
        ),
      ));
      return;
    }

    // Show details dialog before opening
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.live_tv_rounded, color: Colors.red),
          SizedBox(width: 10),
          Text('Start Live Session', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Share these details with students:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          const SizedBox(height: 12),
          _infoTile('Platform', platform),
          if (meetingId.isNotEmpty) _infoTile('Meeting ID', meetingId),
          if (meetingPassword.isNotEmpty) _infoTile('Password', meetingPassword),
          _infoTile('Link', meetingLink, overflow: true),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse(meetingLink);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Open & Start'),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value, {bool overflow = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$label: ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
        Expanded(child: Text(value,
          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
          overflow: overflow ? TextOverflow.ellipsis : null,
        )),
      ]),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final modules = List<Map<String, dynamic>>.from(_course?['modules'] ?? []);

    if (widget.embedded) {
      return _buildEmbeddedBody(modules);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Course Settings',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            Text(
              _course?['title'] ?? 'Untitled Course',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      // Course Settings is settings-only — modules, Go Live, and Add Module
      // all live in the Course Content tab (_buildEmbeddedBody) to avoid
      // duplicating the modules list in two places.
      body: _buildSettingsBody(),
    );
  }

  Widget _buildSettingsBody() {
    final width = MediaQuery.of(context).size.width;
    final crossCount = width > 1000 ? 3 : (width > 650 ? 2 : 1);
    return RefreshIndicator(
      onRefresh: _loadCourse,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: GridView.count(
          crossAxisCount: crossCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.7,
          children: [
            _buildSettingsCard(
              icon: Icons.image_outlined,
              color: const Color(0xFF6366F1),
              title: 'Thumbnail',
              rows: const ['Change the course cover image'],
              onTap: _showEditThumbnail,
            ),
            _buildSettingsCard(
              icon: Icons.workspace_premium_rounded,
              color: const Color(0xFFD4AF37),
              title: 'Certificate Template',
              rows: ['Template: ${_certificateTemplate.name}'],
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => CertificateTemplateSelectorScreen(
                    courseTitle: _course?['title'] ?? 'Course',
                    instructorName: _course?['instructor']?['name'] ?? 'Instructor',
                    courseId: widget.courseId,
                    currentTemplate: _certificateTemplate,
                    certificateReleased: _course?['certificateReleased'] == true,
                    onSelect: (t) => setState(() => _certificateTemplate = t),
                  ),
                )).then((_) => _loadCourse());
              },
            ),
            _buildSettingsCard(
              icon: _courseType == 'pragmatic' ? Icons.timeline_rounded : Icons.self_improvement_rounded,
              color: _courseType == 'pragmatic' ? const Color(0xFF6366F1) : const Color(0xFF10B981),
              title: 'Course Type',
              rows: [_courseType == 'pragmatic' ? 'Pragmatic (Timeline)' : 'Self-paced'],
              onTap: _showCourseTypeDialog,
            ),
            _buildSettingsCard(
              icon: _isFreeDisplay ? Icons.money_off_rounded : Icons.sell_outlined,
              color: const Color(0xFFF59E0B),
              title: 'Pricing Display',
              rows: [_isFreeDisplay ? 'Showing as: Free' : 'Showing real price'],
              onTap: () => _toggleFreeDisplay(!_isFreeDisplay),
            ),
            _buildSettingsCard(
              icon: Icons.people_outline_rounded,
              color: const Color(0xFF0EA5E9),
              title: 'Students & Progress',
              rows: const ['View enrolled students and their progress'],
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => InstructorStudentProgressScreen(
                  courseId: widget.courseId,
                  courseTitle: _course?['title']?.toString() ?? 'Course',
                ),
              )),
            ),
            _buildSettingsCard(
              icon: Icons.analytics_outlined,
              color: const Color(0xFF8B5CF6),
              title: 'Analytics',
              rows: const ['Engagement, completion, and quiz stats'],
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => InstructorCourseAnalyticsScreen(
                  courseId: widget.courseId,
                  courseTitle: _course?['title']?.toString() ?? 'Course',
                ),
              )),
            ),
            _buildSettingsCard(
              icon: Icons.confirmation_number_outlined,
              color: const Color(0xFFEF4444),
              title: 'Discount Vouchers',
              rows: const ['Create and manage enrollment vouchers'],
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const InstructorVoucherScreen(),
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required IconData icon,
    required Color color,
    required String title,
    required List<String> rows,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A))),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 18),
              ],
            ),
            const SizedBox(height: 10),
            ...rows.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(r, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildEmbeddedBody(List<Map<String, dynamic>> modules) {
    final hasContent = modules.isNotEmpty || _assignments.isNotEmpty ||
        _quizzes.isNotEmpty || _liveSessions.isNotEmpty;

    final items = <Widget>[];

    if (!hasContent) {
      items.add(_buildEmptyState());
    } else {
      // Modules
      for (int i = 0; i < modules.length; i++) {
        items.add(_buildModuleCard(modules[i], i));
      }

      // Live Sessions not linked to any module — kept flat for backward
      // compatibility with sessions created before module-linking existed.
      final unlinkedSessions = _liveSessions.where((s) {
        final linked = (s as Map)['linkedModuleId']?.toString();
        return linked == null || linked.isEmpty || !modules.any((m) => m['_id']?.toString() == linked);
      }).toList();
      if (unlinkedSessions.isNotEmpty) {
        items.add(_buildSectionHeader(Icons.live_tv_rounded, 'Live Sessions', Colors.red));
        for (final s in unlinkedSessions) {
          items.add(_buildStandaloneSessionTile(s));
        }
      }

      // Assignments section
      if (_assignments.isNotEmpty) {
        items.add(_buildSectionHeader(Icons.assignment_rounded, 'Assignments', const Color(0xFF6366F1)));
        for (final a in _assignments) {
          items.add(_buildStandaloneAssignmentTile(a));
        }
      }

      // Quizzes section
      if (_quizzes.isNotEmpty) {
        items.add(_buildSectionHeader(Icons.quiz_rounded, 'Quizzes', const Color(0xFFF59E0B)));
        for (final q in _quizzes) {
          items.add(_buildStandaloneQuizTile(q));
        }
      }
    }

    return Column(
      children: [
        _buildContentHeader(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadCourse,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: items,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContentHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _course?['title']?.toString() ?? 'Course Content',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _startLiveClass,
            icon: const Icon(Icons.live_tv_rounded, size: 16),
            label: const Text('Go Live', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.primaryColor),
            tooltip: 'Add Module',
            onPressed: _addModule,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: color.withValues(alpha: 0.3))),
      ]),
    );
  }

  String _fmtDate(String raw) {
    try {
      // Parse as UTC if it ends with Z, otherwise treat as local
      DateTime dt;
      if (raw.endsWith('Z') || raw.contains('+')) {
        dt = DateTime.parse(raw).toLocal();
      } else {
        dt = DateTime.parse(raw);
      }
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour < 12 ? 'AM' : 'PM';
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}  $h:$m $ampm';
    } catch (_) { return raw; }
  }

  Widget _buildStandaloneSessionTile(dynamic session) {
    final title = session['title']?.toString() ?? 'Live Session';
    final status = session['status']?.toString() ?? 'scheduled';
    final scheduledAt = session['scheduledAt']?.toString() ?? session['liveSessionDateTime']?.toString() ?? '';
    final isLive = status == 'live';
    final isEnded = status == 'ended' || status == 'completed';
    final id = session['_id']?.toString() ?? '';
    final driveUrl = session['driveBackupUrl']?.toString() ?? '';
    // A session scheduled for a specific future time can't be started early —
    // this only controls the button's enabled state; the backend (set-live)
    // is the real gate since the client's clock/lock state can't be trusted.
    DateTime? scheduledDt;
    if (scheduledAt.isNotEmpty) {
      try { scheduledDt = DateTime.parse(scheduledAt); } catch (_) {}
    }
    final isLockedByTime = !isLive && !isEnded && scheduledDt != null && scheduledDt.isAfter(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isEnded ? const Color(0xFFF1F5F9) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isEnded ? const Color(0xFF94A3B8).withValues(alpha: 0.3) : const Color(0xFFFB923C).withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isEnded ? const Color(0xFF64748B) : Colors.red).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            isEnded ? Icons.check_circle_outline_rounded : Icons.live_tv_rounded,
            size: 20, color: isEnded ? const Color(0xFF64748B) : Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
          if (scheduledAt.isNotEmpty)
            Text(_fmtDate(scheduledAt), style: TextStyle(fontSize: 12, color: isEnded ? const Color(0xFF64748B) : const Color(0xFFF59E0B))),
        ])),
        if (isEnded)
          GestureDetector(
            onTap: driveUrl.isEmpty ? null : () async {
              final uri = Uri.parse(driveUrl);
              if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: driveUrl.isEmpty ? Colors.grey[200] : const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                driveUrl.isEmpty ? 'Ended' : 'Recording',
                style: TextStyle(
                  color: driveUrl.isEmpty ? Colors.black45 : Colors.white,
                  fontSize: 12, fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
        else
          GestureDetector(
            onTap: isLockedByTime ? () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('This session unlocks at ${_fmtDate(scheduledAt)}'),
                backgroundColor: Colors.orange,
              ));
            } : () => _startLiveSession(session),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isLockedByTime ? Colors.grey[400] : (isLive ? Colors.red : AppColors.primaryColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (isLockedByTime) const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.lock_outline_rounded, size: 12, color: Colors.white),
                ),
                Text(isLockedByTime ? 'Locked' : (isLive ? 'Join Live' : 'Start'),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () async {
            final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('Delete Session'),
              content: Text('Delete "$title"? This cannot be undone.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Delete', style: TextStyle(color: Colors.white))),
              ],
            ));
            if (confirm == true && id.isNotEmpty) {
              try {
                await _lmsService.deleteSession(id);
                _loadCourse();
              } catch (_) {}
            }
          },
          child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
        ),
      ]),
    );
  }

  Widget _buildStandaloneAssignmentTile(dynamic assignment) {
    final title = assignment['title']?.toString() ?? 'Assignment';
    final dueDate = assignment['dueDate']?.toString() ?? '';
    final marks = assignment['totalMarks']?.toString() ?? '100';
    final isPublished = assignment['isPublished'] == true;
    final id = assignment['_id']?.toString() ?? '';

    return GestureDetector(
      onTap: id.isEmpty ? null : () => showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => _AssignmentPreviewDialog(assignmentId: id),
      ),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
          child: const Icon(Icons.assignment_rounded, size: 20, color: Color(0xFF6366F1)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
          Text('$marks marks${dueDate.isNotEmpty ? ' · Due: ${_fmtDate(dueDate)}' : ''}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: isPublished ? const Color(0xFF10B981).withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(isPublished ? 'Published' : 'Draft',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isPublished ? const Color(0xFF10B981) : Colors.grey)),
        ),
        GestureDetector(
          onTap: () async {
            final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('Delete Assignment'),
              content: Text('Delete "$title"?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Delete', style: TextStyle(color: Colors.white))),
              ],
            ));
            if (confirm == true && id.isNotEmpty) {
              try {
                await _lmsService.deleteAssignment(id);
                _loadCourse();
              } catch (_) {}
            }
          },
          child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
        ),
      ]),
      ),
    );
  }

  Widget _buildStandaloneQuizTile(dynamic quiz) {
    final title = quiz['title']?.toString() ?? 'Quiz';
    final timeLimit = quiz['timeLimit']?.toString() ?? '';
    final passingScore = quiz['passingScore']?.toString() ?? '';
    final isPublished = quiz['isPublished'] == true;
    final id = quiz['_id']?.toString() ?? '';

    return GestureDetector(
      onTap: id.isNotEmpty ? () => showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => _QuizPreviewDialog(quizId: id),
      ) : null,
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
          child: const Icon(Icons.quiz_rounded, size: 20, color: Color(0xFFF59E0B)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
          Text('${timeLimit.isNotEmpty ? '$timeLimit min' : ''}${passingScore.isNotEmpty ? ' · Pass: $passingScore%' : ''}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: isPublished ? const Color(0xFF10B981).withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(isPublished ? 'Published' : 'Draft',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isPublished ? const Color(0xFF10B981) : Colors.grey)),
        ),
        if (id.isNotEmpty)
          IconButton(
            tooltip: 'View Attempts / Review',
            icon: const Icon(Icons.fact_check_outlined, color: Color(0xFF6366F1), size: 20),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => InstructorQuizAttemptsScreen(quizId: id, quizTitle: title),
              ));
            },
          ),
        GestureDetector(
          onTap: () async {
            final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('Delete Quiz'),
              content: Text('Delete "$title"?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Delete', style: TextStyle(color: Colors.white))),
              ],
            ));
            if (confirm == true && id.isNotEmpty) {
              try {
                await _lmsService.deleteQuiz(id);
                _loadCourse();
              } catch (_) {}
            }
          },
          child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
        ),
      ]),
    ));
  }

  Widget _buildModuleCard(Map<String, dynamic> module, int index) {
    final lessons = List<Map<String, dynamic>>.from(module['lessons'] ?? []);
    final moduleId = module['_id']?.toString();
    final linkedSessions = _liveSessions.where((s) => (s as Map)['linkedModuleId']?.toString() == moduleId).toList();
    final title = module['title'] ?? 'Module ${index + 1}';
    final description = module['description'] ?? '';
    final completions = List<Map<String, dynamic>>.from(module['completions'] ?? []);
    final completionCount = completions.length;
    final unlockDays = module['unlockAfterDays'] as int? ?? 0;
    final startDateRaw = _course?['startDate'];
    String? unlockLabel;
    if (_courseType == 'pragmatic' && startDateRaw != null) {
      try {
        final start = DateTime.parse(startDateRaw.toString());
        final unlockDate = start.add(Duration(days: unlockDays));
        unlockLabel = 'Unlocks ${unlockDate.day}/${unlockDate.month}/${unlockDate.year}';
      } catch (_) {}
    } else if (_courseType == 'pragmatic' && unlockDays > 0) {
      unlockLabel = 'Unlocks Day $unlockDays';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: CircleAvatar(
            backgroundColor: AppColors.primaryColor,
            child: Text(
              '${index + 1}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (description.isNotEmpty)
                Text(description, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)), maxLines: 2, overflow: TextOverflow.ellipsis),
              if (unlockLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.lock_clock_rounded, size: 12, color: Color(0xFF6366F1)),
                    const SizedBox(width: 4),
                    Text(unlockLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6366F1))),
                  ]),
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${lessons.length} lessons',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Completion count chip
              GestureDetector(
                onTap: () => _showModuleCompletions(module),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '✓ $completionCount',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              PopupMenuButton(
                icon: const Icon(Icons.more_vert),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: const Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 12),
                        Text('Edit'),
                      ],
                    ),
                    onTap: () => Future.delayed(
                      const Duration(milliseconds: 100),
                      () => _editModule(index),
                    ),
                  ),
                  PopupMenuItem(
                    child: const Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                    onTap: () => Future.delayed(
                      const Duration(milliseconds: 100),
                      () => _deleteModule(index),
                    ),
                  ),
                ],
              ),
            ],
          ),
          children: [
            if (lessons.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'No lessons yet.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              )
            else
              ...lessons.asMap().entries.map((entry) {
                final lessonIndex = entry.key;
                final lesson = entry.value;
                return _buildLessonItem(lesson, lessonIndex);
              }),
            if (linkedSessions.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(top: 4, bottom: 6),
                child: Text('Live Sessions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
              ),
              ...linkedSessions.map((s) => _buildStandaloneSessionTile(s)),
            ],
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton.icon(
                onPressed: () => _editModule(index),
                icon: const Icon(Icons.add, size: 18),
                label: Text('Add Lesson ${lessons.length + 1}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryColor,
                  side: BorderSide(color: AppColors.primaryColor.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  minimumSize: const Size(double.infinity, 0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonItem(Map<String, dynamic> lesson, int index) {
    final title = lesson['title'] ?? 'Lesson ${index + 1}';
    final duration = lesson['duration'] ?? 0;
    final hasVideo = lesson['videoUrl'] != null && lesson['videoUrl'].toString().isNotEmpty;
    final lessonType = lesson['type']?.toString() ?? 'content';
    final isLiveSession = lessonType == 'live';
    final isAssignment = lessonType == 'assignment';
    final isQuiz = lessonType == 'quiz';
    final hasRecording = lesson['recordingUrl'] != null && lesson['recordingUrl'].toString().isNotEmpty;
    final sessionStatus = lesson['status']?.toString() ?? 'scheduled';

    // Determine icon/color by type
    IconData typeIcon;
    Color typeColor;
    Color tileBg;
    Color tileBorder;
    if (isLiveSession) {
      typeIcon = hasRecording ? Icons.play_circle_rounded : Icons.live_tv_rounded;
      typeColor = hasRecording ? const Color(0xFF10B981) : Colors.red;
      tileBg = const Color(0xFFFFF7ED);
      tileBorder = const Color(0xFFFB923C).withValues(alpha: 0.4);
    } else if (isAssignment) {
      typeIcon = Icons.assignment_rounded;
      typeColor = const Color(0xFF6366F1);
      tileBg = const Color(0xFFF5F3FF);
      tileBorder = const Color(0xFF6366F1).withValues(alpha: 0.3);
    } else if (isQuiz) {
      typeIcon = Icons.quiz_rounded;
      typeColor = const Color(0xFFF59E0B);
      tileBg = const Color(0xFFFFFBEB);
      tileBorder = const Color(0xFFF59E0B).withValues(alpha: 0.3);
    } else {
      typeIcon = hasVideo ? Icons.play_circle_outline : Icons.article_outlined;
      typeColor = hasVideo ? const Color(0xFF10B981) : const Color(0xFF94A3B8);
      tileBg = const Color(0xFFF8FAFC);
      tileBorder = const Color(0xFFE2E8F0);
    }

    return GestureDetector(
      onTap: isLiveSession ? null : () => _showLessonDetail(lesson),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tileBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(typeIcon, size: 20, color: typeColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                  if (isLiveSession && !hasRecording) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    child: const Text('LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.red)),
                  ),
                  if (isAssignment) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    child: const Text('ASSIGNMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6366F1))),
                  ),
                  if (isQuiz) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    child: const Text('QUIZ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFF59E0B))),
                  ),
                  if (hasRecording) Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    child: const Text('RECORDED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF10B981))),
                  ),
                ]),
                Row(children: [
                  if (duration > 0) Text('$duration min', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  if (isLiveSession && lesson['scheduledAt'] != null) ...[
                    if (duration > 0) const Text(' · ', style: TextStyle(color: Color(0xFF94A3B8))),
                    Text(_fmtDate(lesson['scheduledAt'].toString()), style: const TextStyle(fontSize: 12, color: Color(0xFFF59E0B))),
                  ],
                ]),
              ],
            ),
          ),
          // Live session actions
          if (isLiveSession) Row(mainAxisSize: MainAxisSize.min, children: [
            if (hasRecording)
              // Recording available — play it
              GestureDetector(
                onTap: () => _openRecording(lesson),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(8)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text('Recording', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ),
              )
            else if (sessionStatus == 'ended' || sessionStatus == 'completed')
              // Ended but no recording
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(8)),
                child: const Text('No Recording', style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w600)),
              )
            else
              // Scheduled / upcoming — Start button
              GestureDetector(
                onTap: () => _startLiveSession(lesson),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text('Start', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            const SizedBox(width: 6),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF94A3B8)),
              onSelected: (val) async {
                if (val == 'cancel') {
                  final sessionId = lesson['sessionId']?.toString() ?? lesson['_id']?.toString() ?? '';
                  if (sessionId.isEmpty) return;
                  final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    title: const Text('Cancel Session'),
                    content: Text('Cancel "$title"?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                      ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Cancel Session', style: TextStyle(color: Colors.white))),
                    ],
                  ));
                  if (!mounted) return;
                  if (confirm == true) {
                    try { await _lmsService.deleteSession(sessionId); _loadCourse(); } catch (_) {}
                  }
                }
                if (val == 'delete_rec') {
                  final sessionId = lesson['sessionId']?.toString() ?? '';
                  if (sessionId.isEmpty) return;
                  final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    title: const Text('Delete Recording'),
                    content: const Text('Remove this recording? This cannot be undone.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Delete', style: TextStyle(color: Colors.white))),
                    ],
                  ));
                  if (!mounted) return;
                  if (confirm == true) {
                    try {
                      await _lmsService.updateSession(sessionId, {'recordingUrl': ''});
                      _loadCourse();
                    } catch (_) {}
                  }
                }
              },
              itemBuilder: (_) => [
                if (hasRecording) const PopupMenuItem(value: 'delete_rec', child: Row(children: [
                  Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                  SizedBox(width: 10),
                  Text('Delete Recording', style: TextStyle(color: Colors.red)),
                ])),
                const PopupMenuItem(value: 'cancel', child: Row(children: [
                  Icon(Icons.cancel_outlined, size: 18, color: Color(0xFFF59E0B)),
                  SizedBox(width: 10),
                  Text('Cancel Session'),
                ])),
              ],
            ),
          ]),
        ],
      ),
    ));
  }

  void _showLessonDetail(Map<String, dynamic> lesson) {
    final ltype = lesson['type']?.toString() ?? 'content';
    if (ltype == 'assignment') {
      final assignmentId = lesson['_id']?.toString();
      if (assignmentId != null) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) => _AssignmentPreviewDialog(assignmentId: assignmentId),
        );
        return;
      }
    }
    if (ltype == 'quiz') {
      final quizId = lesson['_id']?.toString();
      if (quizId != null) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) => _QuizPreviewDialog(quizId: quizId),
        );
        return;
      }
    }
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _LessonPreviewScreen(lesson: lesson),
    );
  }

  void _openRecording(dynamic lesson) {
    final url = lesson['recordingUrl']?.toString() ?? '';
    if (url.isEmpty) return;
    final title = lesson['title']?.toString() ?? 'Recording';
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _RecordingDialog(title: title, url: url),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'No modules yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your first module to organize course content',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addModule,
            icon: const Icon(Icons.add),
            label: const Text('Add Module'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// Module Dialog
class _ModuleDialog extends StatefulWidget {
  final Map<String, dynamic>? module;
  final String courseId;

  const _ModuleDialog({this.module, required this.courseId});

  @override
  State<_ModuleDialog> createState() => _ModuleDialogState();
}

class _ModuleDialogState extends State<_ModuleDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _unlockDaysController = TextEditingController();
  final List<Map<String, dynamic>> _lessons = [];

  @override
  void initState() {
    super.initState();
    if (widget.module != null) {
      _titleController.text = widget.module!['title'] ?? '';
      _descriptionController.text = widget.module!['description'] ?? '';
      final days = widget.module!['unlockAfterDays'];
      _unlockDaysController.text = (days != null && days != 0) ? days.toString() : '';
      if (widget.module!['lessons'] != null) {
        _lessons.addAll(List<Map<String, dynamic>>.from(widget.module!['lessons']));
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _unlockDaysController.dispose();
    super.dispose();
  }

  void _addLesson({String defaultType = 'content'}) {
    if (defaultType == 'assignment') {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => InstructorCreateAssignmentScreen(courseId: widget.courseId),
      )).then((result) {
        if (result is Map<String, dynamic>) {
          setState(() => _lessons.add({...result, 'type': 'assignment'}));
        }
      });
      return;
    }
    if (defaultType == 'quiz') {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => InstructorCreateQuizScreen(courseId: widget.courseId),
      )).then((result) {
        if (result is Map<String, dynamic>) {
          setState(() => _lessons.add({...result, 'type': 'quiz'}));
        }
      });
      return;
    }
    showDialog(
      context: context,
      builder: (context) => _LessonDialog(
        defaultType: defaultType,
        onSave: (lesson) {
          setState(() => _lessons.add(lesson));
        },
      ),
    );
  }

  void _editLesson(int index) {
    final lesson = _lessons[index];
    final ltype = lesson['type']?.toString() ?? 'content';
    if (ltype == 'assignment') {
      final assignmentId = lesson['_id']?.toString();
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => InstructorCreateAssignmentScreen(courseId: '', assignmentId: assignmentId),
      ));
      return;
    }
    if (ltype == 'quiz') {
      final quizId = lesson['_id']?.toString();
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => InstructorCreateQuizScreen(courseId: '', quizId: quizId),
      ));
      return;
    }
    showDialog(
      context: context,
      builder: (context) => _LessonDialog(
        lesson: lesson,
        onSave: (lesson) {
          setState(() => _lessons[index] = lesson);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.module != null ? 'Edit Module' : 'Add Module'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Module Title *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _unlockDaysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Unlock After Days (Pragmatic mode)',
                  hintText: 'e.g. 7 — leave blank to unlock immediately',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_clock_rounded),
                  helperText: 'Day 0 from course start date when this module unlocks',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Content (${_lessons.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Wrap(spacing: 6, children: [
                    TextButton.icon(
                      onPressed: () => _addLesson(defaultType: 'content'),
                      icon: const Icon(Icons.article_outlined, size: 16),
                      label: const Text('Lesson', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                    TextButton.icon(
                      onPressed: () => _addLesson(defaultType: 'live'),
                      icon: const Icon(Icons.live_tv_rounded, size: 16, color: Colors.red),
                      label: const Text('Live', style: TextStyle(fontSize: 12, color: Colors.red)),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                    TextButton.icon(
                      onPressed: () => _addLesson(defaultType: 'assignment'),
                      icon: const Icon(Icons.assignment_rounded, size: 16, color: Color(0xFF6366F1)),
                      label: const Text('Assignment', style: TextStyle(fontSize: 12, color: Color(0xFF6366F1))),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                    TextButton.icon(
                      onPressed: () => _addLesson(defaultType: 'quiz'),
                      icon: const Icon(Icons.quiz_rounded, size: 16, color: Color(0xFFF59E0B)),
                      label: const Text('Quiz', style: TextStyle(fontSize: 12, color: Color(0xFFF59E0B))),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                  ]),
                ],
              ),
              const SizedBox(height: 8),
              if (_lessons.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No content yet', style: TextStyle(color: Color(0xFF94A3B8))),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _lessons.length,
                  itemBuilder: (context, index) {
                    final lesson = _lessons[index];
                    final ltype = lesson['type']?.toString() ?? 'content';
                    final typeIcon = ltype == 'live'
                        ? Icons.live_tv_rounded
                        : ltype == 'assignment'
                            ? Icons.assignment_rounded
                            : ltype == 'quiz'
                                ? Icons.quiz_rounded
                                : Icons.play_circle_outline;
                    final typeColor = ltype == 'live'
                        ? Colors.red
                        : ltype == 'assignment'
                            ? const Color(0xFF6366F1)
                            : ltype == 'quiz'
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF10B981);
                    return ListTile(
                      dense: true,
                      leading: Icon(typeIcon, size: 20, color: typeColor),
                      title: Text(lesson['title'] ?? 'Item ${index + 1}'),
                      subtitle: Text(ltype == 'live' ? 'Live Session' : ltype == 'assignment' ? 'Assignment' : ltype == 'quiz' ? 'Quiz' : '${lesson['duration'] ?? 0} min'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => _editLesson(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                            onPressed: () => setState(() => _lessons.removeAt(index)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_titleController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Module title is required')),
              );
              return;
            }

            Navigator.pop(context, {
              'title': _titleController.text,
              'description': _descriptionController.text,
              'lessons': _lessons,
              'order': widget.module?['order'] ?? 0,
              'unlockAfterDays': int.tryParse(_unlockDaysController.text.trim()) ?? 0,
            });
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// Lesson Dialog
class _LessonDialog extends StatefulWidget {
  final Map<String, dynamic>? lesson;
  final Function(Map<String, dynamic>) onSave;
  final String defaultType;

  const _LessonDialog({this.lesson, required this.onSave, this.defaultType = 'content'});

  @override
  State<_LessonDialog> createState() => _LessonDialogState();
}

class _LessonDialogState extends State<_LessonDialog> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _videoUrlController = TextEditingController();
  final _driveLinkController = TextEditingController();
  final _durationController = TextEditingController();
  final _unlockDaysController = TextEditingController();
  final _meetingLinkController = TextEditingController();
  bool _uploadingVideo = false;
  double _uploadVideoProgress = 0;
  String? _uploadedVideoUrl;
  bool _uploadingDocument = false;
  double _uploadDocProgress = 0;
  String? _documentUrl;
  String? _documentName;
  String _lessonType = 'content'; // 'content' or 'live'
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;

  // YouTube embed preview: extract video ID from URL
  String? _youtubeId(String url) {
    final patterns = [
      RegExp(r'(?:youtube\.com/watch\?v=|youtu\.be/)([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]{11})'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(url);
      if (m != null) return m.group(1);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.lesson != null) {
      _titleController.text = widget.lesson!['title'] ?? '';
      _contentController.text = widget.lesson!['content'] ?? '';
      _videoUrlController.text = widget.lesson!['videoUrl'] ?? '';
      _driveLinkController.text = widget.lesson!['driveLink'] ?? '';
      _durationController.text = (widget.lesson!['duration'] ?? 15).toString();
      _uploadedVideoUrl = widget.lesson!['videoUrl'];
      _lessonType = widget.lesson!['type']?.toString() ?? 'content';
      _documentUrl = widget.lesson!['documentUrl']?.toString();
      _documentName = widget.lesson!['documentName']?.toString();
      _unlockDaysController.text = (widget.lesson!['unlockAfterDays'] ?? 0).toString();
      _meetingLinkController.text = widget.lesson!['meetingLink']?.toString() ?? '';
    } else {
      _lessonType = widget.defaultType;
      _durationController.text = '15';
      _unlockDaysController.text = '0';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _videoUrlController.dispose();
    _driveLinkController.dispose();
    _durationController.dispose();
    _unlockDaysController.dispose();
    _meetingLinkController.dispose();
    super.dispose();
  }

  Widget _typeChip(String type, IconData icon, String label, Color color) {
    final selected = _lessonType == type;
    return GestureDetector(
      onTap: () => setState(() => _lessonType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? color : const Color(0xFFE2E8F0)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: selected ? Colors.white : const Color(0xFF64748B)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : const Color(0xFF64748B))),
        ]),
      ),
    );
  }

  Future<void> _uploadVideo() async {
    try {
      // withReadStream avoids loading the entire video into RAM — essential for
      // large files (30-min recordings can be 1 GB+) where fromBytes() OOMs.
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        withData: false,
        withReadStream: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.readStream == null) return;

      setState(() { _uploadingVideo = true; _uploadVideoProgress = 0; });
      // Step 1: Get signed upload params from backend
      final signRes = await ApiService().get('/upload/sign?folder=icare/lessons&resource_type=video');
      final signature = signRes.data['signature']?.toString() ?? '';
      final timestamp = signRes.data['timestamp']?.toString() ?? '';
      final apiKey = signRes.data['api_key']?.toString() ?? '';
      final cloudName = signRes.data['cloud_name']?.toString() ?? 'dzlcnyxgb';
      final folder = signRes.data['folder']?.toString() ?? 'icare/lessons';

      if (signature.isEmpty) throw Exception('Could not get upload signature from server');

      // Step 2: Stream directly to Cloudinary (bypasses Vercel 4.5MB limit and
      // avoids loading the whole video into browser memory)
      final dio2 = Dio();
      final formData = FormData.fromMap({
        'file': MultipartFile.fromStream(
          () => file.readStream!,
          file.size,
          filename: file.name,
        ),
        'signature': signature,
        'timestamp': timestamp,
        'api_key': apiKey,
        'folder': folder,
      });
      final response = await dio2.post(
        'https://api.cloudinary.com/v1_1/$cloudName/video/upload',
        data: formData,
        options: Options(validateStatus: (s) => s != null && s < 600),
        onSendProgress: (sent, total) {
          if (total > 0 && mounted) setState(() => _uploadVideoProgress = sent / total);
        },
      );
      if (response.statusCode == 200 && response.data['secure_url'] != null) {
        final url = response.data['secure_url'] as String;
        setState(() {
          _uploadedVideoUrl = url;
          _videoUrlController.text = url;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Video uploaded successfully!'), backgroundColor: Colors.green),
          );
        }
      } else {
        final errMsg = response.data is Map
            ? (response.data['error']?['message'] ?? response.data['message'] ?? 'Upload failed (${response.statusCode})')
            : 'Upload failed (${response.statusCode})';
        throw Exception(errMsg);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
        );
      }
    } finally {
      if (mounted) setState(() { _uploadingVideo = false; _uploadVideoProgress = 0; });
    }
  }

  Future<void> _uploadDocument() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'txt'],
        allowMultiple: false,
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.first;
      if (file.bytes == null) return;

      setState(() { _uploadingDocument = true; _uploadDocProgress = 0; });

      // Step 1: get Cloudinary signature for a raw (document) upload
      final signRes = await ApiService().get('/upload/sign?resource_type=raw&folder=icare/lesson-docs');
      final signature = signRes.data['signature']?.toString() ?? '';
      final timestamp  = signRes.data['timestamp']?.toString() ?? '';
      final apiKey     = signRes.data['api_key']?.toString() ?? '';
      final cloudName  = signRes.data['cloud_name']?.toString() ?? 'dzlcnyxgb';
      final folder     = signRes.data['folder']?.toString() ?? 'icare/lesson-docs';
      if (signature.isEmpty) throw Exception('Could not get upload signature from server');

      // Step 2: upload directly to Cloudinary raw endpoint — no CORS issues,
      // no Vercel size limit, no private-store errors
      final dio2 = Dio();
      final res = await dio2.post(
        'https://api.cloudinary.com/v1_1/$cloudName/raw/upload',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(file.bytes!, filename: file.name),
          'signature': signature,
          'timestamp': timestamp,
          'api_key': apiKey,
          'folder': folder,
        }),
        options: Options(validateStatus: (s) => s != null && s < 600),
        onSendProgress: (sent, total) {
          if (total > 0 && mounted) setState(() => _uploadDocProgress = sent / total);
        },
      );

      if (res.statusCode != 200 || res.data['secure_url'] == null) {
        final msg = res.data is Map
            ? (res.data['error']?['message'] ?? res.data['message'] ?? 'Upload failed (${res.statusCode})')
            : 'Upload failed (${res.statusCode})';
        throw Exception(msg);
      }

      final docUrl = res.data['secure_url'] as String;

      setState(() {
        _documentUrl = docUrl;
        _documentName = file.name;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Document uploaded successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Document upload failed: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
        );
      }
    } finally {
      if (mounted) setState(() { _uploadingDocument = false; _uploadDocProgress = 0; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUrl = _videoUrlController.text.trim();
    final ytId = currentUrl.isNotEmpty ? _youtubeId(currentUrl) : null;
    final isCloudinaryVideo = currentUrl.contains('cloudinary.com') ||
        currentUrl.contains('.mp4') ||
        currentUrl.contains('.webm');

    return AlertDialog(
      title: Text(widget.lesson != null ? 'Edit Lesson' : 'Add Lesson',
          style: const TextStyle(fontWeight: FontWeight.w700)),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Lesson Type Toggle
              Wrap(spacing: 8, runSpacing: 8, children: [
                _typeChip('content', Icons.article_outlined, 'Content', AppColors.primaryColor),
                _typeChip('live', Icons.live_tv_rounded, 'Live Session', Colors.red),
              ]),
              const SizedBox(height: 14),
              // Title
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Lesson Title *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 14),
              // Notes
              TextField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 14),
              // Live session: scheduled date/time
              if (_lessonType == 'live') ...[
                GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: _scheduledDate ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030));
                    if (d != null) {
                      final t = await showTimePicker(context: context, initialTime: _scheduledTime ?? TimeOfDay.now());
                      setState(() { _scheduledDate = d; if (t != null) _scheduledTime = t; });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: _scheduledDate != null ? Colors.red.withValues(alpha: 0.5) : const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(children: [
                      Icon(Icons.event_rounded, size: 18, color: _scheduledDate != null ? Colors.red : const Color(0xFF94A3B8)),
                      const SizedBox(width: 10),
                      Text(
                        _scheduledDate != null
                            ? 'Scheduled: ${_scheduledDate!.day}/${_scheduledDate!.month}/${_scheduledDate!.year} ${_scheduledTime?.format(context) ?? ''}'
                            : 'Set Scheduled Date & Time',
                        style: TextStyle(fontSize: 13, color: _scheduledDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(8)),
                  child: const Row(children: [
                    Icon(Icons.fiber_manual_record_rounded, color: Colors.red, size: 14),
                    SizedBox(width: 8),
                    Expanded(child: Text('Live session will be auto-recorded. Video + chat will be saved to this lesson automatically.', style: TextStyle(fontSize: 11, color: Color(0xFF92400E)))),
                  ]),
                ),
                const SizedBox(height: 14),
                // Google Meet link field
                TextField(
                  controller: _meetingLinkController,
                  decoration: const InputDecoration(
                    labelText: 'Google Meet Link (Optional)',
                    hintText: 'https://meet.google.com/xxx-xxxx-xxx',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.video_call_rounded, color: Color(0xFF1A73E8)),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 6),
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text(
                    'Students can click this link to join the Google Meet from the classwork tab.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              // ── Video Section (Content only) ────────────────────
              if (_lessonType == 'content') ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.videocam_rounded,
                            color: Color(0xFF1A73E8), size: 18),
                        const SizedBox(width: 8),
                        const Text('Video',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Color(0xFF0F172A))),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Upload video button
                    SizedBox(
                      width: double.infinity,
                      child: _uploadingVideo
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A73E8))),
                                      const SizedBox(width: 10),
                                      Text(
                                        _uploadVideoProgress > 0
                                            ? 'Uploading video... ${(_uploadVideoProgress * 100).toStringAsFixed(0)}%'
                                            : 'Preparing upload...',
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: _uploadVideoProgress > 0 ? _uploadVideoProgress : null,
                                      backgroundColor: const Color(0xFFE2E8F0),
                                      color: const Color(0xFF1A73E8),
                                      minHeight: 4,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : OutlinedButton.icon(
                              onPressed: _uploadVideo,
                              icon: const Icon(Icons.upload_rounded, size: 16),
                              label: const Text('Upload Video File',
                                  style: TextStyle(fontSize: 13)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1A73E8),
                                side: const BorderSide(color: Color(0xFF1A73E8)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                    ),

                    // Preview
                    if (ytId != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        height: 160,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                'https://img.youtube.com/vi/$ytId/hqdefault.jpg',
                                width: double.infinity,
                                height: 160,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const SizedBox(),
                              ),
                            ),
                            Container(
                              width: 48, height: 48,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF0000),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.play_arrow_rounded,
                                  color: Colors.white, size: 28),
                            ),
                            Positioned(
                              bottom: 8, left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('YouTube Preview',
                                    style: TextStyle(color: Colors.white, fontSize: 11)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isCloudinaryVideo && _uploadedVideoUrl != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF10B981), size: 18),
                            const SizedBox(width: 8),
                            const Text('Video uploaded',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF10B981))),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // ── Google Drive Link (optional, alongside the uploaded video) ──
              TextField(
                controller: _driveLinkController,
                decoration: const InputDecoration(
                  labelText: 'Google Drive Link (optional)',
                  hintText: 'https://drive.google.com/...',
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.folder_shared_rounded, size: 18, color: Color(0xFF10B981)),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 14),
              // ── Document Section (Content only) ────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.description_outlined, color: Color(0xFF6366F1), size: 18),
                        SizedBox(width: 8),
                        Text('Document (optional)',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: _uploadingDocument
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1))),
                                      const SizedBox(width: 10),
                                      Text(
                                        _uploadDocProgress > 0
                                            ? 'Uploading document... ${(_uploadDocProgress * 100).toStringAsFixed(0)}%'
                                            : 'Preparing upload...',
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: _uploadDocProgress > 0 ? _uploadDocProgress : null,
                                      backgroundColor: const Color(0xFFE2E8F0),
                                      color: const Color(0xFF6366F1),
                                      minHeight: 4,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : OutlinedButton.icon(
                              onPressed: _uploadDocument,
                              icon: const Icon(Icons.upload_file_rounded, size: 16),
                              label: Text(_documentUrl != null ? 'Replace Document' : 'Upload Document / PDF',
                                  style: const TextStyle(fontSize: 13)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF6366F1),
                                side: const BorderSide(color: Color(0xFF6366F1)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                    ),
                    if (_documentUrl != null && _documentName != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_documentName!,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                              onPressed: () => setState(() { _documentUrl = null; _documentName = null; }),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ] else const SizedBox.shrink(),
              // Duration
              TextField(
                controller: _durationController,
                decoration: const InputDecoration(
                  labelText: 'Duration (minutes)',
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.timer_outlined, size: 18),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),
              // Days to complete (Pragmatic timeline)
              TextField(
                controller: _unlockDaysController,
                decoration: const InputDecoration(
                  labelText: 'Days to Complete (Pragmatic mode)',
                  hintText: 'e.g. 2',
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.event_available_outlined, size: 18),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_titleController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Lesson title is required')),
              );
              return;
            }
            final scheduledAt = _scheduledDate != null
                ? '${_scheduledDate!.day}/${_scheduledDate!.month}/${_scheduledDate!.year}${_scheduledTime != null ? ' ${_scheduledTime!.format(context)}' : ''}'
                : null;
            widget.onSave({
              'title': _titleController.text.trim(),
              'content': _contentController.text.trim(),
              'videoUrl': _lessonType == 'content' ? _videoUrlController.text.trim() : '',
              'driveLink': _lessonType == 'content' ? _driveLinkController.text.trim() : '',
              'documentUrl': _lessonType == 'content' ? (_documentUrl ?? '') : '',
              'documentName': _lessonType == 'content' ? (_documentName ?? '') : '',
              'duration': int.tryParse(_durationController.text) ?? 15,
              'unlockAfterDays': int.tryParse(_unlockDaysController.text) ?? 0,
              'order': widget.lesson?['order'] ?? 0,
              'type': _lessonType,
              if (scheduledAt != null) 'scheduledAt': scheduledAt,
              'autoRecord': _lessonType == 'live',
              if (_lessonType == 'live' && _meetingLinkController.text.trim().isNotEmpty)
                'meetingLink': _meetingLinkController.text.trim(),
            });
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white),
          child: const Text('Save Lesson'),
        ),
      ],
    );
  }
}

// Full-screen lesson preview for instructors — replaces the old bottom sheet
// so the video takes the full viewport width and the document/content below
// is always visible without hidden-below-fold surprises.
class _LessonPreviewScreen extends StatelessWidget {
  final Map<String, dynamic> lesson;
  const _LessonPreviewScreen({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final title       = lesson['title']?.toString() ?? 'Lesson';
    final lessonType  = lesson['type']?.toString() ?? 'content';
    final videoUrl    = lesson['videoUrl']?.toString() ?? '';
    final driveLink   = lesson['driveLink']?.toString() ?? '';
    final documentUrl = lesson['documentUrl']?.toString() ?? '';
    final documentName = lesson['documentName']?.toString() ?? 'Document';
    final content     = lesson['content']?.toString() ?? '';
    final duration    = lesson['duration']?.toString() ?? '';
    final isAssignment = lessonType == 'assignment';
    final isQuiz       = lessonType == 'quiz';
    final typeColor = isAssignment ? const Color(0xFF6366F1)
        : isQuiz ? const Color(0xFFF59E0B)
        : const Color(0xFF10B981);
    final typeLabel = isAssignment ? 'Assignment' : isQuiz ? 'Quiz' : 'Content';

    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(typeLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Full-width video (black letterbox background) ──────────
              if (videoUrl.isNotEmpty)
                Container(
                  color: Colors.black,
                  width: double.infinity,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: VideoPlayerWidget(videoUrl: videoUrl),
                  ),
                ),

              // ── Meta row (duration + type chip) ───────────────────────
              if (duration.isNotEmpty && duration != '0')
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Row(children: [
                    Icon(Icons.timer_outlined, size: 16, color: typeColor),
                    const SizedBox(width: 6),
                    Text('$duration min', style: TextStyle(fontSize: 13, color: typeColor, fontWeight: FontWeight.w600)),
                  ]),
                ),

              // ── Google Drive link ────────────────────────────────────
              if (driveLink.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: InkWell(
                    onTap: () async {
                      final uri = Uri.tryParse(driveLink);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.folder_shared_rounded, color: Color(0xFF10B981), size: 22),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text('Open in Google Drive',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                          ),
                          const Icon(Icons.open_in_new_rounded, size: 18, color: Color(0xFF10B981)),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Document ──────────────────────────────────────────────
              if (documentUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Document',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                      const SizedBox(height: 8),
                      AttachmentViewer(url: documentUrl, name: documentName, label: 'Tap to preview'),
                    ],
                  ),
                ),

              // ── Lesson notes / text content ───────────────────────────
              if (content.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Lesson Notes',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(content,
                            style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A), height: 1.6)),
                      ),
                    ],
                  ),
                ),

              // ── Empty state ───────────────────────────────────────────
              if (videoUrl.isEmpty && driveLink.isEmpty && documentUrl.isEmpty && content.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('No content added yet.',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
                    ]),
                  ),
                ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// Read-only assignment preview shown when instructor taps an assignment tile.
// Edit mode is still accessible via the module's lesson edit button.
class _AssignmentPreviewDialog extends StatefulWidget {
  final String assignmentId;
  const _AssignmentPreviewDialog({required this.assignmentId});

  @override
  State<_AssignmentPreviewDialog> createState() => _AssignmentPreviewDialogState();
}

class _AssignmentPreviewDialogState extends State<_AssignmentPreviewDialog> {
  final LmsService _lmsService = LmsService();
  bool _loading = true;
  Map<String, dynamic> _a = {};

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await _lmsService.getAssignment(widget.assignmentId);
      if (mounted) setState(() { _a = Map<String, dynamic>.from(res['assignment'] ?? {}); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title       = _a['title']?.toString() ?? '';
    final description = _a['description']?.toString() ?? '';
    final instructions = _a['instructions']?.toString() ?? '';
    final totalMarks  = (_a['totalMarks'] as num?)?.toInt() ?? 100;
    final subType     = _a['submissionType']?.toString() ?? 'file';
    final attachUrl   = _a['attachmentUrl']?.toString();
    final attachName  = _a['attachmentName']?.toString() ?? 'Attachment';
    final isPublished = _a['isPublished'] == true;
    DateTime? dueDate;
    if (_a['dueDate'] != null) dueDate = DateTime.tryParse(_a['dueDate'].toString());

    String formatDate(DateTime d) {
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
      final ampm = d.hour >= 12 ? 'PM' : 'AM';
      final mm = d.minute.toString().padLeft(2, '0');
      return '${d.day} ${months[d.month - 1]} ${d.year}  $h:$mm $ampm';
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0036BC).withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF0036BC).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.assignment_rounded, color: Color(0xFF0036BC), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Assignment', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                _loading
                    ? const SizedBox(height: 16, width: 160, child: LinearProgressIndicator())
                    : Text(title.isEmpty ? '(No title)' : title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              ])),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPublished ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(isPublished ? 'Published' : 'Draft',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: isPublished ? const Color(0xFF059669) : const Color(0xFFD97706))),
              ),
              const SizedBox(width: 4),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ]),
          ),

          if (_loading)
            const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())
          else
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Stats row
                  Row(children: [
                    _statChip(Icons.star_rounded, '$totalMarks marks', const Color(0xFF7C3AED), const Color(0xFFF5F3FF)),
                    const SizedBox(width: 8),
                    _statChip(
                      subType == 'text' ? Icons.text_fields_rounded : subType == 'both' ? Icons.layers_rounded : Icons.upload_file_rounded,
                      subType == 'text' ? 'Text only' : subType == 'both' ? 'File + Text' : 'File upload',
                      const Color(0xFF0284C7), const Color(0xFFE0F2FE),
                    ),
                    if (dueDate != null) ...[
                      const SizedBox(width: 8),
                      _statChip(Icons.calendar_today_rounded, formatDate(dueDate), const Color(0xFFDC2626), const Color(0xFFFEF2F2)),
                    ],
                  ]),
                  const SizedBox(height: 16),

                  if (description.isNotEmpty) ...[
                    const Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
                      child: Text(description, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.5)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (instructions.isNotEmpty) ...[
                    const Text('Instructions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Text(instructions, style: const TextStyle(fontSize: 13, color: Color(0xFF92400E), height: 1.5)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (attachUrl != null && attachUrl.isNotEmpty) ...[
                    const Text('Attachment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    AttachmentViewer(url: attachUrl, name: attachName),
                  ],
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color fg, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: fg),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
    ]),
  );
}

// Read-only quiz preview for instructors — shows all questions with correct answers highlighted.
class _QuizPreviewDialog extends StatefulWidget {
  final String quizId;
  const _QuizPreviewDialog({required this.quizId});

  @override
  State<_QuizPreviewDialog> createState() => _QuizPreviewDialogState();
}

class _QuizPreviewDialogState extends State<_QuizPreviewDialog> {
  final LmsService _lmsService = LmsService();
  bool _loading = true;
  Map<String, dynamic> _q = {};

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await _lmsService.getQuiz(widget.quizId);
      if (mounted) setState(() { _q = Map<String, dynamic>.from(res['quiz'] ?? {}); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title       = _q['title']?.toString() ?? '';
    final description = _q['description']?.toString() ?? '';
    final timeLimit   = (_q['timeLimit'] as num?)?.toInt() ?? 0;
    final passingScore = (_q['passingScore'] as num?)?.toInt() ?? 0;
    final maxAttempts = (_q['maxAttempts'] as num?)?.toInt() ?? 3;
    final showAnswers = _q['showCorrectAnswers'] == true;
    final isPublished = _q['isPublished'] == true;
    final questions   = List<Map<String, dynamic>>.from(_q['questions'] ?? []);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.quiz_rounded, color: Color(0xFFF59E0B), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Quiz', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                _loading
                    ? const SizedBox(height: 16, width: 160, child: LinearProgressIndicator())
                    : Text(title.isEmpty ? '(No title)' : title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              ])),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPublished ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(isPublished ? 'Published' : 'Draft',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: isPublished ? const Color(0xFF059669) : const Color(0xFFD97706))),
              ),
              const SizedBox(width: 4),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ]),
          ),

          if (_loading)
            const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())
          else
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Stats chips
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (timeLimit > 0) _qChip(Icons.timer_rounded, '$timeLimit min', const Color(0xFF0284C7), const Color(0xFFE0F2FE)),
                    if (passingScore > 0) _qChip(Icons.verified_rounded, 'Pass: $passingScore%', const Color(0xFF059669), const Color(0xFFECFDF5)),
                    _qChip(Icons.help_outline_rounded, '${questions.length} question${questions.length == 1 ? '' : 's'}', const Color(0xFF7C3AED), const Color(0xFFF5F3FF)),
                    _qChip(Icons.refresh_rounded, '$maxAttempts attempt${maxAttempts == 1 ? '' : 's'}', const Color(0xFFD97706), const Color(0xFFFFF7ED)),
                    if (showAnswers) _qChip(Icons.check_circle_outline_rounded, 'Shows answers', const Color(0xFF10B981), const Color(0xFFECFDF5)),
                  ]),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
                      child: Text(description, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.5)),
                    ),
                  ],
                  if (questions.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('Questions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    ...questions.asMap().entries.map((e) => _buildQuestionCard(e.key + 1, e.value)),
                  ] else ...[
                    const SizedBox(height: 24),
                    const Center(child: Text('No questions added yet.', style: TextStyle(color: Color(0xFF94A3B8)))),
                  ],
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildQuestionCard(int qNum, Map<String, dynamic> q) {
    final text    = q['question']?.toString() ?? q['text']?.toString() ?? '';
    final options = List<String>.from(q['options'] ?? []);
    final correct = q['correctAnswer']?.toString() ?? q['answer']?.toString() ?? '';
    final points  = (q['points'] as num?)?.toInt() ?? 1;
    final explanation = q['explanation']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: Text('Q$qNum', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFF59E0B))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A), height: 1.4))),
          const SizedBox(width: 8),
          Text('$points pt${points == 1 ? '' : 's'}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ]),
        if (options.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...options.map((opt) {
            final isCorrect = opt == correct;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isCorrect ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isCorrect ? const Color(0xFF10B981) : const Color(0xFFE2E8F0), width: isCorrect ? 1.5 : 1),
              ),
              child: Row(children: [
                Icon(isCorrect ? Icons.check_circle_rounded : Icons.circle_outlined,
                    size: 16, color: isCorrect ? const Color(0xFF10B981) : const Color(0xFFCBD5E1)),
                const SizedBox(width: 8),
                Expanded(child: Text(opt, style: TextStyle(fontSize: 13, color: isCorrect ? const Color(0xFF059669) : const Color(0xFF334155), fontWeight: isCorrect ? FontWeight.w600 : FontWeight.normal))),
              ]),
            );
          }),
        ],
        if (explanation.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(8)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.lightbulb_outline_rounded, size: 14, color: Color(0xFFF59E0B)),
              const SizedBox(width: 6),
              Expanded(child: Text(explanation, style: const TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.4))),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _qChip(IconData icon, String label, Color fg, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: fg),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _RecordingDialog extends StatefulWidget {
  final String title;
  final String url;
  const _RecordingDialog({required this.title, required this.url});

  @override
  State<_RecordingDialog> createState() => _RecordingDialogState();
}

class _RecordingDialogState extends State<_RecordingDialog> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final compactWidth = screenSize.width < 760 ? screenSize.width - 48 : 720.0;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: _expanded
          ? const EdgeInsets.all(16)
          : const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: SizedBox(
        width: _expanded ? screenSize.width - 32 : compactWidth,
        height: _expanded ? screenSize.height - 32 : null,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(children: [
              const Icon(Icons.play_circle_rounded, color: Color(0xFF10B981), size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              IconButton(
                icon: Icon(_expanded ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded),
                tooltip: _expanded ? 'Shrink' : 'Enlarge',
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          if (_expanded)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: VideoPlayerWidget(videoUrl: widget.url),
              ),
            )
          else
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: VideoPlayerWidget(videoUrl: widget.url),
              ),
            ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }
}

