import 'dart:async';
import 'package:flutter/material.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';

class QuizTakeScreen extends StatefulWidget {
  final Map<String, dynamic> quiz;
  final String enrollmentId;

  const QuizTakeScreen({
    super.key,
    required this.quiz,
    required this.enrollmentId,
  });

  @override
  State<QuizTakeScreen> createState() => _QuizTakeScreenState();
}

class _QuizTakeScreenState extends State<QuizTakeScreen> {
  final LmsService _lmsService = LmsService();

  // Quiz data
  late List<dynamic> _questions;
  late String _quizId;
  late String _quizTitle;
  late int _timeLimitSeconds;

  // State
  int _currentIndex = 0;
  final Map<int, dynamic> _answers = {}; // questionIndex -> answer (int for MCQ, String for text)
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _showPalette = false;
  bool _quizCompleted = false;
  Map<String, dynamic>? _result;

  // Timer
  Timer? _timer;
  int _secondsRemaining = 0;
  final int _timeSpentSeconds = 0;
  final Stopwatch _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _quizId = widget.quiz['_id']?.toString() ?? widget.quiz['id']?.toString() ?? '';
    _quizTitle = widget.quiz['title'] ?? 'Quiz';
    final timeLimitMinutes = (widget.quiz['timeLimit'] as num?)?.toInt() ?? 0;
    _timeLimitSeconds = timeLimitMinutes * 60;

