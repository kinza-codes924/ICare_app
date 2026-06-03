import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icare/models/appointment_detail.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/services/appointment_service.dart';
import 'package:icare/services/connect_now_service.dart';
import 'package:icare/services/doctor_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/screens/doctor_appointments.dart';
import 'package:icare/screens/settings.dart';
import 'package:icare/screens/doctor_availability.dart';
import 'package:icare/screens/courses.dart';
import 'package:icare/screens/my_learning.dart';
import 'package:icare/screens/clinical_audit_screen.dart';
import 'package:icare/screens/doctor_forum_screen.dart';
import 'package:icare/screens/credential_vault_screen.dart';
import 'package:icare/screens/profile_or_appointement_view.dart';
import 'package:icare/models/medical_record.dart';
import 'package:icare/services/medical_record_service.dart';
import 'package:icare/services/consultation_service.dart';
import 'package:icare/screens/medical_record_detail.dart';
import 'package:icare/screens/prescription_detail_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DoctorDashboard extends ConsumerStatefulWidget {
  const DoctorDashboard({super.key});

  @override
  ConsumerState<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends ConsumerState<DoctorDashboard> {
  final AppointmentService _appointmentService = AppointmentService();
  final DoctorService _doctorService = DoctorService();
  List<AppointmentDetail> _appointments = [];
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _clinicalRejectionFlags = [];
  bool _isLoading = true;
  bool _availableForInstantConsultation = true;
  final bool _isInConsultation = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadInstantConsultToggle();
    _doctorService.setOnlineStatus(true);
    // Note: DoctorConnectNowListener in tabs.dart handles all polling globally
  }

  @override
  void dispose() {
    _doctorService.setOnlineStatus(false);
    super.dispose();
  }

  Future<void> _loadInstantConsultToggle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getBool('doctor_instant_consult_available') ?? true;
      if (mounted) setState(() => _availableForInstantConsultation = val);
      // Sync with backend on load so backend knows current state
      ConnectNowService().setInstantAvailability(val);
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _appointmentService.getMyAppointmentsDetailed(),
        _doctorService.getStats().catchError((_) => <String, dynamic>{'success': false, 'stats': {}}),
        _doctorService.getClinicalRejectionFlags().catchError((_) => <String, dynamic>{'success': false, 'flags': []}),
      ]);

      if (mounted) {
        setState(() {
          final appResult = results[0];
          final statsResult = results[1];
          final rejResult = results[2];
          if (appResult['success'] == true) {
            _appointments = appResult['appointments'] as List<AppointmentDetail>;
          }
          if (statsResult['success'] == true) {
            _stats = statsResult['stats'] ?? {};
          }
          if (rejResult['success'] == true) {
            _clinicalRejectionFlags =
                List<Map<String, dynamic>>.from(rejResult['flags'] ?? []);
          } else {
            _clinicalRejectionFlags = [];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ _loadData error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAppointments() async {
    _loadData();
  }

  List<AppointmentDetail> get _todayAppointments {
    final today = DateTime.now();
    return _appointments.where((a) {
      return a.date.year == today.year &&
          a.date.month == today.month &&
          a.date.day == today.day;
    }).toList();
  }

  int get _pendingCount =>
      _appointments.where((a) => a.status == 'pending').length;
  int get _confirmedCount =>
      _appointments.where((a) => a.status == 'confirmed').length;
  int get _completedCount =>
      _appointments.where((a) => a.status == 'completed').length;
  int get _missedCount =>
      _appointments.where((a) => a.status.toLowerCase() == 'missed').length;

  @override
  Widget build(BuildContext context) {
    final userName = ref.watch(authProvider).user?.name ?? 'Doctor';
    final width = Utils.windowWidth(context);
    final bool isDesktop = width > 900;
    final bool isTablet = width > 600 && width <= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'doctor_workspace'.tr(),
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF0F172A)),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAppointments,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(isDesktop ? 32 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Welcome Header with rating + satisfaction
                        _buildWelcomeHeader(userName),
                        const SizedBox(height: 16),

                        // 1b. Instant Consultation Toggle
                        _buildInstantConsultToggle(),
                        const SizedBox(height: 24),

                        // 2. Appointment Requests (pending — Accept/Decline)
                        _buildAppointmentRequests(),
                        const SizedBox(height: 24),

                        // 3. Today's Appointments
                        _buildTodayAppointments(),
                        const SizedBox(height: 24),

                        // 4. Pending Appointments Count Card
                        _buildPendingAppointmentsCard(),
                        const SizedBox(height: 24),

                        // 5. Clinical Flags (pharmacy rejection alerts — not SOAP)
                        _buildClinicalFlags(),
                        const SizedBox(height: 24),

                        // 6. Recent Activity
                        _buildRecentActivity(),
                        const SizedBox(height: 24),

                        // 7. Clinical & Professional Features
                        _buildFeatureGrid(isDesktop, isTablet),
                        // Quick Actions intentionally removed per meeting notes
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildInstantConsultToggle() {
    return GestureDetector(
      onTap: () {
        if (_isInConsultation) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot change availability during an active consultation'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        setState(() => _availableForInstantConsultation = !_availableForInstantConsultation);
        // Persist toggle state
        _saveInstantConsultToggle(_availableForInstantConsultation);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: _availableForInstantConsultation
              ? const LinearGradient(
                  colors: [Color(0xFF0036BC), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: _availableForInstantConsultation ? null : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _availableForInstantConsultation
                ? const Color(0xFF0036BC)
                : const Color(0xFFE2E8F0),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (_availableForInstantConsultation
                      ? const Color(0xFF0036BC)
                      : Colors.black)
                  .withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _availableForInstantConsultation
                    ? Colors.white.withValues(alpha: 0.2)
                    : const Color(0xFF0036BC).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.video_call_rounded,
                color: _availableForInstantConsultation
                    ? Colors.white
                    : const Color(0xFF0036BC),
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available for Instant Consultation',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: _availableForInstantConsultation
                          ? Colors.white
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _availableForInstantConsultation
                        ? 'Patients can connect with you instantly'
                        : 'Toggle ON to receive instant consultation requests',
                    style: TextStyle(
                      fontSize: 12,
                      color: _availableForInstantConsultation
                          ? Colors.white.withValues(alpha: 0.8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _availableForInstantConsultation,
              onChanged: _isInConsultation
                  ? null
                  : (val) {
                      setState(() => _availableForInstantConsultation = val);
                      _saveInstantConsultToggle(val);
                    },
              activeThumbColor: Colors.white,
              activeTrackColor: Colors.white.withValues(alpha: 0.3),
              inactiveThumbColor: const Color(0xFF0036BC),
              inactiveTrackColor:
                  const Color(0xFF0036BC).withValues(alpha: 0.15),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveInstantConsultToggle(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('doctor_instant_consult_available', value);
    } catch (_) {}
    ConnectNowService().setInstantAvailability(value);
    // DoctorConnectNowListener reads this pref — no need to manage polling here
  }

  Widget _buildWelcomeHeader(String userName) {
    final avgRating = _stats['avgRating'] ?? '0.0';
    final satisfaction = _stats['satisfaction'] ?? '0%';
    final profilePic = ref.watch(authProvider).user?.profilePicture;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
            child: ClipOval(child: () {
              final img = buildProfileImageProvider(profilePic);
              if (img != null) return Image(image: img, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, color: AppColors.primaryColor, size: 30));
              return const Icon(Icons.person, color: AppColors.primaryColor, size: 30);
            }()),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'welcome_back'.tr(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Dr. $userName',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            avgRating.toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.sentiment_very_satisfied_rounded, color: Color(0xFF8B5CF6), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            satisfaction.toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6B21A8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCards(bool isDesktop, bool isTablet) {
    final totalConsultations = _stats['totalPatients'] ?? _completedCount;
    final avgRating = _stats['avgRating'] ?? '0.0';
    final satisfaction = _stats['satisfaction'] ?? '0%';

    final cards = [
      _buildStatCard(
        'Consultations',
        totalConsultations,
        Icons.medical_services_rounded,
        const Color(0xFF3B82F6),
      ),
      _buildStatCard(
        'Pending',
        _pendingCount,
        Icons.pending_actions_rounded,
        const Color(0xFFF59E0B),
      ),
      _buildStatCard(
        'Missed',
        _missedCount,
        Icons.event_busy_rounded,
        const Color(0xFFEF4444),
      ),
      _buildStatCard(
        'rating'.tr(),
        avgRating,
        Icons.star_rounded,
        const Color(0xFFF59E0B),
      ),
      _buildStatCard(
        'satisfaction'.tr(),
        satisfaction,
        Icons.sentiment_very_satisfied_rounded,
        const Color(0xFF8B5CF6),
      ),
    ];

    if (isDesktop || isTablet) {
      return Row(
        children: cards
            .map((c) => Expanded(child: c))
            .expand((w) => [w, const SizedBox(width: 16)])
            .toList()
          ..removeLast(),
      );
    }

    return Column(
      children: [
        Row(children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 12),
          Expanded(child: cards[1]),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: cards[2]),
          const SizedBox(width: 12),
          Expanded(child: cards[3]),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: cards[4]),
          const SizedBox(width: 12),
          const Expanded(child: SizedBox()),
        ]),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    dynamic count,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateAppointmentStatus(String appointmentId, String status) async {
    try {
      final result = await _appointmentService.updateAppointmentStatus(
        appointmentId: appointmentId,
        status: status,
      );
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(status == 'confirmed' ? 'Appointment accepted.' : 'Appointment declined.'),
            backgroundColor: status == 'confirmed' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          ));
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result['message'] ?? 'Failed to update appointment.'),
            backgroundColor: const Color(0xFFEF4444),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Something went wrong. Please try again.'),
          backgroundColor: Color(0xFFEF4444),
        ));
      }
    }
  }

  Widget _buildAppointmentRequests() {
    final pendingAppointments = _appointments
        .where((a) => a.status == 'pending')
        .take(5)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'Appointment Requests',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (_pendingCount > 0) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'New ${_pendingCount.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFamily: 'Gilroy-Bold',
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (_pendingCount > 5)
              TextButton(
                onPressed: () => context.push('/doctor/appointments'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primaryColor),
                child: const Text('View All'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (pendingAppointments.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text(
                'No pending appointment requests.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
              ),
            ),
          )
        else
          ...pendingAppointments.map((appt) => _buildRequestCard(appt)),
      ],
    );
  }

  Widget _buildRequestCard(AppointmentDetail appointment) {
    return _PendingRequestCard(
      appointment: appointment,
      onAccept: () => _updateAppointmentStatus(appointment.id, 'confirmed'),
      onReject: () => _updateAppointmentStatus(appointment.id, 'cancelled'),
    );
  }

  /// Today's appointments sorted: pending first, then completed
  List<AppointmentDetail> get _todayAppointmentsSorted {
    final today = _todayAppointments;
    final pending = today.where((a) => a.status == 'pending').toList();
    final others = today.where((a) => a.status != 'pending').toList();
    return [...pending, ...others];
  }

  Widget _buildTodayAppointments() {
    final sorted = _todayAppointmentsSorted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "today_appointments".tr(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Total Patients Today: ${sorted.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (sorted.length > 6)
              GestureDetector(
                onTap: _showAllTodayAppointments,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'View All (${sorted.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        sorted.isEmpty
            ? Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_available_rounded,
                        size: 48,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'no_appointments'.tr(),
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.95,
                children: sorted.take(6).map((appointment) {
                  return _buildTodayAppointmentCard(appointment);
                }).toList(),
              ),
      ],
    );
  }

  void _showAllTodayAppointments() {
    final sorted = _todayAppointmentsSorted;
    final pendingCount = sorted.where((a) => a.status == 'pending').length;
    final completedCount = sorted.where((a) => a.status == 'completed').length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    const Text(
                      "Today's Appointments",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    if (pendingCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$pendingCount Pending',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                        ),
                      ),
                    const SizedBox(width: 8),
                    if (completedCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$completedCount Done',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF166534)),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // List
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: sorted.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final appt = sorted[i];
                    final statusColor = _getStatusColor(appt.status);
                    final initials = (appt.patient?.name ?? 'P')
                        .split(' ')
                        .take(2)
                        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
                        .join();
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: statusColor.withValues(alpha: 0.15),
                                child: Text(
                                  initials.isEmpty ? 'P' : initials,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      appt.patient?.name ?? 'Patient',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${appt.timeSlot}  •  ${DateFormat('dd MMM yyyy').format(appt.date)}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  appt.status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Accept/Reject for pending appointments
                          if (appt.status == 'pending') ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _updateAppointmentStatus(appt.id, 'cancelled');
                                    },
                                    icon: const Icon(Icons.close_rounded, size: 16),
                                    label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w700)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFEF4444),
                                      side: const BorderSide(color: Color(0xFFEF4444)),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _updateAppointmentStatus(appt.id, 'confirmed');
                                    },
                                    icon: const Icon(Icons.check_rounded, size: 16),
                                    label: const Text('Accept', style: TextStyle(fontWeight: FontWeight.w700)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF059669),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayAppointmentCard(AppointmentDetail appointment) {
    final statusColor = _getStatusColor(appointment.status);
    final patientName = appointment.patient?.name ?? 'Patient';
    final patientPhoto = appointment.patient?.profilePicture;
    final initials = patientName
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();
    final isPending = appointment.status == 'pending';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => ProfileOrAppointmentViewScreen(appointment: appointment),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPending ? const Color(0xFFF59E0B).withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
            width: isPending ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top section: Avatar and name
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  backgroundImage: (patientPhoto != null && patientPhoto.isNotEmpty)
                      ? NetworkImage(patientPhoto) as ImageProvider
                      : null,
                  child: (patientPhoto == null || patientPhoto.isEmpty)
                      ? Text(
                          initials.isEmpty ? 'P' : initials,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: statusColor,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    patientName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            // Middle section: Time
            Text(
              appointment.timeSlot,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            // Bottom section: Status or actions
            if (isPending)
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _updateAppointmentStatus(appointment.id, 'cancelled'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Center(child: Icon(Icons.close_rounded, size: 12, color: Color(0xFFEF4444))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _updateAppointmentStatus(appointment.id, 'confirmed'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Center(child: Icon(Icons.check_rounded, size: 12, color: Color(0xFF059669))),
                      ),
                    ),
                  ),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  appointment.status.toUpperCase(),
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: statusColor),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingAppointmentsCard() {
    return GestureDetector(
      onTap: () => context.push('/doctor/appointments?filter=pending'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0036BC), Color(0xFF3B82F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0036BC).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.pending_actions_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _pendingCount.toString(),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Pending Appointments',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'View All',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsultationsCard() {
    final totalConsultations = _stats['totalPatients'] ?? _completedCount;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.medical_services_rounded,
              color: Color(0xFF3B82F6),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  totalConsultations.toString(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Text(
                  'Total Consultations',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueCard() {
    final revenue = _stats['revenue'] ?? 0;
    final consultationFee = _stats['consultationFee'] ?? _stats['fee'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.payments_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PKR ${_formatRevenue(revenue)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Total Revenue${consultationFee > 0 ? '  •  Fee: PKR $consultationFee' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatRevenue(dynamic val) {
    final n = (val is num) ? val.toInt() : int.tryParse('$val') ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  Future<void> _openClinicalRejectionDetail(Map<String, dynamic> flag) async {
    final prescId = flag['prescriptionId']?.toString() ?? '';
    final source = flag['prescriptionSource']?.toString() ?? '';
    if (prescId.isEmpty) return;

    try {
      if (source == 'medical_record') {
        final res = await MedicalRecordService().getRecordById(prescId);
        if (!mounted) return;
        if (res['success'] == true && res['record'] != null) {
          final recMap = Map<String, dynamic>.from(res['record'] as Map);
          final record = MedicalRecord.fromJson(recMap);
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => MedicalRecordDetailScreen(record: record),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open medical record'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        final rx = await ConsultationService().getPrescription(prescId);
        if (!mounted) return;
        if (rx != null) {
          final pmap = Map<String, dynamic>.from(rx as Map);
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => PrescriptionDetailScreen(prescription: pmap),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open prescription'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Clinical flag navigation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open record: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Missed consultations (for clinical flags)
  List<AppointmentDetail> get _missedConsultations =>
      _appointments.where((a) => a.status.toLowerCase() == 'missed').toList();

  // Appointments that ran over the 30-min consultation limit
  List<AppointmentDetail> get _timeExceededConsultations =>
      _appointments.where((a) =>
        a.status.toLowerCase() == 'completed' &&
        a.durationMinutes != null &&
        a.durationMinutes! > 30
      ).toList();

  Widget _buildClinicalFlags() {
    final totalRejections = _clinicalRejectionFlags.length;
    final flagged = _clinicalRejectionFlags.take(5).toList();
    final missed = _missedConsultations;
    final timeExceeded = _timeExceededConsultations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.flag_rounded, color: Color(0xFFDC2626), size: 20),
            const SizedBox(width: 8),
            const Text(
              'Clinical Flags',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 10),
            if (totalRejections > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$totalRejections rejection${totalRejections == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                ),
              ),
            if (missed.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${missed.length} missed',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                ),
              ),
            ],
            if (timeExceeded.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${timeExceeded.length} time exceeded',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: flagged.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: const Color(0xFF10B981),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'No pharmacy rejections on your prescriptions. Rejections marked as having no referrer are reported only to admin.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: Color(0xFFDC2626), size: 16),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'A pharmacy rejected an order linked to your prescription. Tap a row to review.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFDC2626),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...flagged.asMap().entries.map<Widget>((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      final patientName = item['patientName']?.toString() ?? 'Patient';
                      final orderNum = item['orderNumber']?.toString() ?? '';
                      final reason = item['rejectionReason']?.toString() ?? 'Rejected';
                      DateTime? at;
                      final rawAt = item['rejectedAt'];
                      if (rawAt is String) {
                        at = DateTime.tryParse(rawAt);
                      }
                      final dateStr = at != null
                          ? DateFormat('dd MMM yyyy, hh:mm a').format(at.toLocal())
                          : '';

                      return Column(
                        children: [
                          if (i > 0)
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          InkWell(
                            onTap: () => _openClinicalRejectionDetail(item),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.local_pharmacy_rounded,
                                      color: Color(0xFFDC2626),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Order $orderNum · $patientName',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          dateStr.isNotEmpty ? '$reason  ·  $dateStr' : reason,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Color(0xFF94A3B8),
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
        ),

        // ── Missed Consultations ──────────────────────────────────────────
        if (missed.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.event_busy_rounded, color: Color(0xFFB45309), size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Missed consultations — patients who did not show up.',
                          style: TextStyle(fontSize: 12, color: Color(0xFFB45309), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                ...missed.take(5).toList().asMap().entries.map<Widget>((entry) {
                  final i = entry.key;
                  final appt = entry.value;
                  return Column(
                    children: [
                      if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.person_off_rounded, color: Color(0xFFB45309), size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    appt.patient?.name ?? 'Patient',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${appt.timeSlot}  ·  ${DateFormat('dd MMM yyyy').format(appt.date)}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('MISSED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFB45309))),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
        // ── Time-Exceeded Consultations ───────────────────────────────────
        if (timeExceeded.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.timer_off_rounded, color: Color(0xFFEF4444), size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Consultations that exceeded the 30-minute limit.',
                          style: TextStyle(fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                ...timeExceeded.take(5).toList().asMap().entries.map<Widget>((entry) {
                  final i = entry.key;
                  final appt = entry.value;
                  final mins = appt.durationMinutes ?? 0;
                  final over = mins - 30;
                  return Column(
                    children: [
                      if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.timer_off_rounded, color: Color(0xFFEF4444), size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    appt.patient?.name ?? 'Patient',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${appt.timeSlot}  ·  ${DateFormat('dd MMM yyyy').format(appt.date)}  ·  ${mins}min total',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('+${over}min', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFEF4444))),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionCardCompact(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column( // Use column for 3-col layout
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
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
      default:
        return const Color(0xFF64748B);
    }
  }

  Widget _buildRecentActivity() {
    final recentAppts = _appointments.take(5).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.history_rounded, color: AppColors.primaryColor, size: 18),
              ),
              const SizedBox(width: 12),
              const Text('Recent Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 16),
          if (recentAppts.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No recent activity', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
              ),
            )
          else
            ...recentAppts.map((appt) {
              final status = appt.status.toLowerCase();
              Color dot;
              String label;
              if (status == 'completed') { dot = const Color(0xFF10B981); label = 'Consultation completed'; }
              else if (status == 'confirmed' || status == 'approved') { dot = const Color(0xFF3B82F6); label = 'Appointment confirmed'; }
              else if (status == 'cancelled') { dot = const Color(0xFFEF4444); label = 'Appointment cancelled'; }
              else { dot = const Color(0xFFF59E0B); label = 'Appointment pending'; }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                          Text('${appt.patient?.name ?? 'Patient'} • ${appt.date.day}/${appt.date.month}/${appt.date.year}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: dot.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(appt.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: dot)),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildFeatureGrid(bool isDesktop, bool isTablet) {
    final gridCount = isDesktop ? 4 : (isTablet ? 3 : 2);
    final clinicalRatio = isDesktop ? 2.0 : (isTablet ? 1.6 : 1.3);
    final profRatio = isDesktop ? 2.4 : (isTablet ? 2.0 : 1.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'clinical_management'.tr(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: gridCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: clinicalRatio,
          children: [
            _buildFeatureCard(
              'Quality Score',
              Icons.rule_folder_rounded,
              const Color(0xFF0F172A),
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const ClinicalAuditScreen(),
                  ),
                );
              },
            ),
            _buildFeatureCard(
              'forum'.tr(),
              Icons.groups_rounded,
              const Color(0xFF8B5CF6),
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const DoctorForumScreen(),
                  ),
                );
              },
            ),
            _buildFeatureCard(
              'Certificates',
              Icons.workspace_premium_rounded,
              const Color(0xFF10B981),
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const CredentialVaultScreen(),
                  ),
                );
              },
            ),
            _buildFeatureCard(
              'availability'.tr(),
              Icons.event_available_rounded,
              const Color(0xFF64748B),
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const DoctorAvailability(),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 32),
        Text(
          'professional_development'.tr(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: gridCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: profRatio,
          children: [
            _buildFeatureCard(
              'Courses',
              Icons.school_rounded,
              const Color(0xFF8B5CF6),
              () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (ctx) => const Courses()));
              },
            ),
            _buildFeatureCard(
              'my_learning'.tr(),
              Icons.bookmark_added_rounded,
              const Color(0xFF10B981),
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (ctx) => const MyLearningScreen()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Pending Request Card with 3-minute countdown timer
// ─────────────────────────────────────────────────────────────────────────────
class _PendingRequestCard extends StatefulWidget {
  final AppointmentDetail appointment;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _PendingRequestCard({
    required this.appointment,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<_PendingRequestCard> createState() => _PendingRequestCardState();
}

class _PendingRequestCardState extends State<_PendingRequestCard> {
  static const int _totalSeconds = 180; // 3 minutes
  late int _secondsLeft;
  Timer? _timer;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _secondsLeft = _totalSeconds;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _expired = true;
          t.cancel();
          // Auto-reject after 3 minutes
          widget.onReject();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timerLabel {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Color get _timerColor {
    if (_secondsLeft > 120) return const Color(0xFF10B981);
    if (_secondsLeft > 60) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _secondsLeft / _totalSeconds;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _expired ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
          width: _expired ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Timer progress bar
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
            ),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(_timerColor),
              minHeight: 4,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                      child: Text(
                        (widget.appointment.patient?.name ?? 'P').substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppColors.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.appointment.patient?.name ?? 'Patient',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.appointment.timeSlot}  •  ${DateFormat('dd MMM').format(widget.appointment.date)}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          if (widget.appointment.reason != null &&
                              widget.appointment.reason!.isNotEmpty &&
                              !widget.appointment.reason!.toLowerCase().contains('connect now')) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.appointment.reason!,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Countdown timer
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _timerColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _timerColor.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.timer_rounded, color: _timerColor, size: 14),
                          const SizedBox(height: 2),
                          Text(
                            _timerLabel,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: _timerColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _expired ? null : widget.onReject,
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFEF4444)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _expired ? null : widget.onAccept,
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Accept', style: TextStyle(fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFE2E8F0),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
