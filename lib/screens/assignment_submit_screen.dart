import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/api_constants.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/attachment_viewer.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';

class AssignmentSubmitScreen extends StatefulWidget {
  final Map<String, dynamic> assignment;
  final String courseId;
  final String? enrollmentId;

  const AssignmentSubmitScreen({
    super.key,
    required this.assignment,
    required this.courseId,
    this.enrollmentId,
  });

  @override
  State<AssignmentSubmitScreen> createState() => _AssignmentSubmitScreenState();
}

class _AssignmentSubmitScreenState extends State<AssignmentSubmitScreen> {
  final LmsService _lmsService = LmsService();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _fileUrlController = TextEditingController();

  bool _isLoadingSubmission = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _existingSubmission;
  String? _error;

  // Direct file upload (Vercel Blob)
  bool _uploadingFile = false;
  String? _uploadedFileName; // kept for legacy single-file display fallback
  final List<Map<String, String>> _uploadedFiles = []; // [{url, name}]
  static const int _maxFiles = 5;

  // The /upload/blob-doc endpoint runs as a Vercel serverless function,
  // which hard-caps request bodies at 4.5 MB at the platform level —
  // uploads over that are rejected before this route's own code (or its
  // multer limit) ever runs, so Dio just sees a raw platform error with no
  // useful message. Checking client-side first turns that into a clear,
  // immediate "file too large" instead of a silent/confusing failure.
  static const int _maxUploadBytes = 4 * 1024 * 1024; // 4 MB (leaves headroom under the 4.5 MB platform cap)

