import 'dart:async';
import 'package:flutter/material.dart';
import '../services/appointment_service.dart';
import '../models/appointment_detail.dart';
import '../utils/shared_pref.dart';

/// Wraps the app and polls every 30 seconds for appointments within 5 minutes.
/// Shows an in-app banner reminder for both doctor and patient.
class AppointmentReminderListener extends StatefulWidget {
  final Widget child;

  const AppointmentReminderListener({super.key, required this.child});

  @override
  State<AppointmentReminderListener> createState() =>
      _AppointmentReminderListenerState();
}

class _AppointmentReminderListenerState
    extends State<AppointmentReminderListener> {
  Timer? _timer;
  final Set<String> _shownReminders = {}; // key = "apptId_mins"
  final AppointmentService _service = AppointmentService();
  final SharedPref _sharedPref = SharedPref();

  // Reminder windows in minutes
  static const List<int> _reminderWindows = [10, 5];

  @override
  void initState() {
    super.initState();
    // Start polling after a short delay so the app fully loads first
    Future.delayed(const Duration(seconds: 5), _startPolling);
  }

  void _startPolling() {
    if (!mounted) return;
    _checkAppointments(); // immediate check
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _checkAppointments();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkAppointments() async {
    try {
      // Only run for logged-in users
      final user = await _sharedPref.getUserData();
      if (user == null) return;

      final result = await _service.getMyAppointmentsDetailed();
      final appointments = result['appointments'] as List<AppointmentDetail>? ?? [];

      final now = DateTime.now();

      for (final appt in appointments) {
        // Only remind for confirmed appointments
        if (appt.status.toLowerCase() != 'confirmed') continue;

        // Already shown reminder for this appointment? Skip.
        if (_shownReminders.contains(appt.id)) continue;

        // Parse appointment datetime: combine date + timeSlot
        final apptDateTime = _parseApptDateTime(appt.date, appt.timeSlot);
        if (apptDateTime == null) continue;

        final diff = apptDateTime.difference(now);

        // Fire at each reminder window
        for (final window in _reminderWindows) {
          final key = '${appt.id}_$window';
          if (_shownReminders.contains(key)) continue;
          // Within this window and not past
          if (diff.inSeconds > 0 && diff.inMinutes <= window) {
            _shownReminders.add(key);
            _showReminder(appt, diff.inMinutes);
            break; // only one banner at a time per appointment
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Reminder check failed: $e');
    }
  }

  /// Parse the appointment datetime from date + timeSlot string like "09:00 AM"
  DateTime? _parseApptDateTime(DateTime date, String timeSlot) {
    try {
      if (timeSlot.isEmpty) return date;

      // Try parsing "HH:MM AM/PM" or "HH:MM"
      final parts = timeSlot.trim().toUpperCase().split(' ');
      final timeParts = parts[0].split(':');
      if (timeParts.length < 2) return date;

      int hour = int.parse(timeParts[0]);
      final int minute = int.parse(timeParts[1]);

      if (parts.length > 1) {
        final meridiem = parts[1];
        if (meridiem == 'PM' && hour != 12) hour += 12;
        if (meridiem == 'AM' && hour == 12) hour = 0;
      }

      return DateTime(date.year, date.month, date.day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  void _showReminder(AppointmentDetail appt, int minsLeft) {
    if (!mounted) return;

    final isZero = minsLeft == 0;
    final timeText = isZero ? 'starting now!' : 'in $minsLeft minute${minsLeft == 1 ? '' : 's'}!';
    final otherParty = appt.doctor?.name ?? appt.patient?.name ?? 'your appointment';

    // Show as a persistent top banner using OverlayEntry
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _ReminderBanner(
        message: 'Appointment with $otherParty $timeText',
        onDismiss: () {
          try {
            entry.remove();
          } catch (_) {}
        },
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          Overlay.of(context).insert(entry);
          // Auto-dismiss after 15 seconds
          Future.delayed(const Duration(seconds: 15), () {
            try {
              entry.remove();
            } catch (_) {}
          });
        } catch (e) {
          debugPrint('⚠️ Could not show reminder overlay: $e');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ReminderBanner extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ReminderBanner({required this.message, required this.onDismiss});

  @override
  State<_ReminderBanner> createState() => _ReminderBannerState();
}

class _ReminderBannerState extends State<_ReminderBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnim,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A73E8), Color(0xFF0D47A1)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.alarm_rounded,
                        color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Appointment Reminder',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.message,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white70, size: 20),
                      onPressed: widget.onDismiss,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
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
}
