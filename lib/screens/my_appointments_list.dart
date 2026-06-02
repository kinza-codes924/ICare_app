import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:icare/models/appointment_detail.dart';
import 'package:icare/models/user.dart';
import 'package:icare/screens/profile_or_appointement_view.dart';
import 'package:icare/screens/lab_list.dart';
import 'package:icare/screens/video_call.dart';
import 'package:icare/screens/consultation_chat_screen_v2.dart';
import 'package:icare/services/appointment_service.dart';
import 'package:icare/services/consultation_service.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/widgets/rating_dialog.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:intl/intl.dart';

class MyAppointmentsListScreen extends StatefulWidget {
  const MyAppointmentsListScreen({super.key});

  @override
  State<MyAppointmentsListScreen> createState() =>
      _MyAppointmentsListScreenState();
}

class _MyAppointmentsListScreenState extends State<MyAppointmentsListScreen> {
  final AppointmentService _appointmentService = AppointmentService();
  List<AppointmentDetail> _appointments = [];
  bool _isLoading = true;
  User? _currentUser;
  Timer? _reminderTimer;
  final Set<String> _notifiedAppointments = {};

  @override
  void initState() {
    super.initState();
    _loadAppointments();
    _startReminderTimer();
  }

  void _startReminderTimer() {
    _reminderTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _checkUpcomingReminders();
    });
  }

  void _checkUpcomingReminders() {
    final now = DateTime.now();
    for (final appt in _appointments) {
      final status = appt.status.toLowerCase();
      if (status != 'confirmed' && status != 'pending') continue;
      if (_notifiedAppointments.contains(appt.id)) continue;

      try {
        final timeStr = appt.timeSlot;
        final parts = timeStr.split(' ');
        final timeParts = parts[0].split(':');
        int hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final isPm = parts.length > 1 && parts[1].toUpperCase() == 'PM';
        if (isPm && hour != 12) hour += 12;
        if (!isPm && hour == 12) hour = 0;

        final apptTime = DateTime(
          appt.date.year, appt.date.month, appt.date.day, hour, minute,
        );
        final diff = apptTime.difference(now).inMinutes;

        if (diff >= 0 && diff <= 5) {
          _notifiedAppointments.add(appt.id);
          _showReminderNotification(appt, diff);
        }
      } catch (_) {}
    }
  }

  void _showReminderNotification(AppointmentDetail appt, int minutesLeft) {
    if (!mounted) return;
    final msg = minutesLeft == 0
        ? 'Your appointment is starting now!'
        : 'Your appointment starts in $minutesLeft minute${minutesLeft == 1 ? '' : 's'}!';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.alarm_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(msg, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                  Text('Dr. ${appt.doctorName} • ${appt.timeSlot}',
                      style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF7C3AED),
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }

  Future<void> _rateDoctor(AppointmentDetail appointment) async {
    await showRatingDialog(
      context: context,
      title: 'Rate Your Experience',
      subtitle: 'How was your appointment with ${appointment.doctorName}?',
      onSubmit: (rating, satisfied, comment) async {
        await _appointmentService.rateAppointment(
          appointmentId: appointment.id,
          rating: rating,
          comment: comment,
        );
      },
    );
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);
    _currentUser ??= await SharedPref().getUserData();

    final result = await _appointmentService.getMyAppointmentsDetailed();

    if (result['success']) {
      setState(() {
        _appointments = result['appointments'] as List<AppointmentDetail>;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result['message'])));
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return const Color(0xFF10B981);
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'cancelled':
        return const Color(0xFFEF4444);
      case 'completed':
        return const Color(0xFF3B82F6);
      case 'in_progress':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Icons.check_circle_rounded;
      case 'pending':
        return Icons.schedule_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      case 'completed':
        return Icons.task_alt_rounded;
      case 'in_progress':
        return Icons.video_call_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  /// Returns effective display status:
  /// If appointment is confirmed/pending but date+time has passed → show as 'completed'
  String _effectiveStatus(AppointmentDetail appointment) {
    final raw = appointment.status.toLowerCase();
    // These statuses must never be overridden by time logic
    if (raw == 'cancelled' || raw == 'completed') return raw;

    // If in_progress but appointment was more than 3 hours ago → treat as completed
    // This handles the case where browser was closed without ending the consultation
    if (raw == 'in_progress') {
      try {
        final timeStr = appointment.timeSlot;
        final parts = timeStr.split(' ');
        final timeParts = parts[0].split(':');
        int hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final isPm = parts.length > 1 && parts[1].toUpperCase() == 'PM';
        if (isPm && hour != 12) hour += 12;
        if (!isPm && hour == 12) hour = 0;
        final apptDateTime = DateTime(
          appointment.date.year, appointment.date.month, appointment.date.day,
          hour, minute,
        );
        // If appointment started more than 3 hours ago, it's stale — show as completed
        if (DateTime.now().difference(apptDateTime).inHours >= 3) {
          return 'completed';
        }
      } catch (_) {
        // If parsing fails, keep in_progress
      }
      return raw;
    }

    // Parse appointment date + time slot to get exact datetime
    try {
      final timeStr = appointment.timeSlot; // e.g. "10:30 AM"
      final parts = timeStr.split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final isPm = parts.length > 1 && parts[1].toUpperCase() == 'PM';
      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;

      final appointmentDateTime = DateTime(
        appointment.date.year,
        appointment.date.month,
        appointment.date.day,
        hour,
        minute,
      );

      if (appointmentDateTime.isBefore(DateTime.now())) {
        return 'completed';
      }
    } catch (_) {
      // If time parsing fails, fall back to date-only check
      if (appointment.date.isBefore(DateTime.now())) {
        return 'completed';
      }
    }

    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Utils.windowWidth(context) > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: CustomBackButton(),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: CustomText(
          text: "Patient Bookings".tr(),
          fontFamily: "Gilroy-Bold",
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF0F172A),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (ctx) => LabsListScreen()),
                );
              },
              icon: const Icon(Icons.biotech_rounded, size: 18),
              label: Text('Book Lab Test'.tr()),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryColor,
                backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _appointments.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.calendar_today_rounded,
                      size: 64,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No appointments yet'.tr(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Book an appointment with a doctor'.tr(),
                    style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAppointments,
              child: ListView.builder(
                padding: EdgeInsets.all(isDesktop ? 24 : 16),
                itemCount: _appointments.length,
                itemBuilder: (context, index) {
                  final appointment = _appointments[index];
                  final effectiveStatus = _effectiveStatus(appointment);
                  final statusColor = _getStatusColor(effectiveStatus);
                  final isPast = appointment.date.isBefore(DateTime.now());

                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => ProfileOrAppointmentViewScreen(
                            appointment: appointment,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Header with status
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  statusColor.withValues(alpha: 0.1),
                                  statusColor.withValues(alpha: 0.05),
                                ],
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(24),
                                topRight: Radius.circular(24),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _getStatusIcon(effectiveStatus),
                                    color: statusColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        effectiveStatus.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: statusColor,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat(
                                          'EEEE, MMM dd, yyyy',
                                        ).format(appointment.date),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isPast)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF64748B,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Past'.tr(),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Doctor Info
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: AppColors.primaryColor
                                          .withValues(alpha: 0.1),
                                      child: Text(
                                        appointment.doctorName.isNotEmpty
                                            ? appointment.doctorName
                                                  .substring(0, 1)
                                                  .toUpperCase()
                                            : 'D',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primaryColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            appointment.doctorName,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            appointment.doctorEmail,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 20),
                                const Divider(),
                                const SizedBox(height: 20),

                                // Time Slot
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF8B5CF6,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.access_time_rounded,
                                        size: 20,
                                        color: Color(0xFF8B5CF6),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Time Slot'.tr(),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          appointment.timeSlot,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF8B5CF6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                // Join Video Call — confirmed appointments
                                if (effectiveStatus == 'confirmed') ...[
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => VideoCall(
                                              channelName: appointment.id,
                                              remoteUserName: appointment.doctorName,
                                              appointmentId: appointment.id,
                                              currentUserName: _currentUser?.name ?? '',
                                              currentUserId: _currentUser?.id ?? '',
                                            ),
                                          ),
                                        ).then((_) => _loadAppointments());
                                      },
                                      icon: const Icon(Icons.video_call_rounded, size: 20),
                                      label: Text(
                                        'Join Video Call'.tr(),
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                      ),
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

                                // Rate Doctor button (completed appointments)
                                if (effectiveStatus == 'completed') ...[
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _rateDoctor(appointment),
                                      icon: const Icon(Icons.star_rounded, size: 18, color: Color(0xFFF59E0B)),
                                      label: Text(
                                        'Rate Doctor'.tr(),
                                        style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFF59E0B)),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        side: const BorderSide(color: Color(0xFFF59E0B)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ],

                                // Consultation in Progress — Rejoin button
                                if (appointment.status.toLowerCase() == 'in_progress') ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.video_call_rounded, color: Color(0xFF8B5CF6), size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Consultation in Progress'.tr(),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF8B5CF6),
                                            ),
                                          ),
                                        ),
                                        ElevatedButton(
                                          onPressed: () async {
                                            // Show loading
                                            showDialog(
                                              context: context,
                                              barrierDismissible: false,
                                              builder: (_) => const Center(child: CircularProgressIndicator()),
                                            );

                                            try {
                                              print('🔄 PATIENT REJOIN: Fetching consultation for appointment ${appointment.id}');
                                              final consultationService = ConsultationService();
                                              final result = await consultationService.getConsultationByAppointmentId(appointment.id);

                                              print('📥 REJOIN RESPONSE: $result');

                                              if (mounted) Navigator.pop(context); // close loading

                                              if (result['success'] == true && result['consultation'] != null) {
                                                final consultationId = result['consultation']['_id']?.toString() ?? '';
                                                print('✅ Found consultation: $consultationId');

                                                if (consultationId.isEmpty) {
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text('Consultation ID not found. Please contact support.'),
                                                        backgroundColor: Colors.orange,
                                                      ),
                                                    );
                                                  }
                                                  return;
                                                }

                                                // Navigate to chat with existing consultation
                                                if (mounted) {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => ConsultationChatScreenV2(
                                                        appointment: appointment,
                                                        isDoctor: false,
                                                        currentUserId: _currentUser?.id ?? '',
                                                        currentUserName: _currentUser?.name ?? '',
                                                        consultationId: consultationId,
                                                      ),
                                                    ),
                                                  ).then((_) => _loadAppointments());
                                                }
                                              } else {
                                                // Consultation not found
                                                print('❌ Consultation not found for appointment ${appointment.id}');
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text(result['message']?.toString() ?? 'Consultation not found. Please start a new consultation.'),
                                                      backgroundColor: Colors.red,
                                                    ),
                                                  );
                                                }
                                              }
                                            } catch (e) {
                                              print('❌ ERROR IN PATIENT REJOIN: $e');
                                              if (mounted) {
                                                Navigator.pop(context); // close loading
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Error rejoining consultation: $e'),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF8B5CF6),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          child: Text('Rejoin'.tr(), style: const TextStyle(fontWeight: FontWeight.w700)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Reason
                                if (appointment.reason != null &&
                                    appointment.reason!.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.note_rounded,
                                              size: 16,
                                              color: Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Reason for Visit'.tr(),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          appointment.reason!,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
