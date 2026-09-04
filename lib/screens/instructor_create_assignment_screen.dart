import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/api_constants.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/utils/theme.dart';
import 'package:intl/intl.dart';
import 'package:icare/widgets/back_button.dart';

/// Assignment Creation Screen - Google Classroom style
class InstructorCreateAssignmentScreen extends StatefulWidget {
  final String? courseId;
  final String? assignmentId; // For editing

  const InstructorCreateAssignmentScreen({
    super.key,
    this.courseId,
    this.assignmentId,
  });

  @override
  State<InstructorCreateAssignmentScreen> createState() => _InstructorCreateAssignmentScreenState();
}

class _InstructorCreateAssignmentScreenState extends State<InstructorCreateAssignmentScreen> {
  final LmsService _lmsService = LmsService();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isSubmitting = false;

  // Assignment data
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _instructionsController = TextEditingController();
  String? _selectedCourseId;
  DateTime? _dueDate;
  int _totalMarks = 100;
  bool _isPublished = false;
  String _submissionType = 'file'; // file, text, both

  // Attachment
  String? _attachmentUrl;
  String? _attachmentName;
  bool _uploadingAttachment = false;

  List<Map<String, dynamic>> _courses = [];

  @override
  void initState() {
    super.initState();
    _selectedCourseId = widget.courseId;
    _loadCourses();
    if (widget.assignmentId != null) {
      _loadAssignment();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<String?> _cloudinaryRawUpload(Uint8List bytes, String filename) async {
    final token = await SharedPref().getToken() ?? '';
    // Documents go through our backend to the server's disk (icare.com.co/
    // uploads/). Cloudinary raw upload 401'd on PDFs and Vercel Blob is gone.
    final res = await Dio().post(
      '${ApiConstants.baseUrl}/upload/blob-doc',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      }),
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        validateStatus: (s) => s != null && s < 600,
      ),
    );
    if (res.statusCode == 200 && res.data['url'] != null) {
      return res.data['url'] as String;
    }
    throw Exception('Upload failed: ${res.data}');
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'txt', 'jpg', 'jpeg', 'png', 'mp4', 'mov'],
        withData: true,
      );
      if (result == null || result.files.isEmpty || result.files.first.bytes == null) return;
      final file = result.files.first;
      setState(() => _uploadingAttachment = true);
      final url = await _cloudinaryRawUpload(file.bytes!, file.name);
      if (mounted) setState(() { _attachmentUrl = url; _attachmentName = file.name; _uploadingAttachment = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingAttachment = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _loadCourses() async {
    try {
      final response = await _lmsService.getInstructorCourses();
      if (mounted) {
        setState(() {
          _courses = List<Map<String, dynamic>>.from(response['courses'] ?? []);
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _loadAssignment() async {
    setState(() => _isLoading = true);
    try {
      final data = await _lmsService.getAssignment(widget.assignmentId!);
      final a = (data['assignment'] as Map<String, dynamic>?) ?? {};
      if (mounted) {
        setState(() {
          _titleController.text       = a['title']?.toString() ?? '';
          _descriptionController.text = a['description']?.toString() ?? '';
          _instructionsController.text = a['instructions']?.toString() ?? '';
          _totalMarks   = (a['totalMarks'] as num?)?.toInt() ?? 100;
          _isPublished  = a['isPublished'] == true;
          _submissionType = a['submissionType']?.toString() ?? 'file';
          _attachmentUrl  = a['attachmentUrl']?.toString();
          _attachmentName = a['attachmentName']?.toString();
          final rawDate = a['dueDate'];
          if (rawDate != null) _dueDate = DateTime.tryParse(rawDate.toString());
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null && mounted) {
        setState(() {
          _dueDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _saveAssignment() async {
    if (!_formKey.currentState!.validate()) return;

    final isEditing = widget.assignmentId != null;
    if (!isEditing && (_selectedCourseId == null || (_selectedCourseId?.isEmpty ?? true))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a course')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final data = {
        if (!isEditing && _selectedCourseId != null) 'courseId': _selectedCourseId,
        'title': _titleController.text,
        'description': _descriptionController.text,
        'instructions': _instructionsController.text,
        'dueDate': _dueDate?.toIso8601String(),
        'totalMarks': _totalMarks,
        'isPublished': _isPublished,
        'submissionType': _submissionType,
        'attachmentUrl': _attachmentUrl,
        'attachmentName': _attachmentName,
      };

      if (isEditing) {
        final updated = await _lmsService.updateAssignment(widget.assignmentId!, data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Assignment updated!'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, updated['assignment'] ?? updated);
        }
      } else {
        final created = await _lmsService.createAssignment(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Assignment created!'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, created['assignment'] ?? created);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF0F172A)),
          onPressed: () => goBackOrHome(context),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.assignmentId != null ? 'Edit Assignment' : 'Create Assignment',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _isSubmitting ? null : _saveAssignment,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(widget.assignmentId != null ? 'Save' : 'Create'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryColor,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Info Card
              _buildCard(
                title: 'Assignment Details',
                icon: Icons.assignment_outlined,
                children: [
                  if (widget.courseId == null)
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCourseId,
                      decoration: const InputDecoration(
                        labelText: 'Course *',
                        border: OutlineInputBorder(),
                      ),
                      items: _courses.map((course) {
                        return DropdownMenuItem(
                          value: course['_id'].toString(),
                          child: Text(course['title'] ?? 'Untitled'),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedCourseId = value),
                      validator: (value) => value == null ? 'Please select a course' : null,
                    ),
                  if (widget.courseId == null) const SizedBox(height: 16),

                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Assignment Title *',
                      hintText: 'e.g., Week 1 Assignment - Research Paper',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Brief description of the assignment',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _instructionsController,
                    decoration: const InputDecoration(
                      labelText: 'Instructions',
                      hintText: 'Detailed instructions for students',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Settings Card
              _buildCard(
                title: 'Assignment Settings',
                icon: Icons.settings_outlined,
                children: [
                  InkWell(
                    onTap: _selectDueDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Due Date',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _dueDate != null
                            ? DateFormat('MMM dd, yyyy - hh:mm a').format(_dueDate!)
                            : 'Select due date',
                        style: TextStyle(
                          color: _dueDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    initialValue: _totalMarks.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Total Marks',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => _totalMarks = int.tryParse(value) ?? 100,
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue: _submissionType,
                    decoration: const InputDecoration(
                      labelText: 'Submission Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'file', child: Text('File Upload')),
                      DropdownMenuItem(value: 'text', child: Text('Text Entry')),
                      DropdownMenuItem(value: 'both', child: Text('File or Text')),
                    ],
                    onChanged: (value) => setState(() => _submissionType = value!),
                  ),
                  const SizedBox(height: 16),

                  SwitchListTile(
                    title: const Text('Publish immediately'),
                    subtitle: const Text('Students can view and submit'),
                    value: _isPublished,
                    onChanged: (value) => setState(() => _isPublished = value),
                    activeThumbColor: AppColors.primaryColor,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Attachment Card
              _buildCard(
                title: 'Attachment',
                icon: Icons.attach_file,
                children: [
                  if (_attachmentUrl != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _attachmentName ?? 'Attachment uploaded',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF065F46)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(() { _attachmentUrl = null; _attachmentName = null; }),
                            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _uploadingAttachment
                      ? const Center(child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                              SizedBox(width: 10),
                              Text('Uploading...', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                            ],
                          ),
                        ))
                      : OutlinedButton.icon(
                          onPressed: _pickAttachment,
                          icon: const Icon(Icons.upload_file),
                          label: Text(_attachmentUrl != null ? 'Replace Attachment' : 'Upload Attachment'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryColor,
                            side: BorderSide(color: AppColors.primaryColor),
                          ),
                        ),
                  const SizedBox(height: 8),
                  const Text(
                    'Attach a PDF, document, image, or video for students to reference.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primaryColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

