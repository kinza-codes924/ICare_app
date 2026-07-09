import 'package:flutter/material.dart';
import 'package:icare/utils/theme.dart';
import 'package:intl/intl.dart';

class DateFilterBar extends StatelessWidget {
  final String selected; // 'all' | 'today' | '7days' | '30days' | 'custom'
  final DateTime? customDate;
  final void Function(String filter, DateTime? date) onChanged;

  const DateFilterBar({
    super.key,
    required this.selected,
    required this.onChanged,
    this.customDate,
  });

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: customDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: AppColors.primaryColor),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      onChanged('custom', picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = [
      ('all', 'All'),
      ('today', 'Today'),
      ('7days', '7 Days'),
      ('30days', '30 Days'),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...labels.map((e) {
              final isSelected = selected == e.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onChanged(e.$1, null),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryColor : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      e.$2,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              );
            }),
            GestureDetector(
              onTap: () => _pickDate(context),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: selected == 'custom' ? AppColors.primaryColor : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_month_rounded, size: 13,
                        color: selected == 'custom' ? Colors.white : const Color(0xFF64748B)),
                    const SizedBox(width: 5),
                    Text(
                      selected == 'custom' && customDate != null
                          ? DateFormat('d MMM').format(customDate!)
                          : 'Calendar',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected == 'custom' ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper: filter a list of items by date.
/// [getDate] extracts the DateTime from each item.
List<T> applyDateFilter<T>(List<T> items, DateTime Function(T) getDate, String filter, DateTime? customDate) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  switch (filter) {
    case 'today':
      return items.where((item) {
        final d = getDate(item);
        return DateTime(d.year, d.month, d.day) == today;
      }).toList();
    case '7days':
      final cutoff = today.subtract(const Duration(days: 6));
      return items.where((item) {
        final d = getDate(item);
        return !DateTime(d.year, d.month, d.day).isBefore(cutoff);
      }).toList();
    case '30days':
      final cutoff = today.subtract(const Duration(days: 29));
      return items.where((item) {
        final d = getDate(item);
        return !DateTime(d.year, d.month, d.day).isBefore(cutoff);
      }).toList();
    case 'custom':
      if (customDate == null) return items;
      final pick = DateTime(customDate.year, customDate.month, customDate.day);
      return items.where((item) {
        final d = getDate(item);
        return DateTime(d.year, d.month, d.day) == pick;
      }).toList();
    default:
      return items;
  }
}