    // Load questions from the quiz data or fetch fresh
    final rawQuestions = widget.quiz['questions'];
    if (rawQuestions is List && rawQuestions.isNotEmpty) {
      _questions = rawQuestions;
      _isLoading = false;
      _startTimerAndStopwatch();
    } else {
      _fetchQuizDetails();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  Future<void> _fetchQuizDetails() async {
    try {
      final data = await _lmsService.getQuiz(_quizId);
      final q = data['quiz'] ?? data;
      if (mounted) {
        setState(() {
          _questions = (q['questions'] as List?) ?? [];
          final tl = (q['timeLimit'] as num?)?.toInt() ?? 0;
          if (tl > 0) _timeLimitSeconds = tl * 60;
          _isLoading = false;
        });
        _startTimerAndStopwatch();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _questions = [];
          _isLoading = false;
        });
        _startTimerAndStopwatch();
      }
    }
  }

  void _startTimerAndStopwatch() {
    _stopwatch.start();
    if (_timeLimitSeconds > 0) {
      _secondsRemaining = _timeLimitSeconds;
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() {
          _secondsRemaining--;
          if (_secondsRemaining <= 0) {
            t.cancel();
            _submitQuiz(autoSubmit: true);
          }
        });
      });
    }
  }

  String get _formattedTime {
    final mins = _secondsRemaining ~/ 60;
    final secs = _secondsRemaining % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  bool get _hasTimeLimit => _timeLimitSeconds > 0;

  Color get _timerColor {
    if (!_hasTimeLimit) return AppColors.primaryColor;
    if (_secondsRemaining <= 60) return const Color(0xFFEF4444);
    if (_secondsRemaining <= 5 * 60) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  // ── Question helpers ─────────────────────────────────────────────────────

  String _questionType(dynamic q) {
    return (q['type'] ?? q['questionType'] ?? 'MCQ').toString().toUpperCase();
  }

  List<dynamic> _options(dynamic q) {
    return (q['options'] as List?) ?? (q['choices'] as List?) ?? [];
  }

  bool _isAnswered(int index) => _answers.containsKey(index);

  int get _answeredCount => _answers.length;

  // ── Navigation ───────────────────────────────────────────────────────────

  void _goToQuestion(int index) {
    setState(() {
      _currentIndex = index;
      _showPalette = false;
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
    }
  }

  void _prevQuestion() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  // ── Submit ───────────────────────────────────────────────────────────────

  Future<void> _submitQuiz({bool autoSubmit = false}) async {
    if (!autoSubmit) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Submit Quiz', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Text(
            'You have answered $_answeredCount of ${_questions.length} questions.\n\nAre you sure you want to submit?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Submit', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    _timer?.cancel();
    _stopwatch.stop();
    setState(() => _isSubmitting = true);

    // Build answers list
    final answersPayload = <Map<String, dynamic>>[];
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final qId = q['_id']?.toString() ?? q['id']?.toString() ?? i.toString();
      final answer = _answers[i];
      if (answer != null) {
        answersPayload.add({
          'questionId': qId,
          'answer': answer is int ? _options(q)[answer] : answer,
          'selectedOptionIndex': answer is int ? answer : null,
        });
      }
    }

    final timeSpent = _stopwatch.elapsed.inSeconds;

    try {
      final result = await _lmsService.submitQuiz(
        quizId: _quizId,
        answers: answersPayload,
        timeSpent: timeSpent,
      );
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _quizCompleted = true;
          _result = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: ${e.toString()}')),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: AppColors.primaryColor,
          leading: const CustomBackButton(color: Colors.white),
          title: Text(_quizTitle, style: const TextStyle(color: Colors.white)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_quizCompleted) {
      return _buildResultScreen();
    }

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: AppColors.primaryColor,
          leading: const CustomBackButton(color: Colors.white),
          title: Text(_quizTitle, style: const TextStyle(color: Colors.white)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.quiz_outlined, size: 64, color: Color(0xFF94A3B8)),
              const SizedBox(height: 16),
              const Text('No questions available',
                  style: TextStyle(fontSize: 16, color: Color(0xFF64748B))),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor),
                child: const Text('Go Back', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: _showPalette ? _buildPaletteView() : _buildQuestionView(),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primaryColor,
      elevation: 0,
      leading: const CustomBackButton(color: Colors.white),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_quizTitle,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text('${_currentIndex + 1} / ${_questions.length}',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
      actions: [
        // Timer
        if (_hasTimeLimit)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _timerColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _timerColor.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.timer_rounded, color: _timerColor, size: 15),
                const SizedBox(width: 4),
                Text(_formattedTime,
                    style: TextStyle(
                        color: _timerColor, fontWeight: FontWeight.w800, fontSize: 13)),
              ],
            ),
          ),
        // Question palette button
        IconButton(
          onPressed: () => setState(() => _showPalette = !_showPalette),
          icon: Icon(
            _showPalette ? Icons.close_rounded : Icons.grid_view_rounded,
            color: Colors.white,
          ),
          tooltip: 'Question Palette',
        ),
      ],
    );
  }

  // ── Question View ────────────────────────────────────────────────────────

  Widget _buildQuestionView() {
    final question = _questions[_currentIndex];
    final qType = _questionType(question);
    final options = _options(question);
    final selectedAnswer = _answers[_currentIndex];

    return Column(
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: (_currentIndex + 1) / _questions.length,
          backgroundColor: const Color(0xFFE2E8F0),
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
          minHeight: 4,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question header
                Container(
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('Q ${_currentIndex + 1}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryColor)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(qType,
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                          ),
                          const Spacer(),
                          if ((question['marks'] ?? question['points']) != null)
                            Text(
                              '${question['marks'] ?? question['points']} pts',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        question['text']?.toString() ??
                            question['question']?.toString() ??
                            question['questionText']?.toString() ??
                            'Question',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Answer section
                if (qType == 'MCQ' || options.isNotEmpty) ...[
                  const Text('Select an answer:',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                  const SizedBox(height: 10),
                  ...options.asMap().entries.map((entry) {
                    final optionIndex = entry.key;
                    final option = entry.value;
                    final optionText = option is Map
                        ? (option['text'] ?? option['value'] ?? option['label'] ?? '').toString()
                        : option.toString();
                    final isSelected = selectedAnswer == optionIndex;

                    return GestureDetector(
                      onTap: () => setState(() => _answers[_currentIndex] = optionIndex),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryColor.withValues(alpha: 0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primaryColor
                                : const Color(0xFFE2E8F0),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? AppColors.primaryColor : Colors.transparent,
                                border: Border.all(
                                  color: isSelected ? AppColors.primaryColor : const Color(0xFFCBD5E1),
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(optionText,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? AppColors.primaryColor : const Color(0xFF0F172A),
                                  )),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ] else ...[
                  // Text answer
                  const Text('Your answer:',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                  const SizedBox(height: 10),
                  TextField(
                    maxLines: 5,
                    onChanged: (v) => setState(() => _answers[_currentIndex] = v.trim()),
                    controller: TextEditingController(
                        text: _answers[_currentIndex]?.toString() ?? ''),
                    decoration: InputDecoration(
                      hintText: 'Write your answer here...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: Colors.white,
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
                        borderSide: const BorderSide(color: AppColors.primaryColor, width: 1.5),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 100), // space for bottom nav
              ],
            ),
          ),
        ),
        // Bottom navigation
        _buildBottomNav(),
      ],
    );
  }

  Widget _buildBottomNav() {
    final isLast = _currentIndex == _questions.length - 1;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: Row(
        children: [
          // Prev
          OutlinedButton.icon(
            onPressed: _currentIndex > 0 ? _prevQuestion : null,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Prev'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryColor,
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const Spacer(),
          // Answered indicator
          Text(
            '$_answeredCount/${_questions.length} answered',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          // Next or Submit
          if (!isLast)
            ElevatedButton.icon(
              onPressed: _nextQuestion,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Next', style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : () => _submitQuiz(),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(_isSubmitting ? 'Submitting...' : 'Submit',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
        ],
      ),
    );
  }

  // ── Question Palette ─────────────────────────────────────────────────────

  Widget _buildPaletteView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Question Palette',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _showPalette = false),
                    child: const Text('Close'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _legendChip(const Color(0xFF10B981), 'Answered'),
                  const SizedBox(width: 12),
                  _legendChip(const Color(0xFFE2E8F0), 'Not Answered'),
                  const SizedBox(width: 12),
                  _legendChip(AppColors.primaryColor, 'Current'),
                ],
              ),
              const SizedBox(height: 4),
              Text('$_answeredCount of ${_questions.length} answered',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemCount: _questions.length,
            itemBuilder: (context, index) {
              final isCurrent = index == _currentIndex;
              final isAnswered = _isAnswered(index);
              Color bg;
              Color fg;
              if (isCurrent) {
                bg = AppColors.primaryColor;
                fg = Colors.white;
              } else if (isAnswered) {
                bg = const Color(0xFF10B981);
                fg = Colors.white;
              } else {
                bg = const Color(0xFFF1F5F9);
                fg = const Color(0xFF64748B);
              }

              return GestureDetector(
                onTap: () => _goToQuestion(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isCurrent
                        ? [BoxShadow(color: AppColors.primaryColor.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))]
                        : null,
                  ),
                  child: Center(
                    child: Text('${index + 1}',
                        style: TextStyle(
                            color: fg, fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : () => _submitQuiz(),
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: const Text('Submit Quiz', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendChip(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      ],
    );
  }

  // ── Result Screen ────────────────────────────────────────────────────────

  Widget _buildResultScreen() {
    final result = _result ?? {};
    final attempt = result['attempt'] ?? result;
    final score = attempt['score'] ?? attempt['percentage'] ?? 0;
    final passed = attempt['passed'] == true;
    final totalQuestions = _questions.length;
    final correctCount = attempt['correctCount'] ?? attempt['correct'] ?? 0;
    final breakdown = attempt['breakdown'] as List? ?? attempt['answers'] as List? ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Result header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 32,
              left: 24,
              right: 24,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: passed
                    ? [const Color(0xFF10B981), const Color(0xFF059669)]
                    : [const Color(0xFFEF4444), const Color(0xFFDC2626)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    passed ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  passed ? 'Congratulations!' : 'Better Luck Next Time',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  passed ? 'You passed the quiz!' : 'You did not pass this time.',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 20),
                // Score circle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'Score: $score%',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats row
                  Row(
                    children: [
                      Expanded(child: _statCard('Total', totalQuestions.toString(), Icons.list_alt_rounded, AppColors.primaryColor)),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard('Correct', correctCount.toString(), Icons.check_circle_rounded, const Color(0xFF10B981))),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard('Wrong',
                          (totalQuestions - (correctCount is int ? correctCount : 0)).toString(),
                          Icons.cancel_rounded, const Color(0xFFEF4444))),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Per-question breakdown (if available)
                  if (breakdown.isNotEmpty) ...[
                    const Text('Question Breakdown',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    const SizedBox(height: 12),
                    ...breakdown.asMap().entries.map((e) => _buildBreakdownItem(e.key, e.value)),
                    const SizedBox(height: 16),
                  ] else if (_questions.isNotEmpty) ...[
                    const Text('Your Answers',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    const SizedBox(height: 12),
                    ..._questions.asMap().entries.map((e) {
                      final q = e.value;
                      final answered = _answers[e.key];
                      final options = _options(q);
                      final answerText = answered is int && answered < options.length
                          ? (options[answered] is Map
                              ? (options[answered]['text'] ?? options[answered]['value'] ?? '').toString()
                              : options[answered].toString())
                          : answered?.toString() ?? 'Not answered';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Q${e.key + 1}. ${q['text'] ?? q['question'] ?? ''}',
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.person_rounded, size: 14, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text('Your answer: $answerText',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: const Text('Go Back', style: TextStyle(fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryColor,
                            side: const BorderSide(color: AppColors.primaryColor),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _answers.clear();
                              _currentIndex = 0;
                              _quizCompleted = false;
                              _result = null;
                              _showPalette = false;
                            });
                            _startTimerAndStopwatch();
                          },
                          icon: const Icon(Icons.replay_rounded, size: 18),
                          label: const Text('Retake', style: TextStyle(fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(int index, dynamic item) {
    final isCorrect = item['isCorrect'] == true || item['correct'] == true;
    final questionText = item['question']?.toString() ?? item['text']?.toString() ?? 'Question ${index + 1}';
    final userAnswer = item['userAnswer']?.toString() ?? item['answer']?.toString() ?? 'N/A';
    final correctAnswer = item['correctAnswer']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : const Color(0xFFEF4444).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Q${index + 1}. $questionText',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your answer: $userAnswer',
                        style: TextStyle(
                            fontSize: 12,
                            color: isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            fontWeight: FontWeight.w600)),
                    if (!isCorrect && correctAnswer.isNotEmpty)
                      Text('Correct: $correctAnswer',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
