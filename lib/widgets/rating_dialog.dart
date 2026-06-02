import 'package:flutter/material.dart';

class RatingDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final String satisfactionQuestion;
  final Function(int rating, bool satisfied, String comment) onSubmit;

  const RatingDialog({
    super.key,
    required this.title,
    required this.subtitle,
    this.satisfactionQuestion = 'Are you satisfied with the service?',
    required this.onSubmit,
  });

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _rating = 0;
  bool? _satisfied;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating')),
      );
      return;
    }
    if (_satisfied == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer the satisfaction question')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(_rating, _satisfied!, _commentController.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(maxWidth: isMobile ? 400 : 500),
        padding: EdgeInsets.all(isMobile ? 20 : 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.rate_review_rounded, size: 40, color: Color(0xFF10B981)),
              ),
              const SizedBox(height: 20),
              Text(widget.title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(widget.subtitle,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              // Star rating
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  return GestureDetector(
                    onTap: () => setState(() => _rating = starIndex),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        _rating >= starIndex ? Icons.star_rounded : Icons.star_border_rounded,
                        size: isMobile ? 40 : 48,
                        color: _rating >= starIndex ? const Color(0xFFF59E0B) : const Color(0xFFD1D5DB),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              // Satisfaction question
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.satisfactionQuestion,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _satisfied = true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _satisfied == true ? const Color(0xFF10B981) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _satisfied == true ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                                width: 1.5,
                              ),
                            ),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.thumb_up_rounded, size: 18,
                                  color: _satisfied == true ? Colors.white : const Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Text('Yes', style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _satisfied == true ? Colors.white : const Color(0xFF374151),
                              )),
                            ]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _satisfied = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _satisfied == false ? const Color(0xFFEF4444) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _satisfied == false ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
                                width: 1.5,
                              ),
                            ),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.thumb_down_rounded, size: 18,
                                  color: _satisfied == false ? Colors.white : const Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Text('No', style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _satisfied == false ? Colors.white : const Color(0xFF374151),
                              )),
                            ]),
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Review text
              TextField(
                controller: _commentController,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Share your experience (optional)',
                  hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981), width: 2)),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: const Text('Skip', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitRating,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                        : const Text('Submit', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool?> showRatingDialog({
  required BuildContext context,
  required String title,
  required String subtitle,
  String satisfactionQuestion = 'Are you satisfied with the service?',
  required Function(int rating, bool satisfied, String comment) onSubmit,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => RatingDialog(
      title: title,
      subtitle: subtitle,
      satisfactionQuestion: satisfactionQuestion,
      onSubmit: onSubmit,
    ),
  );
}
