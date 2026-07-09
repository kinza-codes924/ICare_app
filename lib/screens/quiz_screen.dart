import 'package:flutter/material.dart';
import 'package:icare/models/course.dart';
import 'package:icare/services/course_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';

class QuizScreen extends StatefulWidget {
  final Quiz quiz;
  final String title;
  final String? courseId;
  final String? enrollmentId;

  const QuizScreen({
    super.key,
    required this.quiz,
    required this.title,
    this.courseId,
    this.enrollmentId,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final CourseService _courseService = CourseService();
  int _currentQuestionIndex = 0;
  final Map<int, int> _selectedAnswers = {};
  bool _isFinished = false;
  bool _showReview = false;

  void _submitAnswer(int answerIndex) {
    if (_isFinished) return;
    setState(() {
      _selectedAnswers[_currentQuestionIndex] = answerIndex;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < widget.quiz.questions.length - 1) {
      setState(() => _currentQuestionIndex++);
    } else {
      _finishQuiz();
    }
  }

  void _finishQuiz() {
    int correctCount = 0;
    for (int i = 0; i < widget.quiz.questions.length; i++) {
      if (_selectedAnswers[i] == widget.quiz.questions[i].correctAnswer) {
        correctCount++;
      }
    }
    final score = (correctCount / widget.quiz.questions.length) * 100;
    final passed = score >= widget.quiz.passingScore;

    setState(() => _isFinished = true);

    // Persist result if enrollmentId is present
    if (widget.enrollmentId != null) {
      _courseService
          .submitQuizResult(widget.enrollmentId!, {
            'score': score,
            'passed': passed,
            'completedAt': DateTime.now().toIso8601String(),
          })
          .catchError((e) => debugPrint('Failed to save quiz result: $e'));
    }

    _showResultsDialog(score, passed);
  }

  void _showResultsDialog(double score, bool passed) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(passed ? 'Congratulations!' : 'Quiz Results'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              passed ? Icons.emoji_events_rounded : Icons.info_outline_rounded,
              color: passed ? Colors.orange : Colors.blue,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'You scored ${score.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              passed
                  ? 'You have successfully passed this module.'
                  : 'Keep learning and try again to improve your score.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _showReview = true;
                _currentQuestionIndex = 0;
              });
            },
            child: const Text('Review Answers'),
          ),
          if (!passed)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _isFinished = false;
                  _showReview = false;
                  _currentQuestionIndex = 0;
                  _selectedAnswers.clear();
                });
              },
              child: const Text('Retake Quiz'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to lesson/curriculum
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.quiz.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: Text('No questions available.')),
      );
    }

    final question = widget.quiz.questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / widget.quiz.questions.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFF1F5F9),
              color: AppColors.primaryColor,
              borderRadius: BorderRadius.circular(10),
              minHeight: 8,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question ${_currentQuestionIndex + 1}/${widget.quiz.questions.length}',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_showReview)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _selectedAnswers[_currentQuestionIndex] ==
                              question.correctAnswer
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _selectedAnswers[_currentQuestionIndex] ==
                              question.correctAnswer
                          ? 'Correct'
                          : 'Incorrect',
                      style: TextStyle(
                        color:
                            _selectedAnswers[_currentQuestionIndex] ==
                                question.correctAnswer
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              question.question,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: ListView.separated(
                itemCount: question.options.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final isSelected =
                      _selectedAnswers[_currentQuestionIndex] == index;
                  final isCorrect = question.correctAnswer == index;

                  Color borderColor = const Color(0xFFE2E8F0);
                  Color bgColor = Colors.white;
                  Widget? trailing;

                  if (_showReview) {
                    if (isCorrect) {
                      borderColor = Colors.green;
                      bgColor = Colors.green.withValues(alpha: 0.05);
                      trailing = const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 24,
                      );
                    } else if (isSelected && !isCorrect) {
                      borderColor = Colors.red;
                      bgColor = Colors.red.withValues(alpha: 0.05);
                      trailing = const Icon(
                        Icons.cancel,
                        color: Colors.red,
                        size: 24,
                      );
                    }
                  } else if (isSelected) {
                    borderColor = AppColors.primaryColor;
                    bgColor = AppColors.primaryColor.withValues(alpha: 0.1);
                  }

                  return InkWell(
                    onTap: _showReview ? null : () => _submitAnswer(index),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor, width: 2),
                      ),
                      child: Row(
                        children: [
                          if (!_showReview)
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primaryColor
                                      : const Color(0xFFCBD5E1),
                                  width: 2,
                                ),
                                color: isSelected
                                    ? AppColors.primaryColor
                                    : Colors.transparent,
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              question.options[index],
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight:
                                    (isSelected || (_showReview && isCorrect))
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: _showReview
                                    ? (isCorrect
                                          ? Colors.green
                                          : (isSelected
                                                ? Colors.red
                                                : const Color(0xFF334155)))
                                    : (isSelected
                                          ? AppColors.primaryColor
                                          : const Color(0xFF334155)),
                              ),
                            ),
                          ),
                          if (trailing != null) trailing,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (_currentQuestionIndex > 0) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _currentQuestionIndex--),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Previous',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed:
                        (_selectedAnswers.containsKey(_currentQuestionIndex) ||
                            _showReview)
                        ? () {
                            if (_currentQuestionIndex <
                                widget.quiz.questions.length - 1) {
                              setState(() => _currentQuestionIndex++);
                            } else if (_showReview) {
                              Navigator.pop(context);
                            } else {
                              _finishQuiz();
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _currentQuestionIndex == widget.quiz.questions.length - 1
                          ? (_showReview ? 'Finish Review' : 'Finish Quiz')
                          : 'Next Question',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
