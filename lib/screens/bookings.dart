import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/models/appointment_detail.dart';
import 'package:icare/screens/booking_categories.dart';
import 'package:icare/screens/consultation_chat_screen_v2.dart';
import 'package:icare/services/appointment_service.dart';
import 'package:icare/services/consultation_service.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:intl/intl.dart';

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key, this.tabs = false});
  final bool tabs;

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  final AppointmentService _appointmentService = AppointmentService();
  List<AppointmentDetail> _appointments = [];
  bool _isLoading = true;
  Timer? _reminderTimer;
  final Set<String> _notifiedAppointments = {};
  final Set<String> _notifiedInProgress = {};

  @override
  void initState() {
    super.initState();
    _loadAppointments();
    _startReminderTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void _startReminderTimer() {
    _reminderTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _refreshAppointments();
        _checkUpcomingReminders();
      }
    });
  }

  Future<void> _refreshAppointments() async {
    final result = await _appointmentService.getMyAppointmentsDetailed();
    if (!mounted) return;
    if (result['success']) {
      final updated = result['appointments'] as List<AppointmentDetail>;
      // Check for newly in_progress appointments → show banner to patient
      for (final appt in updated) {
        if (appt.status.toLowerCase() == 'in_progress' &&
            !_notifiedInProgress.contains(appt.id)) {
          _notifiedInProgress.add(appt.id);
          _showCallStartedBanner(appt);
        }
      }
      setState(() => _appointments = updated);
    }
  }

  void _showCallStartedBanner(AppointmentDetail appt) {
    if (!mounted) return;
    final doctorName = appt.doctorName.isNotEmpty ? appt.doctorName : 'Your doctor';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.videocam_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Consultation Started!'.tr(),
                      style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 15)),
                  Text('$doctorName is waiting — tap "In Progress" to join',
                      style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF6366F1),
        duration: const Duration(seconds: 12),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
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
        ? 'Appointment starting now!'
        : 'Appointment in $minutesLeft minute${minutesLeft == 1 ? '' : 's'}!';
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
                  Text('${appt.patientName} • ${appt.timeSlot}',
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

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);
    final result = await _appointmentService.getMyAppointmentsDetailed();
    if (result['success']) {
      setState(() {
        _appointments = result['appointments'] as List<AppointmentDetail>;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  int _getCount(String status) {
    if (status == 'Upcoming') {
      return _appointments
          .where(
            (a) =>
                a.status.toLowerCase() == 'pending' ||
                a.status.toLowerCase() == 'confirmed',
          )
          .length;
    }
    if (status == 'In Progress') {
      final now = DateTime.now();
      return _appointments
          .where((a) =>
              a.status.toLowerCase() == 'in_progress' &&
              (a.channelName?.isNotEmpty == true) &&
              now.difference(a.createdAt).inHours <= 4)
          .length;
    }
    return _appointments
        .where((a) => a.status.toLowerCase() == status.toLowerCase())
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Utils.windowWidth(context) > 600;
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final List<Map<String, dynamic>> bookingMenu = [
      {
        "id": 1,
        "title": "In Progress Bookings".tr(),
        "subtitle": "Currently active appointments".tr(),
        "icon": Icons.play_circle_outline_rounded,
        "color": const Color(0xFF8B5CF6),
        "bgColor": const Color(0xFF8B5CF6).withValues(alpha: 0.08),
        "count": _getCount('In Progress').toString(),
        "image": ImagePaths.inProgress,
        "onPressed": () async {
          await _loadAppointments();
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => InProgressConsultationsScreen(
                appointments: _appointments
                    .where((a) => a.status.toLowerCase() == 'in_progress')
                    .toList(),
              ),
            ),
          ).then((_) => _loadAppointments());
        },
      },
      {
        "id": 2,
        "title": "Upcoming Bookings".tr(),
        "subtitle": "Confirmed & scheduled".tr(),
        "icon": Icons.schedule_rounded,
        "color": const Color(0xFF14B1FF),
        "bgColor": const Color(0xFF14B1FF).withValues(alpha: 0.08),
        "count": _appointments.where((a) => a.status.toLowerCase() == 'confirmed').length.toString(),
        "image": ImagePaths.upcoming,
        "onPressed": () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => BookingCategories(
                appointments: _appointments,
                initialTabIndex: 0,
              ),
            ),
          ).then((_) => _loadAppointments());
        },
      },
      {
        "id": 3,
        "title": "Pending Bookings".tr(),
        "subtitle": "Awaiting confirmation".tr(),
        "icon": Icons.hourglass_empty_rounded,
        "color": const Color(0xFFF59E0B),
        "bgColor": const Color(0xFFF59E0B).withValues(alpha: 0.08),
        "count": _appointments.where((a) => a.status.toLowerCase() == 'pending').length.toString(),
        "image": ImagePaths.pending,
        "onPressed": () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => BookingCategories(
                appointments: _appointments,
                initialTabIndex: 1,
              ),
            ),
          ).then((_) => _loadAppointments());
        },
      },
      {
        "id": 4,
        "title": "Completed Bookings".tr(),
        "subtitle": "Past successful visits".tr(),
        "icon": Icons.check_circle_outline_rounded,
        "color": const Color(0xFF22C55E),
        "bgColor": const Color(0xFF22C55E).withValues(alpha: 0.08),
        "count": _getCount('Completed').toString(),
        "image": ImagePaths.completed,
        "onPressed": () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => BookingCategories(
                appointments: _appointments,
                initialTabIndex: 2,
              ),
            ),
          ).then((_) => _loadAppointments());
        },
      },
      {
        "id": 5,
        "title": "Cancelled Bookings".tr(),
        "subtitle": "Appointments you cancelled".tr(),
        "icon": Icons.cancel_outlined,
        "color": const Color(0xFFEF4444),
        "bgColor": const Color(0xFFEF4444).withValues(alpha: 0.08),
        "count": _getCount('Cancelled').toString(),
        "image": ImagePaths.cancelled,
        "onPressed": () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => BookingCategories(
                appointments: _appointments,
                initialTabIndex: 3,
              ),
            ),
          ).then((_) => _loadAppointments());
        },
      },
    ];

    // ─── MOBILE: original design ────────────────────────────────────────────
    if (!isDesktop) {
      return Material(
        child: Container(
          width: Utils.windowWidth(context),
          height: Utils.windowHeight(context),
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/images/bgImage.jpeg"),
              fit: BoxFit.cover,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(top: ScallingConfig.verticalScale(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(height: ScallingConfig.scale(20)),
                if (!widget.tabs)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [CustomBackButton()],
                  ),
                SizedBox(height: ScallingConfig.scale(20)),
                Center(
                  child: CustomText(
                    text: "Bookings History".tr(),
                    fontSize: 25.27,
                    padding: EdgeInsets.only(
                      left: ScallingConfig.moderateScale(12),
                    ),
                    color: AppColors.themeBlue,
                    fontWeight: FontWeight.w700,
                    isBold: true,
                    textAlign: TextAlign.center,
                  ),
                ),
                Center(
                  child: CustomText(
                    text:
                        "Stay on top of your schedule with real-time updates on patient bookings.".tr(),
                    padding: EdgeInsets.only(
                      top: ScallingConfig.verticalScale(10),
                      left: ScallingConfig.moderateScale(12),
                    ),
                    width: Utils.windowWidth(context) * 0.8,
                    textAlign: TextAlign.center,
                    fontSize: 12.60,
                    maxLines: 2,
                    isSemiBold: true,
                  ),
                ),
                SizedBox(height: ScallingConfig.scale(20)),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        clipBehavior: Clip.hardEdge,
                        width: Utils.windowWidth(context),
                        padding: EdgeInsets.symmetric(
                          horizontal: ScallingConfig.scale(10),
                          vertical: ScallingConfig.verticalScale(20),
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.bgColor,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(40),
                            topRight: Radius.circular(40),
                          ),
                        ),
                        child: Center(
                          child: ListView.builder(
                            padding: EdgeInsets.only(
                              left: ScallingConfig.scale(10),
                              right: ScallingConfig.scale(10),
                            ),
                            itemCount: bookingMenu.length,
                            itemBuilder: (ctx, i) {
                              final item = bookingMenu[i];
                              return BookingCategoryCard(
                                title: item["title"],
                                onPressed: item["onPressed"],
                                image: item["image"],
                              );
                            },
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

    // ─── DESKTOP: premium design ────────────────────────────────────────────
    return Material(
      child: Container(
        width: Utils.windowWidth(context),
        height: Utils.windowHeight(context),
        color: const Color(0xFFF8FAFC),
        child: Column(
          children: [
            // Premium dark header
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                bottom: 32,
                left: 48,
                right: 48,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    children: [
                      if (!widget.tabs)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.arrow_back_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      CustomText(
                        text: "Bookings History".tr(),
                        fontSize: 32,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                      const SizedBox(height: 8),
                      CustomText(
                        text:
                            "Stay on top of your schedule with real-time updates".tr(),
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w400,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStatChip(
                            _appointments.length.toString(),
                            "Total".tr(),
                            Colors.white,
                          ),
                          const SizedBox(width: 12),
                          _buildStatChip(
                            _getCount('In Progress').toString(),
                            "Active".tr(),
                            const Color(0xFF3B82F6),
                          ),
                          const SizedBox(width: 12),
                          _buildStatChip(
                            _getCount('Completed').toString(),
                            "Done",
                            const Color(0xFF22C55E),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Cards list
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 24,
                    ),
                    itemCount: bookingMenu.length,
                    itemBuilder: (ctx, i) {
                      final item = bookingMenu[i];
                      return _PremiumBookingCard(
                        title: item["title"],
                        subtitle: item["subtitle"],
                        icon: item["icon"],
                        color: item["color"],
                        bgColor: item["bgColor"],
                        count: item["count"],
                        onPressed: item["onPressed"],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: "Gilroy",
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: "Gilroy",
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Original mobile card ────────────────────────────────────────────────────
class BookingCategoryCard extends StatelessWidget {
  const BookingCategoryCard({
    super.key,
    this.title,
    this.image,
    this.onPressed,
  });
  final String? title;
  final Function()? onPressed;
  final String? image;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        margin: EdgeInsets.only(top: ScallingConfig.scale(5)),
        padding: EdgeInsets.only(
          top: ScallingConfig.scale(10),
          left: ScallingConfig.scale(20),
        ),
        width: Utils.windowWidth(context) * 0.9,
        height: Utils.windowHeight(context) * 0.1,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          image: DecorationImage(fit: BoxFit.cover, image: AssetImage(image!)),
        ),
        child: Row(
          children: [
            CustomText(
              text: title,
              color: AppColors.white,
              fontSize: ScallingConfig.moderateScale(18.88),
              fontFamily: "",
            ),
            const Icon(Icons.keyboard_arrow_right, color: AppColors.white),
          ],
        ),
      ),
    );
  }
}

// ─── Desktop premium card ────────────────────────────────────────────────────
class _PremiumBookingCard extends StatefulWidget {
  const _PremiumBookingCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.count,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String count;
  final VoidCallback onPressed;

  @override
  State<_PremiumBookingCard> createState() => _PremiumBookingCardState();
}

class _PremiumBookingCardState extends State<_PremiumBookingCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
          decoration: BoxDecoration(
            color: _isHovered ? widget.bgColor : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHovered
                  ? widget.color.withValues(alpha: 0.25)
                  : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? widget.color.withValues(alpha: 0.08)
                    : const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: _isHovered ? 24 : 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _isHovered ? widget.color : widget.bgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  widget.icon,
                  color: _isHovered ? Colors.white : widget.color,
                  size: 26,
                ),
              ),
              const SizedBox(width: 24),
              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontFamily: "Gilroy",
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        fontFamily: "Gilroy",
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              // Count badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: widget.bgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.count,
                  style: TextStyle(
                    fontFamily: "Gilroy",
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: widget.color,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Arrow
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isHovered
                      ? widget.color.withValues(alpha: 0.1)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: _isHovered ? widget.color : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ─── Dedicated In Progress Consultations Screen ──────────────────────────────
class InProgressConsultationsScreen extends StatelessWidget {
  final List<AppointmentDetail> appointments;

  const InProgressConsultationsScreen({super.key, required this.appointments});

  /// Returns valid channelName only if it's a RECENT video channel (last 4 hours)
  String? _getValidChannelName(AppointmentDetail appt) {
    // Must have a stored channel_name
    String? channel;
    if (appt.channelName != null && appt.channelName!.isNotEmpty) {
      channel = appt.channelName!;
    } else {
      // Parse from notes
      final notes = appt.reason ?? '';
      final match = RegExp(r'Channel:\s*(\S+)').firstMatch(notes);
      if (match != null) channel = match.group(1)!;
    }
    if (channel == null) return null;

    // Only consider it "active" if created within last 4 hours
    final now = DateTime.now();
    final diff = now.difference(appt.createdAt);
    if (diff.inHours > 4) return null;

    return channel;
  }

  @override
  Widget build(BuildContext context) {
    // Only show appointments with valid (recent) channelName
    final activeAppointments = appointments
        .where((a) => _getValidChannelName(a) != null)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // newest first

    final videoCount = activeAppointments.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // ── Sticky header ──
          SliverAppBar(
            pinned: true,
            expandedHeight: videoCount > 0 ? 140 : 80,
            backgroundColor: const Color(0xFF1E1B4B),
            leading: const CustomBackButton(),
            centerTitle: true,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E1B4B), Color(0xFF4C1D95)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(60, 12, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Active Consultations',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (videoCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF4ADE80),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$videoCount active session${videoCount > 1 ? 's' : ''} — tap Rejoin',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Content ──
          activeAppointments.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.video_call_rounded,
                              size: 56, color: Color(0xFF8B5CF6)),
                        ),
                        const SizedBox(height: 20),
                        const Text('No active consultations',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A))),
                        const SizedBox(height: 8),
                        const Text(
                          'Start a consultation and use the red button\nto leave — then come back here to rejoin',
                          style: TextStyle(
                              fontSize: 14, color: Color(0xFF94A3B8)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final appt = activeAppointments[i];
                        final channelName = _getValidChannelName(appt)!;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF5F5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.4),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Status badge
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Text(
                                            '● LIVE',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.red,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      DateFormat('MMM dd, hh:mm a')
                                          .format(appt.createdAt.toLocal()),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF94A3B8)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Doctor info
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor:
                                          Colors.red.withValues(alpha: 0.1),
                                      child: Text(
                                        appt.doctorName.isNotEmpty
                                            ? appt.doctorName[0].toUpperCase()
                                            : 'D',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            appt.doctorName,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          Text(
                                            'Video Consultation',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.red
                                                    .withValues(alpha: 0.7)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 14),

                                // Rejoin button — red, full width
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      // Show loading
                                      showDialog(
                                        context: ctx,
                                        barrierDismissible: false,
                                        builder: (_) => const Center(child: CircularProgressIndicator()),
                                      );

                                      try {
                                        print('🔄 DOCTOR REJOIN: Fetching consultation for appointment ${appt.id}');
                                        final consultationService = ConsultationService();
                                        final sharedPref = SharedPref();

                                        final userData = await sharedPref.getUserData();
                                        final currentUserId = userData?.id ?? '';
                                        final currentUserName = userData?.name ?? 'Doctor';

                                        // Fetch existing consultation by appointment ID
                                        final result = await consultationService.getConsultationByAppointmentId(appt.id ?? '');

                                        print('📥 DOCTOR REJOIN RESPONSE: $result');

                                        if (!ctx.mounted) return;
                                        Navigator.pop(ctx); // Close loading

                                        if (result['success'] == true && result['consultation'] != null) {
                                          final consultationId = result['consultation']['_id']?.toString() ?? '';
                                          print('✅ Doctor found consultation: $consultationId');

                                          if (consultationId.isEmpty) {
                                            if (ctx.mounted) {
                                              ScaffoldMessenger.of(ctx).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Consultation ID not found. Please contact support.'),
                                                  backgroundColor: Colors.orange,
                                                ),
                                              );
                                            }
                                            return;
                                          }

                                          // Navigate to chat screen with existing consultation
                                          if (ctx.mounted) {
                                            Navigator.push(
                                              ctx,
                                              MaterialPageRoute(
                                                builder: (_) => ConsultationChatScreenV2(
                                                  appointment: appt,
                                                  isDoctor: true, // Doctor side
                                                  currentUserId: currentUserId,
                                                  currentUserName: currentUserName,
                                                  consultationId: consultationId,
                                                ),
                                              ),
                                            );
                                          }
                                        } else {
                                          // Consultation not found
                                          print('❌ Doctor: Consultation not found for appointment ${appt.id}');
                                          if (ctx.mounted) {
                                            ScaffoldMessenger.of(ctx).showSnackBar(
                                              SnackBar(
                                                content: Text(result['message']?.toString() ?? 'Consultation not found. Please start a new consultation.'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      } catch (e) {
                                        print('❌ ERROR IN DOCTOR REJOIN: $e');
                                        if (ctx.mounted) {
                                          Navigator.pop(ctx);
                                          ScaffoldMessenger.of(ctx).showSnackBar(
                                            SnackBar(
                                              content: Text('Error rejoining consultation: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    icon: const Icon(
                                        Icons.video_call_rounded,
                                        size: 18),
                                    label: const Text(
                                      'Rejoin Consultation',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: activeAppointments.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
