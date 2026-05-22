import 'package:flutter/material.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:intl/intl.dart';

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
      // TODO: Implement get assignment by ID
      // For now, just set loading to false
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

    if (_selectedCourseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a course')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final assignmentData = {
        'courseId': _selectedCourseId,
        'title': _titleController.text,
        'description': _descriptionController.text,
        'instructions': _instructionsController.text,
        'dueDate': _dueDate?.toIso8601String(),
        'totalMarks': _totalMarks,
        'isPublished': _isPublished,
        'submissionType': _submissionType,
      };

      await _lmsService.createAssignment(assignmentData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assignment created successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
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
          onPressed: () => Navigator.pop(context),
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
            label: const Text('Create'),
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

              // Resources Card (Future enhancement)
              _buildCard(
                title: 'Resources',
                icon: Icons.attach_file,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Implement file upload
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('File upload coming soon')),
                      );
                    },
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload Resource Files'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryColor,
                      side: BorderSide(color: AppColors.primaryColor),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Upload reference materials, templates, or sample files',
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

