import 'package:flutter/material.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/lesson_notes_editor.dart';
import 'package:url_launcher/url_launcher.dart';

/// Lesson Detail Page with Video/Content and Notes Editor
class LessonDetailPage extends StatefulWidget {
  final Map<String, dynamic> lesson;
  final String courseId;
  final String moduleId;

  const LessonDetailPage({
    super.key,
    required this.lesson,
    required this.courseId,
    required this.moduleId,
  });

  @override
  State<LessonDetailPage> createState() => _LessonDetailPageState();
}

class _LessonDetailPageState extends State<LessonDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final LmsService _lms = LmsService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    final platform = widget.lesson['platform']?.toString() ?? 'zoom';
    final scheduledAt = widget.lesson['scheduledAt']?.toString();

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
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              color: Colors.black87,
                              child: const Center(
                                child: Icon(Icons.play_circle_outline, size: 64, color: Colors.white70),
                              ),
                            ),
                            Positioned(
                              bottom: 12,
                              right: 12,
                              child: ElevatedButton.icon(
                                onPressed: () => _launchUrl(videoUrl),
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text('Open Video'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                                  Row(children: [
                                    Text('Live Session',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.orange.shade900)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                                      child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                                    ),
                                  ]),
                                  if (scheduledAt != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatScheduledAt(scheduledAt),
                                      style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Platform badge
                        Row(children: [
                          _platformIcon(platform),
                          const SizedBox(width: 6),
                          Text(
                            _platformName(platform),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.orange.shade800),
                          ),
                        ]),

                        // Meeting ID & Password
                        if (meetingId.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _infoRow(Icons.tag_rounded, 'Meeting ID', meetingId),
                        ],
                        if (meetingPassword.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          _infoRow(Icons.lock_outline_rounded, 'Password', meetingPassword),
                        ],

                        const SizedBox(height: 14),

                        // Join Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: meetingLink.isNotEmpty
                                ? () => _launchUrl(meetingLink)
                                : null,
                            icon: const Icon(Icons.video_call_rounded, size: 20),
                            label: Text(meetingLink.isNotEmpty ? 'Join Session' : 'Link not available yet'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
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

  Widget _platformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'zoom':
        return const Icon(Icons.video_camera_front_rounded, color: Color(0xFF2D8CFF), size: 18);
      case 'meet':
        return const Icon(Icons.videocam_rounded, color: Color(0xFF00897B), size: 18);
      case 'teams':
        return const Icon(Icons.groups_rounded, color: Color(0xFF6264A7), size: 18);
      default:
        return const Icon(Icons.link_rounded, color: Colors.orange, size: 18);
    }
  }

  String _platformName(String platform) {
    switch (platform.toLowerCase()) {
      case 'zoom': return 'Zoom Meeting';
      case 'meet': return 'Google Meet';
      case 'teams': return 'Microsoft Teams';
      default: return 'Custom Link';
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
