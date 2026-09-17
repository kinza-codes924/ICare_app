import 'package:easy_localization/easy_localization.dart';
import 'package:icare/widgets/drag_scroll.dart';
import 'package:flutter/material.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';
import 'package:icare/services/reminder_service.dart';

/// Repeat choices offered on the Add Reminder screen.
const List<(String, String)> _repeatOptions = [
  ('none', 'Once'),
  ('daily', 'Daily'),
  ('weekly', 'Weekly'),
  ('monthly', 'Monthly'),
  ('custom', 'Specific days'),
];

/// Weekday numbers match DateTime.weekday, so a stored day needs no mapping.
const List<(int, String)> _weekdays = [
  (1, 'Mon'), (2, 'Tue'), (3, 'Wed'), (4, 'Thu'),
  (5, 'Fri'), (6, 'Sat'), (7, 'Sun'),
];

class CreateReminder extends StatefulWidget {
  const CreateReminder({super.key, this.isEdit = false});
  final bool isEdit;

  @override
  State<CreateReminder> createState() => _CreateReminderState();
}

class _CreateReminderState extends State<CreateReminder> {
  final ReminderService _reminderService = ReminderService();
  final _labelController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  /// How often the reminder repeats.
  ///
  /// A medicine taken at 11pm every night should be set once, not entered
  /// again each day -- which is what "Once" alone forced. 'custom' carries the
  /// chosen weekdays in _selectedDays.
  String _recurrence = 'none';
  final Set<int> _selectedDays = {}; // 1 = Mon ... 7 = Sun, as DateTime uses
  bool _isSubmitting = false;

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (time != null) setState(() => _selectedTime = time);
  }

  Future<void> _submit() async {
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      _snack('Please enter a reminder label');
      return;
    }
    if (_selectedDate == null) {
      _snack('Please select a date');
      return;
    }
    if (_selectedTime == null) {
      _snack('Please select a time');
      return;
    }

    setState(() => _isSubmitting = true);

    // Build as local time then convert to UTC so Google Calendar shows correct time
    final dtLocal = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    final dt = dtLocal.toUtc();

    final result = await _reminderService.createReminder({
      'title': label,
      'type': 'self_created',
      'scheduledFor': dt.toIso8601String(),
      'remindBeforeMinutes': 15,
      // 'custom' is not a value the backend stores, so specific weekdays go
      // as a weekly repeat plus the days themselves.
      'recurrence': _recurrence == 'custom' ? 'weekly' : _recurrence,
      if (_recurrence == 'custom')
        'repeatDays': (_selectedDays.toList()..sort()),
    });

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder added!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        _snack(result['message'] ?? 'Failed to create reminder');
      }
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final String dateLabel = _selectedDate == null
        ? 'Select Date'
        : DateFormat('EEE, dd MMM yyyy').format(_selectedDate!);
    final String timeLabel = _selectedTime == null
        ? 'Select Time'
        : _selectedTime!.format(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        leading: const CustomBackButton(),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.isEdit ? 'Edit Reminder' : 'Add Reminder',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      body: DragScroll(
        builder: (context, dragScrollCtrl) => SingleChildScrollView(
          controller: dragScrollCtrl,
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header icon
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.add_alarm_rounded,
                            color: AppColors.primaryColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isEdit ? 'Edit Reminder' : 'New Reminder',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const Text(
                              'In-app notification will be sent',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 24),

                    // Label
                    _fieldLabel('Label'),
                    const SizedBox(height: 8),
                    TextField(
                      maxLength: 150,
                      controller: _labelController,
                      decoration: _inputDecoration(
                        'e.g. Take morning medicine',
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Date
                    _fieldLabel('Date'),
                    const SizedBox(height: 8),
                    _PickerButton(
                      label: dateLabel,
                      icon: Icons.calendar_today_rounded,
                      isPlaceholder: _selectedDate == null,
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 20),

                    // Time
                    _fieldLabel('Time'),
                    const SizedBox(height: 8),
                    _PickerButton(
                      label: timeLabel,
                      icon: Icons.access_time_rounded,
                      isPlaceholder: _selectedTime == null,
                      onTap: _pickTime,
                    ),
                    const SizedBox(height: 20),

                    // Repeat
                    _fieldLabel('Repeat'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _repeatOptions.map((opt) {
                        final value = opt.$1;
                        final selected = _recurrence == value;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() {
                            _recurrence = value;
                            if (value != 'custom') _selectedDays.clear();
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primaryColor
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primaryColor
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              opt.$2,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    // Weekday picker, shown only when specific days are wanted
                    if (_recurrence == 'custom') ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _weekdays.map((d) {
                          final day = d.$1;
                          final on = _selectedDays.contains(day);
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() {
                              if (on) {
                                _selectedDays.remove(day);
                              } else {
                                _selectedDays.add(day);
                              }
                            }),
                            child: Container(
                              width: 46,
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: on
                                    ? AppColors.primaryColor
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: on
                                      ? AppColors.primaryColor
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(
                                d.$2,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: on
                                      ? Colors.white
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 28),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submit,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                widget.isEdit
                                    ? Icons.edit_rounded
                                    : Icons.add_alarm_rounded,
                              ),
                        label: Text(
                          _isSubmitting
                              ? 'Saving...'
                              : (widget.isEdit
                                    ? 'Update Reminder'
                                    : 'Add Reminder'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Color(0xFF374151),
    ),
  );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
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
      borderSide: BorderSide(color: AppColors.primaryColor, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

class _PickerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPlaceholder;
  final VoidCallback onTap;

  const _PickerButton({
    required this.label,
    required this.icon,
    required this.isPlaceholder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isPlaceholder
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF0F172A),
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF94A3B8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
