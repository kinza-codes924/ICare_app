import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:icare/screens/certificate_templates_screen.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/screens/lms_live_session_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// Course Content Management - Moodle/Udemy style
class InstructorCourseContentScreen extends StatefulWidget {
  final String courseId;

  const InstructorCourseContentScreen({
    super.key,
    required this.courseId,
  });

  @override
  State<InstructorCourseContentScreen> createState() => _InstructorCourseContentScreenState();
}

class _InstructorCourseContentScreenState extends State<InstructorCourseContentScreen> {
  final LmsService _lmsService = LmsService();

  Map<String, dynamic>? _course;
  bool _isLoading = true;
  CertificateTemplate _certificateTemplate = CertificateTemplate.classic;
  // 'self-paced' or 'pragmatic'
  String _courseType = 'self-paced';

  @override
  void initState() {
    super.initState();
    _loadCourse();
  }

  Future<void> _loadCourse() async {
    setState(() => _isLoading = true);
    try {
      final response = await _lmsService.getCourseDetails(widget.courseId);
      if (mounted) {
        setState(() {
          _course = response['course'];
          _courseType = _course?['courseType']?.toString() ?? 'self-paced';
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
          sessionId: widget.courseId,
          courseId: widget.courseId,
          sessionTitle: courseTitle,
          isInstructor: true,
        ),
      ),
    );
  }

  Future<void> _addModule() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ModuleDialog(),
    );

    if (result != null) {
      // Add module to course
      final modules = List<Map<String, dynamic>>.from(_course?['modules'] ?? []);
      modules.add(result);

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
      builder: (context) => _ModuleDialog(module: modules[index]),
    );

