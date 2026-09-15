import 'package:flutter/material.dart';
import 'package:icare/services/instructor_service.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/widgets/custom_text_input.dart';

class InstructorCreatePrecautionScreen extends StatefulWidget {
  final Map<String, dynamic>? precaution;

  const InstructorCreatePrecautionScreen({super.key, this.precaution});

  @override
  State<InstructorCreatePrecautionScreen> createState() =>
      _InstructorCreatePrecautionScreenState();
}

class _InstructorCreatePrecautionScreenState
    extends State<InstructorCreatePrecautionScreen> {
  final InstructorService _instructorService = InstructorService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  bool _isLoading = false;
  bool get _isEditing => widget.precaution != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleController.text = widget.precaution!['title'] ?? '';
      _bodyController.text = widget.precaution!['body'] ?? '';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'title': _titleController.text,
        'body': _bodyController.text,
        'attachments': [],
      };

      if (_isEditing) {
        await _instructorService.updatePrecaution(
          widget.precaution!['_id'],
          data,
        );
      } else {
        await _instructorService.createPrecaution(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Health tip ${_isEditing ? 'updated' : 'created'} successfully!',
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: const Text('Something went wrong. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const CustomBackButton(),
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isEditing ? 'Edit Health Tip' : 'Create Health Tip',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share valuable health tips and precautions with your students',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 24),
              CustomInputField(
                maxLength: 120,
                controller: _titleController,
                hintText: 'Title (e.g., Daily Mental Health Practices)',
                validator: (val) => val?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              CustomInputField(
                maxLength: 500,
                controller: _bodyController,
                hintText:
                    'Description\n\nProvide detailed information, tips, and recommendations...',
                maxLines: 10,
                validator: (val) => val?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 32),
              CustomButton(
                label: _isLoading
                    ? 'Saving...'
                    : (_isEditing ? 'Update Health Tip' : 'Create Health Tip'),
                onPressed: _isLoading ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }
}
