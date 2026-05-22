import 'package:flutter/material.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:intl/intl.dart';

/// Live Session Scheduling Screen - Zoom/Google Meet style
class InstructorScheduleSessionScreen extends StatefulWidget {
  final String? courseId;
  final String? sessionId; // For editing

  const InstructorScheduleSessionScreen({
    super.key,
    this.courseId,
    this.sessionId,
  });

  @override
  State<InstructorScheduleSessionScreen> createState() => _InstructorScheduleSessionScreenState();
}

class _InstructorScheduleSessionScreenState extends State<InstructorScheduleSessionScreen> {
  final LmsService _lmsService = LmsService();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isSubmitting = false;

  // Session data
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _meetingLinkController = TextEditingController();
  final _meetingIdController = TextEditingController();
  final _meetingPasswordController = TextEditingController();
  String? _selectedCourseId;
  DateTime? _scheduledAt;
  int _duration = 60; // minutes
  int _maxParticipants = 100;
  final String _platform = 'zoom'; // zoom, meet, teams, custom

  List<Map<String, dynamic>> _courses = [];

  @override
  void initState() {
    super.initState();
    _selectedCourseId = widget.courseId;
    _loadCourses();
    if (widget.sessionId != null) {
      _loadSession();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _meetingLinkController.dispose();
    _meetingIdController.dispose();
    _meetingPasswordController.dispose();
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

  Future<void> _loadSession() async {
    setState(() => _isLoading = true);
    try {
      // TODO: Implement get session by ID
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? DateTime.now().add(const Duration(days: 1)),
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
          _scheduledAt = DateTime(
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

  Future<void> _saveSession() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCourseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a course')),
      );
      return;
    }

    if (_scheduledAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and time')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final sessionData = {
        'courseId': _selectedCourseId,
        'title': _titleController.text,
        'description': _descriptionController.text,
        'scheduledAt': _scheduledAt!.toIso8601String(),
        'duration': _duration,
        'maxParticipants': _maxParticipants,
        'platform': _platform,
        'meetingLink': _meetingLinkController.text,
        'meetingId': _meetingIdController.text,
        'meetingPassword': _meetingPasswordController.text,
        'status': 'scheduled',
      };

      if (widget.sessionId != null) {
        await _lmsService.updateSession(widget.sessionId!, sessionData);
      } else {
        await _lmsService.createSession(sessionData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Session ${widget.sessionId != null ? 'updated' : 'scheduled'} successfully!')),
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
          widget.sessionId != null ? 'Edit Live Session' : 'Schedule Live Session',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _isSubmitting ? null : _saveSession,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Schedule'),
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
              // Session Details Card
              _buildCard(
                title: 'Session Details',
                icon: Icons.video_call_rounded,
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
                      labelText: 'Session Title *',
                      hintText: 'e.g., Week 1 Live Lecture',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'What will be covered in this session',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  InkWell(
                    onTap: _selectDateTime,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date & Time *',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _scheduledAt != null
                            ? DateFormat('EEE, MMM dd, yyyy - hh:mm a').format(_scheduledAt!)
                            : 'Select date and time',
                        style: TextStyle(
                          color: _scheduledAt != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _duration.toString(),
                          decoration: const InputDecoration(
                            labelText: 'Duration (minutes)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) => _duration = int.tryParse(value) ?? 60,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          initialValue: _maxParticipants.toString(),
                          decoration: const InputDecoration(
                            labelText: 'Max Participants',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) => _maxParticipants = int.tryParse(value) ?? 100,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Session Platform Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryColor.withValues(alpha: 0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.videocam_rounded, color: AppColors.primaryColor, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('iCare Built-in Live Session',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primaryColor)),
                      SizedBox(height: 4),
                      Text('HD video, chat, raise hand, polls, screen sharing, recording — all built-in. No external platform needed.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                    ]),
                  ),
                ]),
              ),

              const SizedBox(height: 24),

              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'When you click "Go Live" in the course, an iCare live session will start. Students will see a notification and can join directly from the Classwork tab.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                  ],
                ),
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