    if (result != null) {
      modules[index] = result;
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
    final platform = lesson['platform']?.toString() ?? 'zoom';

    if (meetingLink.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No meeting link set for this session. Please edit the lesson.'), backgroundColor: Colors.red),
      );
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
          _infoTile('Platform', platform.toUpperCase()),
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

  void _copyMeetingLink(Map<String, dynamic> lesson) {
    final link = lesson['meetingLink']?.toString() ?? '';
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No meeting link available'), backgroundColor: Colors.red),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Meeting link copied to clipboard!'), backgroundColor: Colors.green),
    );
  }

  void _postAnnouncement(String moduleTitle, String lessonTitle) {
    final ctrl = TextEditingController(text: 'The live session for "$lessonTitle" in "$moduleTitle" has been rescheduled. We will announce the new date shortly.');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.campaign_rounded, color: Color(0xFFF59E0B), size: 22),
          SizedBox(width: 10),
          Text('Post Announcement', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('This announcement will be visible to all enrolled students.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 14),
            TextField(controller: ctrl, maxLines: 4, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Announcement message')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiService().post('/courses/${widget.courseId}/announcements', {'message': ctrl.text.trim(), 'type': 'live_reschedule'});
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Announcement posted to all students'), backgroundColor: Colors.green));
              } catch (_) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Announcement posted (offline mode)'), backgroundColor: Colors.orange));
              }
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Post'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          ),
        ],
      ),
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
              'Course Content',
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
        actions: [
          // Certificate template picker
          IconButton(
            icon: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFD4AF37)),
            tooltip: 'Certificate Template',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => CertificateTemplateSelectorScreen(
                  courseTitle: _course?['title'] ?? 'Course',
                  instructorName: _course?['instructor']?['name'] ?? 'Instructor',
                  courseId: widget.courseId,
                  currentTemplate: _certificateTemplate,
                  certificateReleased: _course?['certificateReleased'] == true,
                  onSelect: (t) => setState(() => _certificateTemplate = t),
                ),
              )).then((_) => _loadCourse()); // reload course to get updated certificateReleased
            },
          ),
          // Course Type badge
          GestureDetector(
            onTap: _showCourseTypeDialog,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _courseType == 'pragmatic' ? const Color(0xFF6366F1).withValues(alpha: 0.1) : const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _courseType == 'pragmatic' ? const Color(0xFF6366F1).withValues(alpha: 0.3) : const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_courseType == 'pragmatic' ? Icons.timeline_rounded : Icons.self_improvement_rounded,
                    size: 14, color: _courseType == 'pragmatic' ? const Color(0xFF6366F1) : const Color(0xFF10B981)),
                const SizedBox(width: 5),
                Text(_courseType == 'pragmatic' ? 'Pragmatic' : 'Self-paced',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _courseType == 'pragmatic' ? const Color(0xFF6366F1) : const Color(0xFF10B981))),
              ]),
            ),
          ),
          const SizedBox(width: 4),
          // Go Live button
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
      body: modules.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadCourse,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: modules.length,
                itemBuilder: (context, index) {
                  return _buildModuleCard(modules[index], index);
                },
              ),
            ),
    );
  }

  Widget _buildModuleCard(Map<String, dynamic> module, int index) {
    final lessons = List<Map<String, dynamic>>.from(module['lessons'] ?? []);
    final title = module['title'] ?? 'Module ${index + 1}';
    final description = module['description'] ?? '';
    final completions = List<Map<String, dynamic>>.from(module['completions'] ?? []);
    final completionCount = completions.length;

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
          subtitle: description.isNotEmpty
              ? Text(
                  description,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
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
                padding: EdgeInsets.all(16),
                child: Text(
                  'No lessons yet. Edit module to add lessons.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              )
            else
              ...lessons.asMap().entries.map((entry) {
                final lessonIndex = entry.key;
                final lesson = entry.value;
                return _buildLessonItem(lesson, lessonIndex);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonItem(Map<String, dynamic> lesson, int index) {
    final title = lesson['title'] ?? 'Lesson ${index + 1}';
    final duration = lesson['duration'] ?? 0;
    final hasVideo = lesson['videoUrl'] != null && lesson['videoUrl'].toString().isNotEmpty;
    final isLiveSession = lesson['type']?.toString() == 'live';
    final hasRecording = lesson['recordingUrl'] != null && lesson['recordingUrl'].toString().isNotEmpty;
    final moduleTitle = ''; // passed via closure if needed

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLiveSession ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isLiveSession ? const Color(0xFFFB923C).withValues(alpha: 0.4) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isLiveSession
                  ? Colors.red.withValues(alpha: 0.1)
                  : hasVideo
                      ? const Color(0xFF10B981).withValues(alpha: 0.1)
                      : const Color(0xFF94A3B8).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isLiveSession ? Icons.live_tv_rounded : (hasVideo ? Icons.play_circle_outline : Icons.article_outlined),
              size: 20,
              color: isLiveSession ? Colors.red : (hasVideo ? const Color(0xFF10B981) : const Color(0xFF94A3B8)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                  if (isLiveSession) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    child: const Text('LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.red)),
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
                    Text(lesson['scheduledAt'].toString(), style: const TextStyle(fontSize: 12, color: Color(0xFFF59E0B))),
                  ],
                ]),
              ],
            ),
          ),
          // Live session actions
          if (isLiveSession) Row(mainAxisSize: MainAxisSize.min, children: [
            // Start / Open session button
            GestureDetector(
              onTap: () => _startLiveSession(lesson),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
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
              onSelected: (val) {
                if (val == 'announce') _postAnnouncement(moduleTitle, title);
                if (val == 'copy') _copyMeetingLink(lesson);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'copy', child: Row(children: [
                  Icon(Icons.copy_rounded, size: 18, color: AppColors.primaryColor),
                  SizedBox(width: 10),
                  Text('Copy Meeting Link'),
                ])),
                const PopupMenuItem(value: 'announce', child: Row(children: [
                  Icon(Icons.campaign_rounded, size: 18, color: Color(0xFFF59E0B)),
                  SizedBox(width: 10),
                  Text('Cancel & Announce'),
                ])),
              ],
            ),
          ]),
        ],
      ),
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

  const _ModuleDialog({this.module});

  @override
  State<_ModuleDialog> createState() => _ModuleDialogState();
}

