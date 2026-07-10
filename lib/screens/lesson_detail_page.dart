import 'package:flutter/material.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/lesson_notes_editor.dart';
import 'package:icare/widgets/video_player_widget.dart';
import 'package:url_launcher/url_launcher.dart';

/// Lesson Detail Page with Video/Content and Notes Editor
class LessonDetailPage extends StatefulWidget {
  final Map<String, dynamic> lesson;
  final String courseId;
  final String moduleId;
  final String? enrollmentId;
  final void Function(String lessonId)? onLessonCompleted;

  const LessonDetailPage({
    super.key,
    required this.lesson,
    required this.courseId,
    required this.moduleId,
    this.enrollmentId,
    this.onLessonCompleted,
  });

  @override
  State<LessonDetailPage> createState() => _LessonDetailPageState();
}

class _LessonDetailPageState extends State<LessonDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final LmsService _lms = LmsService();
  bool _isCompleted = false;
  bool _markingComplete = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _isCompleted = widget.lesson['isCompleted'] == true;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _toggleComplete() async {
    if (_markingComplete) return;
    final lessonId = widget.lesson['_id']?.toString() ?? widget.lesson['id']?.toString() ?? '';
    final enrollmentId = widget.enrollmentId;
    if (enrollmentId == null || enrollmentId.isEmpty || lessonId.isEmpty) return;

    setState(() { _markingComplete = true; _isCompleted = !_isCompleted; });
    try {
      if (_isCompleted) {
        await _lms.markLessonComplete(
          enrollmentId: enrollmentId,
          lessonId: lessonId,
          moduleId: widget.moduleId.isNotEmpty ? widget.moduleId : null,
        );
        widget.onLessonCompleted?.call(lessonId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lesson marked as completed!'), backgroundColor: Color(0xFF10B981), duration: Duration(seconds: 2)),
        );
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isCompleted = !_isCompleted);
    } finally {
      if (mounted) setState(() => _markingComplete = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lessonTitle = widget.lesson['title'] ?? 'Lesson';
    final lessonType = widget.lesson['type'] ?? 'content';
    final videoUrl = widget.lesson['videoUrl'];
    final documentUrl = widget.lesson['documentUrl'];
    final content = widget.lesson['content'] ?? '';
    final lessonId = widget.lesson['_id']?.toString() ?? '';
    final meetingLink = widget.lesson['meetingLink']?.toString() ?? '';
    final meetingId = widget.lesson['meetingId']?.toString() ?? '';
    final meetingPassword = widget.lesson['meetingPassword']?.toString() ?? '';
    final liveSessionDateTime = widget.lesson['liveSessionDateTime']?.toString() ?? '';
    final liveSessionNote = widget.lesson['liveSessionNote']?.toString() ?? '';
    final scheduledAt = widget.lesson['scheduledAt']?.toString() ?? (liveSessionDateTime.isNotEmpty ? liveSessionDateTime : null);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        leading: const CustomBackButton(color: Colors.white),
        title: Text(
          lessonTitle,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.play_circle_outline), text: 'Content'),
            Tab(icon: Icon(Icons.note_alt_outlined), text: 'My Notes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Content Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Video Player Section
                if (lessonType == 'content' && videoUrl != null && videoUrl.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    color: Colors.black,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: VideoPlayerWidget(videoUrl: videoUrl),
                    ),
                  ),

                // Live Session Info + Join Button
                if (lessonType == 'live')
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.live_tv_rounded, color: Colors.red.shade600, size: 28),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Live Session',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.orange.shade900)),
                                  if (scheduledAt != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatScheduledAt(scheduledAt),
                                      style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                                    ),
                                  ],
                                  if (liveSessionNote.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      liveSessionNote,
                                      style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Meeting ID & Password — only shown when this lesson actually
                        // carries an external meeting link (legacy Zoom/Meet embed path).
                        if (meetingId.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _infoRow(Icons.tag_rounded, 'Meeting ID', meetingId),
                        ],
                        if (meetingPassword.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          _infoRow(Icons.lock_outline_rounded, 'Password', meetingPassword),
                        ],

                        const SizedBox(height: 14),

                        if (meetingLink.isNotEmpty)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _launchUrl(meetingLink),
                              icon: const Icon(Icons.video_call_rounded, size: 20),
                              label: const Text('Join Session'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          )
                        else
                          // The real, correctly-scheduled session lives under Course
                          // Content (backed by the LiveSession model) — this legacy
                          // per-lesson meetingLink field is rarely populated, so point
                          // students there instead of showing a permanently-dead button.
                          Text(
                            'Join this session from Course Content when it goes live.',
                            style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontStyle: FontStyle.italic),
                          ),
                      ],
                    ),
                  ),

                // Document Section
                if (documentUrl != null && documentUrl.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.description_rounded, color: AppColors.primaryColor, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Lesson Document',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'PDF or Document',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _launchUrl(documentUrl),
                          icon: const Icon(Icons.open_in_new, color: AppColors.primaryColor),
                        ),
                      ],
                    ),
                  ),

                // Content Section
                if (content.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.article_outlined, color: AppColors.primaryColor, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Lesson Content',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          content,
                          style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),
                // Mark as Completed (only for enrolled students/patients)
                if (widget.enrollmentId != null && widget.enrollmentId!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _toggleComplete,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: _isCompleted
                            ? const Color(0xFF10B981).withValues(alpha: 0.1)
                            : AppColors.primaryColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isCompleted
                              ? const Color(0xFF10B981)
                              : AppColors.primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          _markingComplete
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                              : AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 22, height: 22,
                                  decoration: BoxDecoration(
                                    color: _isCompleted ? const Color(0xFF10B981) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _isCompleted ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                                      width: 2,
                                    ),
                                  ),
                                  child: _isCompleted
                                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                      : null,
                                ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isCompleted ? 'Completed!' : 'Mark as Completed',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _isCompleted ? const Color(0xFF10B981) : AppColors.primaryColor,
                                  ),
                                ),
                                if (!_isCompleted)
                                  const Text('Tap to mark this lesson as done',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),

          // Notes Tab
          LessonNotesEditor(
            courseId: widget.courseId,
            moduleId: widget.moduleId,
            lessonId: lessonId,
            lessonTitle: lessonTitle,
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open URL'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, size: 14, color: Colors.orange.shade700),
      const SizedBox(width: 6),
      Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.orange.shade700, fontWeight: FontWeight.w600)),
      Text(value, style: TextStyle(fontSize: 12, color: Colors.orange.shade900, fontWeight: FontWeight.w700)),
    ]);
  }

  String _formatScheduledAt(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour < 12 ? 'AM' : 'PM';
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $h:$m $ampm';
    } catch (_) {
      return iso;
    }
  }
}
