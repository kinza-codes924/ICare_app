import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:icare/models/appointment_detail.dart';
import 'package:icare/screens/consultation_chat_screen_v2.dart';
import 'package:icare/screens/profile_or_appointement_view.dart';
import 'package:icare/services/appointment_service.dart';
import 'package:icare/services/consultation_service.dart';
import 'package:icare/services/call_service.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:intl/intl.dart';

class DoctorAppointmentsScreen extends StatefulWidget {
  final String initialFilter;
  const DoctorAppointmentsScreen({super.key, this.initialFilter = 'all'});

  @override
  State<DoctorAppointmentsScreen> createState() =>
      _DoctorAppointmentsScreenState();
}

class _DoctorAppointmentsScreenState extends State<DoctorAppointmentsScreen> {
  final AppointmentService _appointmentService = AppointmentService();
  List<AppointmentDetail> _appointments = [];
  bool _isLoading = true;
  late String _selectedFilter;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
    _loadAppointments();
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result['message'])));
      }
    }
  }

  Future<void> _updateStatus(String appointmentId, String newStatus) async {
    final result = await _appointmentService.updateAppointmentStatus(
      appointmentId: appointmentId,
      status: newStatus,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
        ),
      );

      if (result['success']) {
        _loadAppointments();
      }
    }
  }

  List<AppointmentDetail> get _filteredAppointments {
    if (_selectedFilter == 'all') return _appointments;
    if (_selectedFilter == 'in_progress') {
      return _appointments
          .where((a) => a.status.toLowerCase() == 'in_progress' || a.status.toLowerCase() == 'in-progress')
          .toList();
    }
    return _appointments
        .where((a) => a.status.toLowerCase() == _selectedFilter)
        .toList();
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
      case 'missed':
        return const Color(0xFF64748B);
      case 'in_progress':
      case 'in-progress':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
      case 'in-progress':
        return 'IN PROGRESS';
      case 'missed':
        return 'MISSED';
      default:
        return status.toUpperCase();
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  /// Extract channel name from appointment (for video call rejoin)
  String _getChannelName(AppointmentDetail appointment) {
    final notes = appointment.reason ?? '';
    final match = RegExp(r'Channel:\s*(\S+)').firstMatch(notes);
    if (match != null) return match.group(1)!;
    return appointment.channelName?.isNotEmpty == true
        ? appointment.channelName!
        : appointment.id;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Utils.windowWidth(context) > 600;
    final filteredList = _filteredAppointments;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomText(
              text: "My Appointments".tr(),
              fontFamily: "Gilroy-Bold",
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
            if (!_isLoading && _appointments.where((a) => a.status.toLowerCase() == 'pending').isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'New ${_appointments.where((a) => a.status.toLowerCase() == 'pending').length.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontFamily: 'Gilroy-Bold',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: EdgeInsets.all(isDesktop ? 24 : 16),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All'.tr(), 'all', _appointments.length),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Pending'.tr(),
                    'pending',
                    _appointments.where((a) => a.status == 'pending').length,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Confirmed'.tr(),
                    'confirmed',
                    _appointments.where((a) => a.status == 'confirmed').length,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'In Progress'.tr(),
                    'in_progress',
                    _appointments.where((a) => a.status.toLowerCase() == 'in_progress' || a.status.toLowerCase() == 'in-progress').length,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Completed'.tr(),
                    'completed',
                    _appointments.where((a) => a.status == 'completed').length,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Missed'.tr(),
                    'missed',
                    _appointments.where((a) => a.status.toLowerCase() == 'missed').length,
                  ),
                ],
              ),
            ),
          ),

          // Appointments List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No ${_selectedFilter == 'all' ? '' : _selectedFilter} appointments',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadAppointments,
                    child: ListView.builder(
                      padding: EdgeInsets.all(isDesktop ? 24 : 16),
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        final appointment = filteredList[index];
                        return _buildAppointmentCard(appointment);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = _selectedFilter == value;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryColor
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(AppointmentDetail appointment) {
    if (_selectedFilter == 'missed') {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_outline_rounded, color: Color(0xFF64748B), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                appointment.patientName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final statusColor = _getStatusColor(appointment.status);
    final isPending = appointment.status.toLowerCase() == 'pending';
    final isConfirmed = appointment.status.toLowerCase() == 'confirmed';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) =>
                ProfileOrAppointmentViewScreen(appointment: appointment),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, statusColor.withValues(alpha: 0.02)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header with Date & Status
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(19),
                  topRight: Radius.circular(19),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: statusColor.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.calendar_today_rounded,
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE, MMM dd').format(appointment.date),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              color: statusColor,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              appointment.timeSlot,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                    _getStatusLabel(appointment.status),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Patient Info Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF3B82F6),
                                const Color(0xFF8B5CF6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF3B82F6,
                                ).withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              appointment.patient?.name
                                      .substring(0, 1)
                                      .toUpperCase() ??
                                  'P',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appointment.patient?.name ?? 'Patient',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              if (appointment.patient?.age != null ||
                                  appointment.patient?.gender != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (appointment.patient?.age != null) ...[
                                      const Icon(Icons.cake_rounded,
                                          size: 13, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${appointment.patient!.age} yrs',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                    if (appointment.patient?.age != null &&
                                        appointment.patient?.gender != null)
                                      const SizedBox(width: 10),
                                    if (appointment.patient?.gender != null) ...[
                                      const Icon(Icons.person_outline_rounded,
                                          size: 13, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Text(
                                        _capitalize(
                                            appointment.patient!.gender!),
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                              // contact details intentionally excluded from doctor view
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Reason Section — hide raw channel names from connect_now
                  if (appointment.reason != null &&
                      appointment.reason!.isNotEmpty &&
                      !appointment.reason!.contains('Channel:')) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.description_rounded,
                                size: 18,
                                color: statusColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Reason for Visit'.tr(),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF000000),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            appointment.reason!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF000000),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Action Buttons
                  if (isPending) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _updateStatus(appointment.id, 'confirmed'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Accept'.tr(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  fontFamily: 'Gilroy-Bold',
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _updateStatus(appointment.id, 'cancelled'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Reject'.tr(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFEF4444),
                                  fontFamily: 'Gilroy-Bold',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (isConfirmed) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              // Show loading
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => const Center(child: CircularProgressIndicator()),
                              );
                              try {
                                final consultationService = ConsultationService();
                                final sharedPref = SharedPref();
                                final userData = await sharedPref.getUserData();
                                final currentUserId = userData?.id ?? '';
                                final currentUserName = userData?.name ?? 'Doctor';

                                final result = await consultationService.startConsultationV2(
                                  appointmentId: appointment.id ?? '',
                                  patientId: appointment.patient?.id ?? '',
                                  doctorId: appointment.doctor?.id ?? currentUserId,
                                );

                                if (context.mounted) Navigator.pop(context); // close loading

                                if (result['success'] == true && context.mounted) {
                                  final consultationId = result['consultationId']?.toString() ?? '';

                                  // ✅ Notify patient — send call signal so IncomingCallListener shows dialog
                                  final patientId = appointment.patient?.id ?? '';
                                  if (patientId.isNotEmpty && consultationId.isNotEmpty) {
                                    try {
                                      await CallService().initiateCall(
                                        receiverId: patientId,
                                        channelName: consultationId, // consultationId as channel
                                        callerName: 'Dr. $currentUserName',
                                        callType: 'consultation', // special type for chat-first
                                      );
                                    } catch (_) {} // non-blocking
                                  }

                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (ctx) => ConsultationChatScreenV2(
                                        appointment: appointment,
                                        isDoctor: true,
                                        currentUserId: currentUserId,
                                        currentUserName: currentUserName,
                                        consultationId: consultationId,
                                      ),
                                    ),
                                  );
                                } else if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(result['message']?.toString() ?? 'Failed to start consultation'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Start Consultation'.tr(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  fontFamily: 'Gilroy-Bold',
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => _updateStatus(appointment.id, 'completed'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
                            ),
                            child: const Icon(
                              Icons.check_circle_outline_rounded,
                              color: Color(0xFF3B82F6),
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (appointment.status.toLowerCase() == 'in_progress' || appointment.status.toLowerCase() == 'in-progress') ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.video_call_rounded, color: Color(0xFF8B5CF6), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Active Session'.tr(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF8B5CF6),
                              ),
                            ),
                          ),
                          // Rejoin consultation (chat interface)
                          ElevatedButton.icon(
                            onPressed: () async {
                              // Show loading
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => const Center(child: CircularProgressIndicator()),
                              );

                              try {
                                final consultationService = ConsultationService();
                                final sharedPref = SharedPref();
                                final userData = await sharedPref.getUserData();
                                final currentUserId = userData?.id ?? '';
                                final currentUserName = userData?.name ?? 'Doctor';

                                // Lookup existing consultation by appointmentId
                                final result = await consultationService.getConsultationByAppointmentId(appointment.id ?? '');

                                if (context.mounted) Navigator.pop(context); // close loading

                                if (result['success'] == true && context.mounted) {
                                  final consultationId = result['consultation']?['_id']?.toString() ?? '';

                                  if (consultationId.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Consultation not found. Please start a new consultation.'.tr()),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    return;
                                  }

                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (ctx) => ConsultationChatScreenV2(
                                        appointment: appointment,
                                        isDoctor: true,
                                        currentUserId: currentUserId,
                                        currentUserName: currentUserName,
                                        consultationId: consultationId,
                                      ),
                                    ),
                                  ).then((_) => _loadAppointments());
                                } else if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(result['message']?.toString() ?? 'Failed to rejoin consultation'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B5CF6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.chat_rounded, size: 18),
                            label: Text('Rejoin'.tr(), style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                    // Also allow ending the session
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _updateStatus(appointment.id, 'completed'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF64748B)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          'Mark as Completed'.tr(),
                          style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
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
  }
}
