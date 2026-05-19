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

                // Live Session Info
                if (lessonType == 'live')
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.videocam_rounded, color: Colors.orange.shade700, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Live Session',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Join the live session when it starts',
                                style: TextStyle(fontSize: 13, color: Colors.orange.shade700),
                              ),
                            ],
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
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withOpacity(0.1),
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
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
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
}
