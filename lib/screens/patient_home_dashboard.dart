import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icare/models/appointment_detail.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/screens/consultation_details_screen.dart';
import 'package:icare/screens/doctors_list.dart';
import 'package:icare/screens/patient_lab_orders.dart';
import 'package:icare/screens/upcoming_appointments.dart';
import 'package:icare/services/appointment_service.dart';
import 'package:icare/services/gamification_service.dart';
import 'package:icare/services/health_tracker_service.dart';
import 'package:icare/services/medical_record_service.dart';
import 'package:intl/intl.dart';

/// Logged-in patient dashboard — replaces the public-home mirror with a real
/// action center. Every tile/card navigates to an existing, working screen;
/// data cards load silently and hide/soften when the API has nothing.
class PatientHomeDashboard extends ConsumerStatefulWidget {
  const PatientHomeDashboard({super.key});

  @override
  ConsumerState<PatientHomeDashboard> createState() => _PatientHomeDashboardState();
}

class _PatientHomeDashboardState extends ConsumerState<PatientHomeDashboard> {
  final _appointmentService = AppointmentService();
  final _trackerService = HealthTrackerService();
  final _gamificationService = GamificationService();
  final _recordService = MedicalRecordService();

  List<AppointmentDetail> _appointments = [];
  List<dynamic> _vitals = [];
  int _points = 0;
  int _recordsCount = 0;
  bool _loading = true;
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  static const _navy = Color(0xFF0F172A);
  static const _slate = Color(0xFF64748B);
  static const _blue = Color(0xFF0036BC);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    // Each loader fails silently — the dashboard renders with whatever
    // arrived; empty sections show friendly placeholders instead of spinners.
    await Future.wait([
      _appointmentService.getMyAppointmentsDetailed().then((r) {
        if (r['success'] == true) {
          _appointments = (r['appointments'] as List<AppointmentDetail>?) ?? [];
        }
      }).catchError((_) {}),
      _trackerService.getLatestEntries().then((r) {
        if (r['success'] == true) _vitals = (r['entries'] as List?) ?? [];
      }).catchError((_) {}),
      _gamificationService.getMyStats().then((r) {
        if (r['success'] == true) _points = (r['points'] as num?)?.toInt() ?? 0;
      }).catchError((_) {}),
      _recordService.getMyRecords().then((r) {
        if (r['success'] == true) _recordsCount = ((r['records'] as List?) ?? []).length;
      }).catchError((_) {}),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  // ── Derived data ───────────────────────────────────────────────────────────

  AppointmentDetail? get _nextAppointment {
    final now = DateTime.now();
    final upcoming = _appointments.where((a) {
      return (a.status == 'confirmed' || a.status == 'pending') &&
          a.date.isAfter(now.subtract(const Duration(days: 1)));
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  List<AppointmentDetail> get _recentActivity {
    final list = List<AppointmentDetail>.from(_appointments)
      ..sort((a, b) => b.date.compareTo(a.date));
    return list.take(4).toList();
  }

  int get _consultationsCount =>
      _appointments.where((a) => a.status == 'completed').length;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(authProvider).user?.name ?? 'Patient';
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 1000;
    final isTablet = width > 640;

    return Scrollbar(
      controller: _scrollCtrl,
      thumbVisibility: true,
      trackVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollCtrl,
        child: Container(
      color: const Color(0xFFF6F8FB),
      padding: EdgeInsets.all(isDesktop ? 28 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(name),
          const SizedBox(height: 24),
          _quickActions(isDesktop, isTablet),
          const SizedBox(height: 24),
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _appointmentCard()),
                const SizedBox(width: 20),
                Expanded(flex: 3, child: _healthTrackerCard(isDesktop)),
              ],
            )
          else ...[
            _appointmentCard(),
            const SizedBox(height: 20),
            _healthTrackerCard(isDesktop),
          ],
          const SizedBox(height: 24),
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _medicalRecordsCard()),
                const SizedBox(width: 20),
                Expanded(child: _recentActivityCard()),
                const SizedBox(width: 20),
                Expanded(child: _rewardsCard()),
              ],
            )
          else ...[
            _medicalRecordsCard(),
            const SizedBox(height: 20),
            _recentActivityCard(),
            const SizedBox(height: 20),
            _rewardsCard(),
          ],
          const SizedBox(height: 32),
        ],
      ),
        ),
      ),
    );
  }

  // ── Header: greeting ───────────────────────────────────────────────────────

  Widget _header(String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$_greeting,',
          style: const TextStyle(fontSize: 15, color: _slate, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          '$name 👋',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: _navy,
            fontFamily: 'Gilroy-Bold',
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Take charge of your health. We are here to help you!',
          style: TextStyle(fontSize: 14, color: _slate),
        ),
      ],
    );
  }

  // ── Quick actions grid ─────────────────────────────────────────────────────

  Widget _quickActions(bool isDesktop, bool isTablet) {
    final actions = <_QuickAction>[
      _QuickAction('Connect to a\nDoctor Now', Icons.videocam_rounded,
          const Color(0xFF0036BC), highlighted: true,
          onTap: () => _push(const ConsultationDetailsScreen())),
      _QuickAction('Book\nAppointment', Icons.calendar_month_rounded, const Color(0xFF2563EB),
          onTap: () => _push(const DoctorsList())),
      _QuickAction('View\nPrescriptions', Icons.description_rounded, const Color(0xFF7C3AED),
          onTap: () => context.push('/patient/prescriptions')),
      _QuickAction('Order\nMedicines', Icons.local_pharmacy_rounded, const Color(0xFF059669),
          onTap: () => context.push('/patient/pharmacies')),
      _QuickAction('Book\nLab Test', Icons.science_rounded, const Color(0xFF9333EA),
          onTap: () => context.push('/patient/book-lab')),
      _QuickAction('Health\nTracker', Icons.monitor_heart_rounded, const Color(0xFFDB2777),
          onTap: () => context.push('/patient/health-tracker')),
      _QuickAction('Health\nCommunity', Icons.groups_rounded, const Color(0xFF0D9488),
          onTap: () => context.push('/community')),
      _QuickAction('Medicine\nReminders', Icons.alarm_rounded, const Color(0xFFDC2626),
          onTap: () => context.push('/reminders')),
    ];

    // Exactly 8 tiles -> a neat 4x2 grid on tablet/desktop, 2x4 on mobile.
    final columns = (isDesktop || isTablet) ? 4 : 2;

    return _panel(
      title: 'Quick Actions',
      child: LayoutBuilder(builder: (context, constraints) {
        const gap = 12.0;
        final w = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: actions.map((a) => SizedBox(width: w, child: _actionTile(a))).toList(),
        );
      }),
    );
  }

  Widget _actionTile(_QuickAction a) {
    final bg = a.highlighted ? _blue : a.color.withValues(alpha: 0.07);
    final fg = a.highlighted ? Colors.white : _navy;
    final iconBg = a.highlighted ? Colors.white.withValues(alpha: 0.18) : a.color.withValues(alpha: 0.14);
    final iconFg = a.highlighted ? Colors.white : a.color;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: a.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
                child: Icon(a.icon, color: iconFg, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  a.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Upcoming appointment ───────────────────────────────────────────────────

  Widget _appointmentCard() {
    final appt = _nextAppointment;
    return _panel(
      title: 'Upcoming Appointment',
      trailing: _viewAll(() => _push(const UpcomingAppointments())),
      child: _loading
          ? const _CardLoader()
          : appt == null
              ? _emptyState(
                  icon: Icons.event_available_rounded,
                  text: 'No upcoming appointments',
                  actionLabel: 'Book Appointment',
                  onAction: () => _push(const DoctorsList()),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _doctorAvatar(appt.doctor?.profilePicture, size: 52),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appt.doctor?.name != null ? 'Dr. ${appt.doctor!.name}' : 'Doctor',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w900, color: _navy),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                (appt.consultationType ?? 'Consultation').toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11, color: _slate, fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _statusChip(appt.status),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 15, color: _slate),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('EEEE, d MMMM yyyy').format(appt.date),
                          style: const TextStyle(
                              fontSize: 13.5, color: _navy, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 15, color: _slate),
                        const SizedBox(width: 8),
                        Text(
                          appt.timeSlot,
                          style: const TextStyle(
                              fontSize: 13.5, color: _navy, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _push(const UpcomingAppointments()),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: const Text('View Details'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  // Real doctor photo when available; falls back to a generic icon so a
  // missing/broken image never breaks the card layout (fixed circle size
  // regardless of how many doctors exist or how long their names are).
  Widget _doctorAvatar(String? url, {required double size}) {
    final hasPhoto = url != null && url.isNotEmpty;
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: _blue.withValues(alpha: 0.08),
        child: hasPhoto
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(Icons.person_rounded, color: _blue, size: size * 0.58),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : Icon(Icons.person_rounded, color: _blue, size: size * 0.58),
              )
            : Icon(Icons.person_rounded, color: _blue, size: size * 0.58),
      ),
    );
  }

  Widget _statusChip(String status) {
    final confirmed = status == 'confirmed';
    final color = confirmed ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        confirmed ? 'Confirmed' : 'Pending',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  // ── Health tracker vitals ──────────────────────────────────────────────────

  static const _vitalMeta = <String, (IconData, Color)>{
    'Blood Pressure': (Icons.favorite_rounded, Color(0xFF10B981)),
    'Blood Sugar': (Icons.water_drop_rounded, Color(0xFFEF4444)),
    'Weight': (Icons.monitor_weight_rounded, Color(0xFF6366F1)),
    'Heart Rate': (Icons.monitor_heart_rounded, Color(0xFFE11D48)),
    'Oxygen Level': (Icons.air_rounded, Color(0xFF0EA5E9)),
    'Temperature': (Icons.thermostat_rounded, Color(0xFFF97316)),
    'Steps': (Icons.directions_walk_rounded, Color(0xFF14B8A6)),
    'Sleep': (Icons.bedtime_rounded, Color(0xFF8B5CF6)),
    'Water Intake': (Icons.local_drink_rounded, Color(0xFF3B82F6)),
  };

  Widget _healthTrackerCard(bool isDesktop) {
    return _panel(
      title: 'Health Tracker',
      trailing: _viewAll(() => context.push('/patient/health-tracker')),
      child: _loading
          ? const _CardLoader()
          : _vitals.isEmpty
              ? _emptyState(
                  icon: Icons.monitor_heart_rounded,
                  text: 'No vitals recorded yet.\nStart tracking your health today.',
                  actionLabel: 'Add First Reading',
                  onAction: () => context.push('/patient/health-tracker'),
                )
              : LayoutBuilder(builder: (context, constraints) {
                  final cols = constraints.maxWidth > 560 ? 4 : 2;
                  const gap = 12.0;
                  final w = (constraints.maxWidth - gap * (cols - 1)) / cols;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: _vitals.take(8).map((v) {
                      final type = v['vitalType']?.toString() ?? '';
                      final meta = _vitalMeta[type] ??
                          (Icons.show_chart_rounded, const Color(0xFF64748B));
                      return SizedBox(
                        width: w,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFEDF2F7)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      type,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: _slate),
                                    ),
                                  ),
                                  Icon(meta.$1, size: 16, color: meta.$2),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                v['value']?.toString() ?? '--',
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w900, color: _navy),
                              ),
                              Text(
                                v['unit']?.toString() ?? '',
                                style: const TextStyle(fontSize: 11, color: _slate),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                }),
    );
  }

  // ── Medical records summary ────────────────────────────────────────────────

  Widget _medicalRecordsCard() {
    final rows = <(IconData, Color, String, String, VoidCallback)>[
      // "Consultations" counts COMPLETED appointments — Upcoming Appointments
      // only lists confirmed/pending/in_progress ones, so tapping this used
      // to land on a screen that (correctly) showed none of them. Bookings
      // History already has a working "Completed" category with this exact
      // data.
      (Icons.chat_rounded, const Color(0xFF2563EB), 'Consultations',
          '$_consultationsCount completed', () => context.push('/patient/bookings-history')),
      (Icons.description_rounded, const Color(0xFF7C3AED), 'Prescriptions', 'View all',
          () => context.push('/patient/prescriptions')),
      (Icons.science_rounded, const Color(0xFF9333EA), 'Lab Reports', 'View all',
          () => _push(const PatientLabOrdersScreen())),
      (Icons.folder_shared_rounded, const Color(0xFF0891B2), 'Medical Records',
          '$_recordsCount records', () => context.push('/patient/records')),
      (Icons.history_rounded, const Color(0xFF059669), 'Bookings History', 'View all',
          () => context.push('/patient/bookings-history')),
    ];

    return _panel(
      title: 'My Medical Records',
      trailing: _viewAll(() => context.push('/patient/records')),
      child: Column(
        children: rows.map((r) {
          return InkWell(
            onTap: r.$5,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: r.$2.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(r.$1, color: r.$2, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(r.$3,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700, color: _navy)),
                  ),
                  Text(r.$4, style: const TextStyle(fontSize: 12, color: _slate)),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFCBD5E1)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Recent activity ────────────────────────────────────────────────────────

  Widget _recentActivityCard() {
    return _panel(
      title: 'Recent Activity',
      trailing: _viewAll(() => context.push('/patient/bookings-history')),
      child: _loading
          ? const _CardLoader()
          : _recentActivity.isEmpty
              ? _emptyState(
                  icon: Icons.history_rounded,
                  text: 'No activity yet',
                )
              : Column(
                  children: _recentActivity.map((a) {
                    final (icon, color, label) = switch (a.status) {
                      'completed' => (
                          Icons.check_circle_rounded,
                          const Color(0xFF10B981),
                          'Consultation completed'
                        ),
                      'cancelled' => (
                          Icons.cancel_rounded,
                          const Color(0xFFEF4444),
                          'Appointment cancelled'
                        ),
                      'confirmed' => (
                          Icons.event_available_rounded,
                          const Color(0xFF2563EB),
                          'Appointment confirmed'
                        ),
                      _ => (
                          Icons.schedule_rounded,
                          const Color(0xFFF59E0B),
                          'Appointment pending'
                        ),
                    };
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: color, size: 17),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.doctor?.name != null ? '$label — Dr. ${a.doctor!.name}' : label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w700, color: _navy),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('d MMM yyyy • h:mm a').format(a.date),
                                  style: const TextStyle(fontSize: 11.5, color: _slate),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
    );
  }

  // ── Rewards ─────────────────────────────────────────────────────────────────

  Widget _rewardsCard() {
    return InkWell(
      onTap: () => context.push('/rewards'),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.workspace_premium_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text('Rewards',
                        style: TextStyle(
                            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 18),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  '$_points',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900),
                ),
                const Text('Points earned',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5)),
              ],
            ),
          ),
    );
  }

  // ── Shared building blocks ─────────────────────────────────────────────────

  Widget _panel({required String title, Widget? trailing, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDF2F7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _navy,
                        fontFamily: 'Gilroy-Bold')),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _viewAll(VoidCallback onTap, {String label = 'View all'}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _blue)),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String text,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Icon(icon, size: 40, color: const Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: _slate, height: 1.5)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _blue,
                  side: const BorderSide(color: _blue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(actionLabel,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final bool highlighted;
  final VoidCallback onTap;
  _QuickAction(this.label, this.icon, this.color, {this.highlighted = false, required this.onTap});
}

class _CardLoader extends StatelessWidget {
  const _CardLoader();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: SizedBox(
          width: 22, height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0036BC)),
        ),
      ),
    );
  }
}