  Future<void> _pickAndUploadFiles() async {
    try {
      if (_uploadedFiles.length >= _maxFiles) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Maximum $_maxFiles files allowed.'), backgroundColor: Colors.red),
        );
        return;
      }
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx',
          'txt', 'jpg', 'jpeg', 'png', 'zip',
        ],
        withData: true,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;

      final picked = result.files.where((f) => f.bytes != null).toList();
      final remaining = _maxFiles - _uploadedFiles.length;
      final toUpload = picked.take(remaining).toList();
      if (picked.length > remaining && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Only $remaining more file(s) can be added (max $_maxFiles total).')),
        );
      }

      setState(() => _uploadingFile = true);
      final token = await SharedPref().getToken() ?? '';
      for (final file in toUpload) {
        if (file.bytes!.length > _maxUploadBytes) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('"${file.name}" is ${(file.bytes!.length / (1024 * 1024)).toStringAsFixed(1)} MB — the maximum allowed is 4 MB. Skipped.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          continue;
        }
        try {
          final res = await Dio().post(
            '${ApiConstants.baseUrl}/upload/blob-doc',
            data: FormData.fromMap({
              'file': MultipartFile.fromBytes(file.bytes!, filename: file.name),
            }),
            options: Options(
              headers: {'Authorization': 'Bearer $token'},
              validateStatus: (s) => s != null && s < 600,
            ),
          );
          if (res.statusCode == 200 && res.data['success'] == true && res.data['url'] != null) {
            _uploadedFiles.add({'url': res.data['url'] as String, 'name': file.name});
          } else {
            throw Exception(res.data['message'] ?? 'Upload failed');
          }
        } catch (e) {
          debugPrint('Assignment file upload error: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Upload failed for "${file.name}": $e'), backgroundColor: Colors.red),
            );
          }
        }
      }
      if (mounted) {
        setState(() {
          _uploadingFile = false;
          if (_uploadedFiles.isNotEmpty) {
            _fileUrlController.text = _uploadedFiles.first['url']!;
            _uploadedFileName = _uploadedFiles.first['name'];
          }
        });
      }
    } catch (e) {
      debugPrint('Assignment file upload error: $e');
      if (mounted) {
        setState(() => _uploadingFile = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _removeUploadedFile(int index) {
    setState(() {
      _uploadedFiles.removeAt(index);
      if (_uploadedFiles.isEmpty) {
        _fileUrlController.clear();
        _uploadedFileName = null;
      } else {
        _fileUrlController.text = _uploadedFiles.first['url']!;
        _uploadedFileName = _uploadedFiles.first['name'];
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadExistingSubmission();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _fileUrlController.dispose();
    super.dispose();
  }

  String get _assignmentId =>
      widget.assignment['_id']?.toString() ??
      widget.assignment['id']?.toString() ??
      '';

  Future<void> _loadExistingSubmission() async {
    if (_assignmentId.isEmpty) {
      setState(() => _isLoadingSubmission = false);
      return;
    }
    try {
      final result = await _lmsService.getMySubmission(_assignmentId);
      if (mounted) {
        final submission = result['submission'] ?? result;
        if (submission is Map && submission.isNotEmpty &&
            (submission['content'] != null || submission['fileUrl'] != null)) {
          setState(() {
            _existingSubmission = Map<String, dynamic>.from(submission);
            _contentController.text = submission['content']?.toString() ?? '';
            _fileUrlController.text = submission['fileUrl']?.toString() ?? '';
            _uploadedFileName = submission['fileName']?.toString();
            final existingFiles = submission['files'];
            if (existingFiles is List && existingFiles.isNotEmpty) {
              _uploadedFiles
                ..clear()
                ..addAll(existingFiles
                    .whereType<Map>()
                    .map((f) => {'url': f['url']?.toString() ?? '', 'name': f['name']?.toString() ?? 'File'})
                    .where((f) => f['url']!.isNotEmpty));
            } else if (submission['fileUrl'] != null) {
              _uploadedFiles
                ..clear()
                ..add({'url': submission['fileUrl'].toString(), 'name': _uploadedFileName ?? 'File'});
            }
            _isLoadingSubmission = false;
          });
        } else {
          setState(() => _isLoadingSubmission = false);
        }
      }
    } catch (e) {
      // No existing submission
      if (mounted) setState(() => _isLoadingSubmission = false);
    }
  }

  Future<void> _submitAssignment() async {
    final content = _contentController.text.trim();
    final fileUrl = _fileUrlController.text.trim();

    if (content.isEmpty && fileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide either text content or a file URL.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _lmsService.submitAssignment(
        assignmentId: _assignmentId,
        content: content.isNotEmpty ? content : null,
        fileUrl: fileUrl.isNotEmpty ? fileUrl : null,
        fileName: fileUrl.isNotEmpty ? _uploadedFileName : null,
        files: _uploadedFiles.isNotEmpty ? _uploadedFiles : null,
      );
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _existingSubmission = {
            'content': content,
            'fileUrl': fileUrl,
            'submittedAt': DateTime.now().toIso8601String(),
          };
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Assignment submitted successfully!'),
            ]),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _error = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: ${e.toString()}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _getDueDateLabel() {
    final dueDateStr = widget.assignment['dueDate']?.toString() ?? '';
    if (dueDateStr.isEmpty) return '';
    try {
      final due = DateTime.parse(dueDateStr);
      return DateFormat('MMMM dd, yyyy • hh:mm a').format(due);
    } catch (_) {
      return dueDateStr;
    }
  }

  bool get _isLate {
    final dueDateStr = widget.assignment['dueDate']?.toString() ?? '';
    if (dueDateStr.isEmpty) return false;
    try {
      final due = DateTime.parse(dueDateStr);
      return DateTime.now().isAfter(due);
    } catch (_) {
      return false;
    }
  }

  bool get _isSubmitted => _existingSubmission != null;

  /// Editable until graded — students can update fields when resubmitting
  bool get _canEdit => !_isSubmitted || _getGradeInfo().isEmpty;

  String _getGradeInfo() {
    if (_existingSubmission == null) return '';
    final marks = _existingSubmission!['marksObtained'] ??
        _existingSubmission!['marks'] ??
        _existingSubmission!['grade'];
    if (marks == null) return '';
    final total = widget.assignment['totalMarks']?.toString() ?? '';
    return total.isNotEmpty ? '$marks / $total' : '$marks';
  }

  // ── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final title = widget.assignment['title'] ?? 'Assignment';
    final description = widget.assignment['description']?.toString() ??
        widget.assignment['instructions']?.toString() ?? '';
    final dueDateLabel = _getDueDateLabel();
    final totalMarks = widget.assignment['totalMarks']?.toString() ?? '';
    final gradeInfo = _getGradeInfo();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        leading: const CustomBackButton(color: Colors.white),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        actions: [
          if (_isSubmitted && !_isLate)
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Submitted',
                    style: TextStyle(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          if (_isLate && !_isSubmitted)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Late',
                  style: TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _isLoadingSubmission
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Assignment Info Card ─────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
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
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.assignment_rounded,
                                  color: AppColors.primaryColor, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A))),
                                  if (totalMarks.isNotEmpty)
                                    Text('Total Marks: $totalMarks',
                                        style: const TextStyle(
                                            fontSize: 12, color: Color(0xFF64748B))),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (dueDateLabel.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _isLate
                                  ? const Color(0xFFFEF2F2)
                                  : const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _isLate
                                    ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                                    : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isLate
                                      ? Icons.warning_rounded
                                      : Icons.calendar_today_rounded,
                                  size: 15,
                                  color: _isLate
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFFF59E0B),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _isLate
                                        ? 'Due date passed: $dueDateLabel'
                                        : 'Due: $dueDateLabel',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _isLate
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFFF59E0B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text('Instructions',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A))),
                          const SizedBox(height: 8),
                          Text(description,
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF374151), height: 1.6)),
                        ],
                        Builder(builder: (_) {
                          final attachUrl = widget.assignment['attachmentUrl']?.toString() ?? '';
                          final attachName = widget.assignment['attachmentName']?.toString() ?? '';
                          if (attachUrl.isEmpty) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              const Text('Attachment',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A))),
                              const SizedBox(height: 8),
                              AttachmentViewer(
                                url: attachUrl,
                                name: attachName.isNotEmpty ? attachName : 'View Attachment',
                                label: 'Tap to open in browser',
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Grade/Feedback Card (if graded) ──────────────────
                  if (_isSubmitted && gradeInfo.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.grade_rounded, color: Color(0xFF10B981), size: 18),
                              SizedBox(width: 8),
                              Text('Grade',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF10B981))),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(gradeInfo,
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A))),
                          if (_existingSubmission!['rubricGrade'] != null &&
                              _existingSubmission!['rubricGrade'].toString().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _existingSubmission!['rubricGrade'].toString(),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF047857)),
                              ),
                            ),
                          ],
                          if (_existingSubmission!['stars'] != null) ...[
                            const SizedBox(height: 12),
                            Builder(builder: (_) {
                              final starCount = (_existingSubmission!['stars'] as num).toInt();
                              return Row(children: [
                                ...List.generate(5, (i) => Icon(
                                  i < starCount ? Icons.star_rounded : Icons.star_outline_rounded,
                                  size: 22,
                                  color: i < starCount ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                                )),
                                const SizedBox(width: 8),
                                Text('($starCount/5 Rating)',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF374151))),
                              ]);
                            }),
                          ],
                          if (_existingSubmission!['feedback'] != null &&
                              _existingSubmission!['feedback'].toString().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Text('Instructor Feedback',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF374151))),
                            const SizedBox(height: 6),
                            Text(
                              _existingSubmission!['feedback'].toString(),
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF374151), height: 1.5),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Submission Form / View ────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
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
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _isSubmitted
                                    ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                    : const Color(0xFF6366F1).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _isSubmitted
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.edit_note_rounded,
                                color: _isSubmitted
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF6366F1),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _isSubmitted ? 'Your Submission' : 'Submit Your Work',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A)),
                            ),
                            if (_isSubmitted && _existingSubmission!['submittedAt'] != null) ...[
                              const Spacer(),
                              Text(
                                _formatDate(_existingSubmission!['submittedAt'].toString()),
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Text submission
                        const Text('Written Submission',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _contentController,
                          maxLines: 8,
                          readOnly: !_canEdit,
                          style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            hintText: !_canEdit
                                ? 'No written submission'
                                : 'Type your answer, essay, or notes here...',
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            filled: true,
                            fillColor: _isSubmitted
                                ? const Color(0xFFF8FAFC)
                                : const Color(0xFFFAFAFF),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.primaryColor.withValues(alpha: 0.6),
                                width: 1.5,
                              ),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // File upload
                        const Text('File Upload',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                        const SizedBox(height: 8),

                        // Submitted / uploaded files preview
                        if (_uploadedFiles.isEmpty)
                          (!_canEdit
                              ? Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: const Text('No file submitted',
                                      style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                                )
                              : const SizedBox.shrink())
                        else
                          ...List.generate(_uploadedFiles.length, (i) {
                            final f = _uploadedFiles[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(children: [
                                Expanded(
                                  child: AttachmentViewer(
                                    url: f['url']!,
                                    name: f['name'] ?? 'Submitted file',
                                    label: 'Tap to open in browser',
                                  ),
                                ),
                                if (_canEdit && !_uploadingFile) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () => _removeUploadedFile(i),
                                    icon: const Icon(Icons.close_rounded, color: Colors.red, size: 18),
                                    tooltip: 'Remove file',
                                    style: IconButton.styleFrom(
                                      backgroundColor: const Color(0xFFFFEBEE),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ],
                              ]),
                            );
                          }),

                        if (_canEdit) ...[
                          // Direct file upload button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: (_uploadingFile || _uploadedFiles.length >= _maxFiles) ? null : _pickAndUploadFiles,
                              icon: _uploadingFile
                                  ? const SizedBox(
                                      width: 16, height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.upload_file_rounded, size: 18),
                              label: Text(
                                _uploadingFile
                                    ? 'Uploading...'
                                    : (_uploadedFiles.isNotEmpty
                                        ? 'Add another file (${_uploadedFiles.length}/$_maxFiles)'
                                        : 'Upload Files'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _uploadedFiles.isNotEmpty
                                    ? const Color(0xFF10B981)
                                    : AppColors.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'PDF, Word, PowerPoint, Excel, images or ZIP — up to $_maxFiles files, 4 MB each.',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.5),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Submit / Resubmit Button ─────────────────────────
                  if (!_isSubmitted || gradeInfo.isEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitAssignment,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(
                                _isSubmitted ? Icons.update_rounded : Icons.send_rounded,
                                size: 20,
                              ),
                        label: Text(
                          _isSubmitting
                              ? 'Submitting...'
                              : _isSubmitted
                                  ? 'Resubmit'
                                  : 'Submit Assignment',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isSubmitted
                              ? const Color(0xFF6366F1)
                              : AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ] else ...[
                    // Graded — no resubmission
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_rounded, size: 16, color: Color(0xFF94A3B8)),
                          SizedBox(width: 8),
                          Text('Assignment Graded - Submission Locked',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}