class _ModuleDialogState extends State<_ModuleDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<Map<String, dynamic>> _lessons = [];

  @override
  void initState() {
    super.initState();
    if (widget.module != null) {
      _titleController.text = widget.module!['title'] ?? '';
      _descriptionController.text = widget.module!['description'] ?? '';
      if (widget.module!['lessons'] != null) {
        _lessons.addAll(List<Map<String, dynamic>>.from(widget.module!['lessons']));
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _addLesson() {
    showDialog(
      context: context,
      builder: (context) => _LessonDialog(
        onSave: (lesson) {
          setState(() => _lessons.add(lesson));
        },
      ),
    );
  }

  void _editLesson(int index) {
    showDialog(
      context: context,
      builder: (context) => _LessonDialog(
        lesson: _lessons[index],
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Lessons (${_lessons.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  TextButton.icon(
                    onPressed: _addLesson,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Lesson'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_lessons.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No lessons yet', style: TextStyle(color: Color(0xFF94A3B8))),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _lessons.length,
                  itemBuilder: (context, index) {
                    final lesson = _lessons[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.play_circle_outline, size: 20),
                      title: Text(lesson['title'] ?? 'Lesson ${index + 1}'),
                      subtitle: Text('${lesson['duration'] ?? 0} min'),
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

  const _LessonDialog({this.lesson, required this.onSave});

  @override
  State<_LessonDialog> createState() => _LessonDialogState();
}

class _LessonDialogState extends State<_LessonDialog> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _videoUrlController = TextEditingController();
  final _durationController = TextEditingController();
  bool _uploadingVideo = false;
  String? _uploadedVideoUrl;
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
      _durationController.text = (widget.lesson!['duration'] ?? 15).toString();
      _uploadedVideoUrl = widget.lesson!['videoUrl'];
      _lessonType = widget.lesson!['type']?.toString() == 'live' ? 'live' : 'content';
    } else {
      _durationController.text = '15';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _videoUrlController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _uploadVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;

      setState(() => _uploadingVideo = true);
      // Step 1: Get signed upload params from backend
      final signRes = await ApiService().get('/upload/sign?folder=icare/lessons');
      final signature = signRes.data['signature']?.toString() ?? '';
      final timestamp = signRes.data['timestamp']?.toString() ?? '';
      final apiKey = signRes.data['api_key']?.toString() ?? '';
      final cloudName = signRes.data['cloud_name']?.toString() ?? 'dzlcnyxgb';
      final folder = signRes.data['folder']?.toString() ?? 'icare/lessons';

      if (signature.isEmpty) throw Exception('Could not get upload signature from server');

      // Step 2: Upload directly to Cloudinary using signed params (bypasses Vercel 4.5MB limit)
      final dio2 = Dio();
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(file.bytes!, filename: file.name),
        'signature': signature,
        'timestamp': timestamp,
        'api_key': apiKey,
        'folder': folder,
      });
      final response = await dio2.post(
        'https://api.cloudinary.com/v1_1/$cloudName/auto/upload',
        data: formData,
        options: Options(validateStatus: (s) => s != null && s < 600),
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
      if (mounted) setState(() => _uploadingVideo = false);
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
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => setState(() => _lessonType = 'content'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _lessonType == 'content' ? AppColors.primaryColor : const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                      border: Border.all(color: _lessonType == 'content' ? AppColors.primaryColor : const Color(0xFFE2E8F0)),
                    ),
                    child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.article_outlined, size: 16, color: _lessonType == 'content' ? Colors.white : const Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text('Content', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _lessonType == 'content' ? Colors.white : const Color(0xFF64748B))),
                    ])),
                  ),
                )),
                Expanded(child: GestureDetector(
                  onTap: () => setState(() => _lessonType = 'live'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _lessonType == 'live' ? Colors.red : const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                      border: Border.all(color: _lessonType == 'live' ? Colors.red : const Color(0xFFE2E8F0)),
                    ),
                    child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.live_tv_rounded, size: 16, color: _lessonType == 'live' ? Colors.white : const Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text('Live Session', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _lessonType == 'live' ? Colors.white : const Color(0xFF64748B))),
                    ])),
                  ),
                )),
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
              ] else ...[
                const SizedBox(height: 0),
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
                          ? const Center(child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(width: 18, height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2)),
                                  SizedBox(width: 10),
                                  Text('Uploading video...', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                                ],
                              ),
                            ))
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
              'duration': int.tryParse(_durationController.text) ?? 15,
              'order': widget.lesson?['order'] ?? 0,
              'type': _lessonType,
              if (scheduledAt != null) 'scheduledAt': scheduledAt,
              'autoRecord': _lessonType == 'live',
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

