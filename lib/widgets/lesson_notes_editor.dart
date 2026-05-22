import 'package:flutter/material.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/theme.dart';
import 'dart:async';

/// Lesson Notes Editor Widget
/// Students can write/edit notes during or after lessons with auto-save
class LessonNotesEditor extends StatefulWidget {
  final String courseId;
  final String moduleId;
  final String lessonId;
  final String lessonTitle;

  const LessonNotesEditor({
    super.key,
    required this.courseId,
    required this.moduleId,
    required this.lessonId,
    required this.lessonTitle,
  });

  @override
  State<LessonNotesEditor> createState() => _LessonNotesEditorState();
}

class _LessonNotesEditorState extends State<LessonNotesEditor> {
  final LmsService _lms = LmsService();
  final TextEditingController _notesController = TextEditingController();
  Timer? _autoSaveTimer;
  bool _isLoading = true;
  bool _isSaving = false;
  String _saveStatus = '';

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _notesController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    try {
      final result = await _lms.getLessonNote(widget.lessonId);
      if (mounted && result['note'] != null) {
        _notesController.text = result['note']['content'] ?? '';
      }
    } catch (e) {
      // Ignore - no notes yet
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onTextChanged() {
    // Cancel previous timer
    _autoSaveTimer?.cancel();

    // Set new timer for auto-save after 2 seconds of inactivity
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      _saveNotes();
    });

    setState(() => _saveStatus = 'Typing...');
  }

  Future<void> _saveNotes() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _saveStatus = 'Saving...';
    });

    try {
      await _lms.saveLessonNote(
        courseId: widget.courseId,
        moduleId: widget.moduleId,
        lessonId: widget.lessonId,
        content: _notesController.text,
      );

      if (mounted) {
        setState(() {
          _saveStatus = '✓ Saved';
          _isSaving = false;
        });

        // Clear status after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _saveStatus = '');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saveStatus = '✗ Failed';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.note_alt_rounded, color: AppColors.primaryColor, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'My Notes',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (_saveStatus.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _saveStatus.contains('✓')
                          ? Colors.green.withValues(alpha: 0.1)
                          : _saveStatus.contains('✗')
                              ? Colors.red.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _saveStatus,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _saveStatus.contains('✓')
                            ? Colors.green
                            : _saveStatus.contains('✗')
                                ? Colors.red
                                : const Color(0xFF64748B),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Notes Editor
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _notesController,
                maxLines: 10,
                decoration: InputDecoration(
                  hintText: 'Write your notes here...\n\nTip: Notes are auto-saved as you type.',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primaryColor, width: 2),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
            ),
        ],
      ),
    );
  }
}
