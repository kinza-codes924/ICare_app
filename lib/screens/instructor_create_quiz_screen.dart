import 'package:flutter/material.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/theme.dart';

/// Quiz Creation Screen - Google Classroom style
class InstructorCreateQuizScreen extends StatefulWidget {
  final String? courseId;
  final String? quizId; // For editing existing quiz

  const InstructorCreateQuizScreen({
    super.key,
    this.courseId,
    this.quizId,
  });

  @override
  State<InstructorCreateQuizScreen> createState() => _InstructorCreateQuizScreenState();
}

class _InstructorCreateQuizScreenState extends State<InstructorCreateQuizScreen> {
  final LmsService _lmsService = LmsService();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isSubmitting = false;

  // Quiz data
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCourseId;
  int _timeLimit = 30;
  int _passingScore = 60;
  int _maxAttempts = 3;
  bool _showCorrectAnswers = true;
  bool _isPublished = false;

  // Questions
  final List<Map<String, dynamic>> _questions = [];

  List<Map<String, dynamic>> _courses = [];

  @override
  void initState() {
    super.initState();
    _selectedCourseId = widget.courseId;
    _loadCourses();
    if (widget.quizId != null) {
      _loadQuiz();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
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

  Future<void> _loadQuiz() async {
    setState(() => _isLoading = true);
    try {
      final response = await _lmsService.getQuiz(widget.quizId!);
      final quiz = response['quiz'];

      if (mounted) {
        setState(() {
          _titleController.text = quiz['title'] ?? '';
          _descriptionController.text = quiz['description'] ?? '';
          _selectedCourseId = quiz['courseId']?.toString();
          _timeLimit = quiz['timeLimit'] ?? 30;
          _passingScore = quiz['passingScore'] ?? 60;
          _maxAttempts = quiz['maxAttempts'] ?? 3;
          _showCorrectAnswers = quiz['showCorrectAnswers'] ?? true;
          _isPublished = quiz['isPublished'] ?? false;
          _questions.clear();
          _questions.addAll(List<Map<String, dynamic>>.from(quiz['questions'] ?? []));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading quiz: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _saveQuiz() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCourseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a course')),
      );
      return;
    }

    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one question')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final quizData = {
        'courseId': _selectedCourseId,
        'title': _titleController.text,
        'description': _descriptionController.text,
        'timeLimit': _timeLimit,
        'passingScore': _passingScore,
        'maxAttempts': _maxAttempts,
        'showCorrectAnswers': _showCorrectAnswers,
        'isPublished': _isPublished,
        'questions': _questions,
      };

      if (widget.quizId != null) {
        await _lmsService.updateQuiz(widget.quizId!, quizData);
      } else {
        await _lmsService.createQuiz(quizData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Quiz ${widget.quizId != null ? 'updated' : 'created'} successfully!')),
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

  void _addQuestion() {
    showDialog(
      context: context,
      builder: (context) => _QuestionDialog(
        onSave: (question) {
          setState(() => _questions.add(question));
        },
      ),
    );
  }

  void _editQuestion(int index) {
    showDialog(
      context: context,
      builder: (context) => _QuestionDialog(
        question: _questions[index],
        onSave: (question) {
          setState(() => _questions[index] = question);
        },
      ),
    );
  }

  void _deleteQuestion(int index) {
    setState(() => _questions.removeAt(index));
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
          widget.quizId != null ? 'Edit Quiz' : 'Create Quiz',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _isSubmitting ? null : _saveQuiz,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(widget.quizId != null ? 'Update' : 'Create'),
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
                title: 'Basic Information',
                icon: Icons.info_outline,
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
                      labelText: 'Quiz Title *',
                      hintText: 'e.g., Week 1 Quiz - Introduction',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Brief description of the quiz',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Settings Card
              _buildCard(
                title: 'Quiz Settings',
                icon: Icons.settings_outlined,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _timeLimit.toString(),
                          decoration: const InputDecoration(
                            labelText: 'Time Limit (minutes)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) => _timeLimit = int.tryParse(value) ?? 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          initialValue: _passingScore.toString(),
                          decoration: const InputDecoration(
                            labelText: 'Passing Score (%)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) => _passingScore = int.tryParse(value) ?? 60,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    initialValue: _maxAttempts.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Maximum Attempts',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => _maxAttempts = int.tryParse(value) ?? 3,
                  ),
                  const SizedBox(height: 16),

                  SwitchListTile(
                    title: const Text('Show correct answers after submission'),
                    value: _showCorrectAnswers,
                    onChanged: (value) => setState(() => _showCorrectAnswers = value),
                    activeThumbColor: AppColors.primaryColor,
                  ),

                  SwitchListTile(
                    title: const Text('Publish immediately'),
                    subtitle: const Text('Students can take this quiz'),
                    value: _isPublished,
                    onChanged: (value) => setState(() => _isPublished = value),
                    activeThumbColor: AppColors.primaryColor,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Questions Card
              _buildCard(
                title: 'Questions (${_questions.length})',
                icon: Icons.quiz_outlined,
                trailing: ElevatedButton.icon(
                  onPressed: _addQuestion,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Question'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                  ),
                ),
                children: [
                  if (_questions.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No questions yet. Add your first question!',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _questions.length,
                      separatorBuilder: (_, _) => const Divider(height: 24),
                      itemBuilder: (context, index) {
                        return _buildQuestionItem(index);
                      },
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
    Widget? trailing,
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
                if (trailing != null) ...[
                  const Spacer(),
                  trailing,
                ],
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

  Widget _buildQuestionItem(int index) {
    final question = _questions[index];
    final type = question['type'] ?? 'mcq';

    String typeLabel;
    IconData typeIcon;
    switch (type) {
      case 'true_false':
        typeLabel = 'True/False';
        typeIcon = Icons.check_circle_outline;
        break;
      case 'short_answer':
        typeLabel = 'Short Answer';
        typeIcon = Icons.short_text;
        break;
      case 'essay':
        typeLabel = 'Essay';
        typeIcon = Icons.article_outlined;
        break;
      default:
        typeLabel = 'Multiple Choice';
        typeIcon = Icons.radio_button_checked;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(typeIcon, size: 14, color: AppColors.primaryColor),
                    const SizedBox(width: 4),
                    Text(
                      typeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${question['points'] ?? 1} pts',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => _editQuestion(index),
                color: AppColors.primaryColor,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => _deleteQuestion(index),
                color: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Q${index + 1}. ${question['question'] ?? ''}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
          if (question['options'] != null && (question['options'] as List).isNotEmpty) ...[
            const SizedBox(height: 8),
            ...((question['options'] as List).asMap().entries.map((entry) {
              final isCorrect = question['correctAnswer'] == entry.value;
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(
                      isCorrect ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 16,
                      color: isCorrect ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.value.toString(),
                      style: TextStyle(
                        fontSize: 13,
                        color: isCorrect ? const Color(0xFF10B981) : const Color(0xFF64748B),
                        fontWeight: isCorrect ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            })),
          ],
        ],
      ),
    );
  }
}

// Question Dialog
class _QuestionDialog extends StatefulWidget {
  final Map<String, dynamic>? question;
  final Function(Map<String, dynamic>) onSave;

  const _QuestionDialog({this.question, required this.onSave});

  @override
  State<_QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<_QuestionDialog> {
  final _questionController = TextEditingController();
  final _explanationController = TextEditingController();
  String _type = 'mcq';
  int _points = 1;
  final List<String> _options = ['', '', '', ''];
  String _correctAnswer = '';

  @override
  void initState() {
    super.initState();
    if (widget.question != null) {
      _questionController.text = widget.question!['question'] ?? '';
      _explanationController.text = widget.question!['explanation'] ?? '';
      _type = widget.question!['type'] ?? 'mcq';
      _points = widget.question!['points'] ?? 1;
      if (widget.question!['options'] != null) {
        final opts = List<String>.from(widget.question!['options']);
        for (int i = 0; i < opts.length && i < 4; i++) {
          _options[i] = opts[i];
        }
      }
      _correctAnswer = widget.question!['correctAnswer']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _explanationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.question != null ? 'Edit Question' : 'Add Question'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Question Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'mcq', child: Text('Multiple Choice')),
                  DropdownMenuItem(value: 'true_false', child: Text('True/False')),
                  DropdownMenuItem(value: 'short_answer', child: Text('Short Answer')),
                  DropdownMenuItem(value: 'essay', child: Text('Essay')),
                  DropdownMenuItem(value: 'clinical_scenario', child: Text('Clinical Scenario (with Image)')),
                  DropdownMenuItem(value: 'clinical_video', child: Text('Clinical Video Question')),
                  DropdownMenuItem(value: 'osce_station', child: Text('OSCE/TOACS Station')),
                ],
                onChanged: (value) => setState(() => _type = value!),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _questionController,
                decoration: const InputDecoration(
                  labelText: 'Question *',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              TextField(
                controller: TextEditingController(text: _points.toString()),
                decoration: const InputDecoration(
                  labelText: 'Points',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => _points = int.tryParse(value) ?? 1,
              ),
              const SizedBox(height: 16),

              if (_type == 'mcq') ...[
                const Text('Options:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                for (int i = 0; i < 4; i++) ...[
                  TextField(
                    controller: TextEditingController(text: _options[i]),
                    decoration: InputDecoration(
                      labelText: 'Option ${i + 1}',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) => _options[i] = value,
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _correctAnswer.isEmpty ? null : _correctAnswer,
                  decoration: const InputDecoration(
                    labelText: 'Correct Answer',
                    border: OutlineInputBorder(),
                  ),
                  items: _options.where((o) => o.isNotEmpty).map((opt) {
                    return DropdownMenuItem(value: opt, child: Text(opt));
                  }).toList(),
                  onChanged: (value) => setState(() => _correctAnswer = value ?? ''),
                ),
              ] else if (_type == 'true_false') ...[
                DropdownButtonFormField<String>(
                  initialValue: _correctAnswer.isEmpty ? null : _correctAnswer,
                  decoration: const InputDecoration(
                    labelText: 'Correct Answer',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'True', child: Text('True')),
                    DropdownMenuItem(value: 'False', child: Text('False')),
                  ],
                  onChanged: (value) => setState(() => _correctAnswer = value ?? ''),
                ),
              ] else if (_type == 'short_answer') ...[
                TextField(
                  controller: TextEditingController(text: _correctAnswer),
                  decoration: const InputDecoration(
                    labelText: 'Correct Answer',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => _correctAnswer = value,
                ),
              ] else if (_type == 'clinical_scenario') ...[
                TextField(
                  controller: TextEditingController(text: _options.isNotEmpty ? _options[0] : ''),
                  decoration: const InputDecoration(
                    labelText: 'Image URL (Clinical Scenario)',
                    hintText: 'https://example.com/xray.jpg',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.image_outlined),
                  ),
                  onChanged: (value) {
                    if (_options.isEmpty) {
                      _options.add(value);
                    } else {
                      _options[0] = value;
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: TextEditingController(text: _correctAnswer),
                  decoration: const InputDecoration(
                    labelText: 'Expected Answer/Diagnosis',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  onChanged: (value) => _correctAnswer = value,
                ),
              ] else if (_type == 'clinical_video') ...[
                TextField(
                  controller: TextEditingController(text: _options.isNotEmpty ? _options[0] : ''),
                  decoration: const InputDecoration(
                    labelText: 'Video URL (Clinical Video)',
                    hintText: 'https://example.com/procedure.mp4',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.video_library_outlined),
                  ),
                  onChanged: (value) {
                    if (_options.isEmpty) {
                      _options.add(value);
                    } else {
                      _options[0] = value;
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: TextEditingController(text: _correctAnswer),
                  decoration: const InputDecoration(
                    labelText: 'Expected Answer',
                    hintText: 'What should students identify?',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  onChanged: (value) => _correctAnswer = value,
                ),
              ] else if (_type == 'osce_station') ...[
                TextField(
                  controller: TextEditingController(text: _options.isNotEmpty ? _options[0] : ''),
                  decoration: const InputDecoration(
                    labelText: 'Station Instructions',
                    hintText: 'Detailed instructions for the OSCE/TOACS station',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                  onChanged: (value) {
                    if (_options.isEmpty) {
                      _options.add(value);
                    } else {
                      _options[0] = value;
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: TextEditingController(text: _options.length > 1 ? _options[1] : ''),
                  decoration: const InputDecoration(
                    labelText: 'Marking Rubric',
                    hintText: 'Key points to assess',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  onChanged: (value) {
                    if (_options.length < 2) {
                      _options.add(value);
                    } else {
                      _options[1] = value;
                    }
                  },
                ),
              ],

              const SizedBox(height: 16),
              TextField(
                controller: _explanationController,
                decoration: const InputDecoration(
                  labelText: 'Explanation (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
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
            if (_questionController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Question text is required')),
              );
              return;
            }

            final question = {
              'type': _type,
              'question': _questionController.text,
              'points': _points,
              'explanation': _explanationController.text,
            };

            if (_type == 'mcq') {
              question['options'] = _options.where((o) => o.isNotEmpty).toList();
              question['correctAnswer'] = _correctAnswer;
            } else if (_type == 'true_false') {
              question['options'] = ['True', 'False'];
              question['correctAnswer'] = _correctAnswer;
            } else if (_type == 'short_answer') {
              question['correctAnswer'] = _correctAnswer;
            } else if (_type == 'clinical_scenario') {
              question['imageUrl'] = _options.isNotEmpty ? _options[0] : '';
              question['correctAnswer'] = _correctAnswer;
            } else if (_type == 'clinical_video') {
              question['videoUrl'] = _options.isNotEmpty ? _options[0] : '';
              question['correctAnswer'] = _correctAnswer;
            } else if (_type == 'osce_station') {
              question['instructions'] = _options.isNotEmpty ? _options[0] : '';
              question['rubric'] = _options.length > 1 ? _options[1] : '';
              question['correctAnswer'] = _correctAnswer;
            }

            widget.onSave(question);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

