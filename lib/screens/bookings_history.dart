import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:icare/models/appointment_detail.dart';
import 'package:icare/screens/doctors_list.dart';
import 'package:icare/screens/prescription_detail_screen.dart';
import 'package:icare/screens/profile_or_appointement_view.dart';
import 'package:icare/screens/consultation_chat_screen_v2.dart';
import 'package:icare/services/appointment_service.dart';
import 'package:icare/services/consultation_service.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:intl/intl.dart';

class BookingsHistoryScreen extends StatefulWidget {
  const BookingsHistoryScreen({super.key});

  @override
  State<BookingsHistoryScreen> createState() => _BookingsHistoryScreenState();
}

class _BookingsHistoryScreenState extends State<BookingsHistoryScreen> {
  final AppointmentService _appointmentService = AppointmentService();
  final ConsultationService _consultationService = ConsultationService();
  List<AppointmentDetail> _appointments = [];
  bool _isLoading = true;
  String _currentUserId = '';
  String _currentUserName = '';

  @override
  void initState() {
    super.initState();
    _loadUserAndAppointments();
  }

  Future<void> _loadUserAndAppointments() async {
    final user = await SharedPref().getUserData();
    if (mounted && user != null) {
      setState(() {
        _currentUserId = user.id ?? '';
        _currentUserName = user.name ?? user.email ?? 'User';
      });
    }
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);
    final result = await _appointmentService.getMyAppointmentsDetailed();
    if (mounted) {
      setState(() {
        if (result['success']) {
          _appointments = result['appointments'] as List<AppointmentDetail>;
        }
        _isLoading = false;
      });
    }
  }

  int _count(String status) =>
      _appointments.where((a) => a.status.toLowerCase() == status).length;

  List<AppointmentDetail> _byStatus(String status) =>
      _appointments.where((a) => a.status.toLowerCase() == status).toList();

  /// Extract the real Agora channel from an appointment.
  /// Tries channelName field first, then parses it from reason/notes text.
  String? _extractChannel(AppointmentDetail a) {
    if (a.channelName != null && a.channelName!.trim().isNotEmpty) {
      return a.channelName!.trim();
    }
    final notes = a.reason ?? '';
    final match = RegExp(r'Channel:\s*(\S+)').firstMatch(notes);
    return match?.group(1);
  }

  /// Only show in_progress appointments that:
  /// 1. Have a valid video channel (from channelName field OR reason text)
  /// 2. Status was updated (set to in_progress) within the last 60 minutes
  ///    — older sessions are considered stale/ended
  List<AppointmentDetail> get _inProgress {
    final now = DateTime.now();
    return _appointments.where((a) {
      if (a.status.toLowerCase() != 'in_progress') return false;
      // Must have a real video channel
      if (_extractChannel(a) == null) return false;
      // Must be recently set to in_progress (within 60 min of last update)
      return now.difference(a.updatedAt).inMinutes <= 60;
    }).toList();
  }

  List<AppointmentDetail> get _upcoming => _appointments
      .where((a) =>
          a.status.toLowerCase() == 'confirmed' &&
          a.date.isAfter(DateTime.now()))
      .toList();

  @override
  Widget build(BuildContext context) {
    final double pad = Utils.windowWidth(context) > 600 ? 32 : 20;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: RefreshIndicator(
        onRefresh: _loadAppointments,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildHeader(pad),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(pad, 24, pad, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(_buildBody()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader(double pad) {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E3A5F), Color(0xFF0F2744)],
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(36),
            bottomRight: Radius.circular(36),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, 16, pad, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back
                GestureDetector(
                  onTap: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Text('Home'.tr(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Icon + title — centered
                Center(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.calendar_month_rounded,
                            color: Colors.white, size: 32),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Bookings History'.tr(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'All your appointments in one place'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.65)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A))),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Body list ─────────────────────────────────────────────────────────────
  List<Widget> _buildBody() {
    return [
      // Stats row — inside scrollable body, NOT in header
      if (!_isLoading)
        Row(
          children: [
            _statCard('Total'.tr(), _appointments.length,
                const Color(0xFF60A5FA), Icons.list_alt_rounded),
            const SizedBox(width: 10),
            _statCard('Live'.tr(), _inProgress.length,
                const Color(0xFFF87171), Icons.circle),
            const SizedBox(width: 10),
            _statCard('Done'.tr(), _count('completed'),
                const Color(0xFF34D399), Icons.check_circle_rounded),
          ],
        ),
      if (!_isLoading) const SizedBox(height: 20),

      // Book Now
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DoctorsList())),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: Text('Book Appointment Now'.tr(),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      ),
      const SizedBox(height: 20),

      // In Progress — only show if there are active sessions
      if (_inProgress.isNotEmpty) ...[
        _buildInProgressSection(),
        const SizedBox(height: 12),
      ],

      // Categories: Pending → Upcoming → Completed → Cancelled
      _categoryTile('Pending'.tr(), 'Awaiting confirmation'.tr(),
          _count('pending'), const Color(0xFFF59E0B),
          Icons.hourglass_empty_rounded, _byStatus('pending')),
      const SizedBox(height: 10),
      _categoryTile('Upcoming'.tr(), 'Confirmed & scheduled'.tr(),
          _upcoming.length, const Color(0xFF0EA5E9),
          Icons.access_time_rounded, _upcoming),
      const SizedBox(height: 10),
      _categoryTile('Completed'.tr(), 'Past successful visits'.tr(),
          _count('completed'), const Color(0xFF10B981),
          Icons.check_circle_outline_rounded,
          // Sort completed newest first
          (_byStatus('completed')..sort((a, b) => b.date.compareTo(a.date)))),
      const SizedBox(height: 10),
      _categoryTile('Cancelled'.tr(), 'Appointments you cancelled'.tr(),
          _count('cancelled'), const Color(0xFFEF4444),
          Icons.cancel_outlined, _byStatus('cancelled')),

      if (_appointments.isEmpty) ...[
        const SizedBox(height: 40),
        Center(
          child: Column(
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('No bookings yet'.tr(),
                  style: const TextStyle(
                      fontSize: 16, color: Color(0xFF94A3B8))),
            ],
          ),
        ),
      ],
    ];
  }

  // ── In Progress section ───────────────────────────────────────────────────
  Widget _buildInProgressSection() {
    final appts = _inProgress;
    const red = Color(0xFFEF4444);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: red.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: red.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.videocam_rounded,
                      color: red, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Consultation In Progress'.tr(),
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A))),
                      const SizedBox(height: 3),
                      Text('Active video sessions'.tr(),
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: red,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('${appts.length}',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                ),
              ],
            ),
          ),

          if (appts.isNotEmpty) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                children: appts.map((a) => _rejoinRow(a)).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rejoinRow(AppointmentDetail appt) {
    // All rows here are guaranteed active (already filtered by _inProgress)
    const red = Color(0xFFEF4444);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: red.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                (appt.doctor?.name ?? 'D').substring(0, 1).toUpperCase(),
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appt.doctor?.name ?? 'Doctor',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A)),
                ),
                Text(
                  DateFormat('dd MMM yyyy').format(appt.date),
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _rejoin(appt),
            style: ElevatedButton.styleFrom(
              backgroundColor: red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.video_call_rounded, size: 17),
            label: Text('Rejoin'.tr(),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _rejoin(AppointmentDetail appt) async {
    if (!mounted) return;

    try {
      // First, try to get the existing consultation by appointment ID
      final consultationService = ConsultationService();
      final result = await consultationService.getConsultationByAppointmentId(appt.id);

      if (result['success'] == true) {
        // Found existing consultation, navigate with consultationId
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConsultationChatScreenV2(
              appointment: appt,
              isDoctor: false,
              currentUserId: _currentUserId,
              currentUserName: _currentUserName,
              consultationId: result['consultationId'],
            ),
          ),
        ).then((_) => _loadAppointments());
      } else {
        // No existing consultation, start new one
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConsultationChatScreenV2(
              appointment: appt,
              isDoctor: false,
              currentUserId: _currentUserId,
              currentUserName: _currentUserName,
              consultationId: null, // let the screen create it
            ),
          ),
        ).then((_) => _loadAppointments());
      }
    } catch (e) {
      // On error, fallback to creating new
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConsultationChatScreenV2(
            appointment: appt,
            isDoctor: false,
            currentUserId: _currentUserId,
            currentUserName: _currentUserName,
            consultationId: null,
          ),
        ),
      ).then((_) => _loadAppointments());
    }
  }

  // ── Category tile ─────────────────────────────────────────────────────────
  Widget _categoryTile(
    String title,
    String subtitle,
    int count,
    Color color,
    IconData icon,
    List<AppointmentDetail> list,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: count > 0
            ? () => _showSheet(title, list, color)
            : null,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: color.withValues(alpha: 0.18), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A))),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: count > 0
                        ? color
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10)),
                child: Text('$count',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: count > 0
                            ? Colors.white
                            : Colors.grey.shade400)),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded,
                  size: 22,
                  color: count > 0
                      ? const Color(0xFF94A3B8)
                      : Colors.grey.shade300),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bottom sheet ──────────────────────────────────────────────────────────
  void _showSheet(
      String title, List<AppointmentDetail> list, Color color) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, sc) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Sheet header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
              children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.calendar_month_rounded,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A))),
                              Text(
                                '${list.length} appointment${list.length != 1 ? 's' : ''}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                        // Global Close (X) button — dismisses the entire list view
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: sc,
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (ctx, i) => _apptCard(list[i], color, onCancelled: () {
                    if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                    _loadAppointments();
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _apptCard(AppointmentDetail appt, Color color, {VoidCallback? onCancelled}) {
    return _ApptCard(appt: appt, color: color, onCancelled: onCancelled);
  }
}

// ─── Appointment card (always expanded) ───────────────────────────────────
class _ApptCard extends StatefulWidget {
  final AppointmentDetail appt;
  final Color color;
  final VoidCallback? onCancelled;
  const _ApptCard({required this.appt, required this.color, this.onCancelled});
  @override
  State<_ApptCard> createState() => _ApptCardState();
}

class _ApptCardState extends State<_ApptCard> {
  bool _cancelling = false;

  Future<void> _cancelAppointment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancel Appointment'.tr(),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text(
            'Are you sure you want to cancel this appointment? This cannot be undone.'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No'.tr(), style: const TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Yes, Cancel'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    final result = await AppointmentService().updateAppointmentStatus(
      appointmentId: widget.appt.id,
      status: 'cancelled',
    );
    if (!mounted) return;
    setState(() => _cancelling = false);

    if (result['success'] == true) {
      widget.onCancelled?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to cancel appointment'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _viewPrescription() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final svc = ConsultationService();
      final res = await svc.getConsultationByAppointmentId(widget.appt.id);
      if (!mounted) return;
      Navigator.pop(context);

      if (res['success'] == true && res['consultation'] != null) {
        final consultation = res['consultation'] as Map;
        final consultationId = (res['consultationId'] ?? consultation['_id'] ?? consultation['id'])?.toString() ?? '';

        // Try prescriptionId field — could be a string or a populated object
        dynamic rawPrescId = consultation['prescriptionId'];
        String prescriptionId = '';

        if (rawPrescId is Map) {
          prescriptionId = rawPrescId['_id']?.toString() ?? '';
        } else if (rawPrescId is String && rawPrescId.isNotEmpty) {
          prescriptionId = rawPrescId;
        }

        // Fallback: check 'prescription' object field
        if (prescriptionId.isEmpty && consultation['prescription'] is Map) {
          final prescMap = consultation['prescription'] as Map;
          prescriptionId = (prescMap['_id'] ?? prescMap['id'])?.toString() ?? '';
        }

        Map<String, dynamic>? prescription;

        if (prescriptionId.isNotEmpty) {
          prescription = await svc.getPrescription(prescriptionId);
        }

        // If still not found, try fetching by consultationId directly
        if (prescription == null && consultationId.isNotEmpty) {
          prescription = await svc.getPrescriptionByConsultation(consultationId);
        }

        if (!mounted) return;
        if (prescription != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PrescriptionDetailScreen(prescription: prescription!),
            ),
          );
          return;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No prescription found for this appointment'.tr()),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appt = widget.appt;
    final color = widget.color;
    final isCompleted = appt.status.toLowerCase() == 'completed';
    final canCancel = ['pending', 'confirmed'].contains(appt.status.toLowerCase());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.65)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      appt.doctor?.name.isNotEmpty == true
                          ? appt.doctor!.name[0].toUpperCase()
                          : 'D',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(appt.doctor?.name ?? 'Doctor',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 10, color: color),
                          const SizedBox(width: 4),
                          Text(DateFormat('MMM dd, yyyy').format(appt.date),
                              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 6),
                          Icon(Icons.access_time_rounded, size: 10, color: color),
                          const SizedBox(width: 4),
                          Text(appt.timeSlot,
                              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Detail section — always visible (removed per-row delete/collapse toggle)
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // View Prescription (only for completed)
                if (isCompleted) ...[
                  GestureDetector(
                    onTap: _viewPrescription,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.description_outlined, size: 12, color: Color(0xFF10B981)),
                          const SizedBox(width: 4),
                          Text('Prescription'.tr(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // Details button
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileOrAppointmentViewScreen(appointment: appt),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Details'.tr(),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                  ),
                ),
              ],
            ),
          ),

          // Cancel button — only for pending / confirmed appointments
          if (canCancel) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: SizedBox(
                width: double.infinity,
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: _cancelling ? null : _cancelAppointment,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: EdgeInsets.zero,
                  ),
                  icon: _cancelling
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFEF4444)))
                      : const Icon(Icons.cancel_outlined, size: 15),
                  label: Text(
                    _cancelling ? 'Cancelling...'.tr() : 'Cancel Appointment'.tr(),
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
