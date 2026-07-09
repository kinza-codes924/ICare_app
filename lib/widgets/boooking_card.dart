import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:icare/models/appointment_detail.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/screens/chat_screen.dart';
import 'package:icare/screens/prescription_detail_screen.dart';
import 'package:icare/screens/profile_or_appointement_view.dart';
import 'package:icare/screens/consultation_chat_screen_v2.dart';
import 'package:icare/services/consultation_service.dart';
import 'package:icare/services/call_service.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:intl/intl.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/svg_wrapper.dart';

// enum Status { upcoming, cancelled, completed }

class BookingCard extends ConsumerWidget {
  const BookingCard({
    super.key,
    required this.appointment,
    this.showActions = true,
    this.onTap,
  });
  final AppointmentDetail appointment;
  final bool showActions;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRole = ref.watch(authProvider).userRole;
    final bool isDesktop = MediaQuery.of(context).size.width > 600;
    Widget reminder = Row(
      // mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CustomText(
          text: "Reminds Me",
          color: AppColors.primary500,
          fontSize: 10,
          fontFamily: "Gilroy-SemiBold",
        ),
        SizedBox(width: 20),
        FlutterSwitch(
          width: 50.0,
          height: 20.0,

          toggleSize: 15.0,
          value: true,
          borderRadius: 30.0,
          padding: 2.0,
          toggleColor: Color.fromRGBO(225, 225, 225, 1),
          activeColor: AppColors.themeBlack,
          inactiveColor: AppColors.darkGreyColor,
          onToggle: (val) {
            // setState(() {
            // status2 = val;
            // });
          },
        ),
      ],
    );

    Widget action =
        appointment.status.toLowerCase() == 'in_progress'
        ? Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.fiber_manual_record, color: Color(0xFF8B5CF6), size: 10),
                    SizedBox(width: 8),
                    Text(
                      'Consultation in Progress',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: ScallingConfig.scale(8)),
              CustomButton(
                label: "Rejoin Consultation",
                height: isDesktop ? 48 : Utils.windowHeight(context) * 0.055,
                borderRadius: 30,
                labelSize: 15,
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
                    final currentUserName = userData?.name ?? 'User';
                    final isDoctor = selectedRole == 'Doctor';

                    // Start consultation with chat-first approach
                    final result = await consultationService.startConsultationV2(
                      appointmentId: appointment.id ?? '',
                      patientId: appointment.patient?.id ?? '',
                      doctorId: appointment.doctor?.id ?? '',
                    );

                    Navigator.pop(context); // Close loading

                    if (result['success'] == true) {
                      final consultationId = result['consultationId']?.toString() ?? '';

                      // ✅ If doctor, notify patient via call signal
                      if (isDoctor) {
                        final patientId = appointment.patient?.id ?? '';
                        if (patientId.isNotEmpty && consultationId.isNotEmpty) {
                          try {
                            await CallService().initiateCall(
                              receiverId: patientId,
                              channelName: consultationId,
                              callerName: 'Dr. $currentUserName',
                              callType: 'consultation',
                            );
                          } catch (_) {}
                        }
                      }

                      // Navigate to chat screen (NOT video directly)
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ConsultationChatScreenV2(
                            appointment: appointment,
                            isDoctor: isDoctor,
                            currentUserId: currentUserId,
                            currentUserName: currentUserName,
                            consultationId: consultationId,
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(result['message'] ?? 'Failed to start consultation'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } catch (e) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
            ],
          )
        : (appointment.status.toLowerCase() == 'pending' ||
            appointment.status.toLowerCase() == 'confirmed')
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: CustomButton(
                  height: isDesktop ? 48 : Utils.windowHeight(context) * 0.055,
                  borderRadius: 30,
                  labelSize: 15,
                  label: "View",
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => ProfileOrAppointmentViewScreen(
                          appointment: appointment,
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(width: ScallingConfig.scale(10)),
              Expanded(
                child: CustomButton(
                  borderRadius: 30,
                  labelSize: 15,
                  labelColor: AppColors.primaryColor,
                  height: isDesktop ? 48 : Utils.windowHeight(context) * 0.055,
                  label: "Cancel",
                  outlined: true,
                  onPressed: () {
                    // TODO: Implement cancel logic
                  },
                ),
              ),
            ],
          )
        : appointment.status.toLowerCase() == 'cancelled'
        ? CustomButton(
            label: "View Appointment",
            height: Utils.windowHeight(context) * 0.055,
            borderRadius: 30,
            labelSize: 15,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) =>
                      ProfileOrAppointmentViewScreen(appointment: appointment),
                ),
              );
            },
          )
        : appointment.status.toLowerCase() == 'completed'
        ? Row(
            children: [
              Expanded(
                child: CustomButton(
                  label: "View Details",
                  height: Utils.windowHeight(context) * 0.055,
                  borderRadius: 30,
                  labelSize: 15,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => ProfileOrAppointmentViewScreen(
                          appointment: appointment,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          )
        : Row(
            children: [
              Expanded(
                child: CustomButton(
                  label: "Message",
                  height: Utils.windowHeight(context) * 0.055,
                  borderRadius: 30,
                  labelSize: 15,
                  outlined: true,
                  onPressed: () {
                    final targetUser = selectedRole == "Doctor"
                        ? appointment.patient
                        : appointment.doctor;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => ChatScreen(
                          userId: targetUser?.id ?? "",
                          userName: selectedRole == "Doctor"
                              ? appointment.patientName
                              : appointment.doctorName,
                          userImage: targetUser?.profilePicture,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CustomButton(
                  label: "View Details",
                  height: Utils.windowHeight(context) * 0.1,
                  borderRadius: 30,
                  labelSize: 15,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => ProfileOrAppointmentViewScreen(
                          appointment: appointment,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );

    final currentUser = ref.watch(authProvider).user;
    return isDesktop
        ? _WebBookingCard(
            appointment: appointment,
            onTap: onTap,
            showActions: showActions,
            selectedRole: selectedRole,
            currentUserName: currentUser?.name ?? '',
            currentUserId: currentUser?.id ?? '',
          )
        : GestureDetector(
            onTap: onTap ?? () {},
            child: Container(
              width: Utils.windowWidth(context) * 0.75,
              margin: EdgeInsets.only(top: ScallingConfig.verticalScale(12)),
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: ScallingConfig.verticalScale(12),
              ),
              decoration: BoxDecoration(
                color: AppColors.white,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.veryLightGrey.withValues(alpha: 0.5),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CustomText(
                        text:
                            "${DateFormat('MMM dd, yyyy').format(appointment.date)} - ${appointment.timeSlot}",
                        color: AppColors.primary500,
                        fontSize: 12,
                        fontFamily: "Gilroy-SemiBold",
                      ),
                      if (appointment.status.toLowerCase() == 'pending' ||
                          appointment.status.toLowerCase() == 'confirmed')
                        reminder,
                    ],
                  ),
                  SizedBox(height: ScallingConfig.scale(10)),
                  Row(
                    children: [
                      Container(
                        width: Utils.windowWidth(context) * 0.22,
                        height: Utils.windowWidth(context) * 0.22,
                        decoration: BoxDecoration(
                          color: AppColors.darkGray400,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Image.asset(
                          selectedRole == "Patient"
                              ? ImagePaths.walkthrough1
                              : ImagePaths.user1,
                          fit: selectedRole == "Patient"
                              ? BoxFit.contain
                              : BoxFit.cover,
                        ),
                      ),
                      SizedBox(width: ScallingConfig.scale(12)),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            CustomText(
                              width: double.infinity,
                              text: selectedRole == "Patient"
                                  ? appointment.doctorName
                                  : (appointment.patient?.name ?? "Patient"),
                              isSemiBold: true,
                              textAlign: TextAlign.start,
                            ),
                            SizedBox(height: ScallingConfig.scale(5)),
                            Row(
                              children: [
                                SvgWrapper(assetPath: ImagePaths.location),
                                SizedBox(
                                  width: Utils.windowWidth(context) * 0.025,
                                ),
                                CustomText(
                                  text: "20 Cooper Square, USA",
                                  fontSize: 12,
                                  color: AppColors.darkGreyColor,
                                ),
                              ],
                            ),
                            SizedBox(height: ScallingConfig.scale(6)),
                            Row(
                              children: [
                                SvgWrapper(assetPath: ImagePaths.scan),
                                SizedBox(
                                  width: Utils.windowWidth(context) * 0.025,
                                ),
                                CustomText(
                                  text:
                                      "Booking ID: #${appointment.id.length > 8 ? appointment.id.substring(appointment.id.length - 8).toUpperCase() : appointment.id.toUpperCase()}",
                                  fontSize: 12,
                                  color: AppColors.darkGreyColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ScallingConfig.scale(20)),
                  if (showActions) action,
                ],
              ),
            ),
          );
  }
}

class _WebBookingCard extends StatefulWidget {
  final AppointmentDetail appointment;
  final VoidCallback? onTap;
  final bool showActions;
  final String selectedRole;
  final String currentUserName;
  final String currentUserId;

  const _WebBookingCard({
    required this.appointment,
    this.onTap,
    required this.showActions,
    required this.selectedRole,
    this.currentUserName = '',
    this.currentUserId = '',
  });

  @override
  State<_WebBookingCard> createState() => _WebBookingCardState();
}

class _WebBookingCardState extends State<_WebBookingCard> {
  bool _isHovered = false;
  bool _remindMe = true;
  bool _isCollapsed = false;

  Future<void> _viewPrescription() async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final consultationService = ConsultationService();
      final result = await consultationService.getConsultationByAppointmentId(
        widget.appointment.id,
      );
      if (!mounted) return;
      Navigator.pop(context);

      if (result['success'] == true && result['consultation'] != null) {
        final consultation = result['consultation'] as Map<String, dynamic>;
        // prescriptionId may be a String (ObjectId) or a Map (if populated)
        final rawPrescId = consultation['prescriptionId'];
        final prescriptionId = rawPrescId is Map
            ? rawPrescId['_id']?.toString() ?? ''
            : rawPrescId?.toString() ?? '';

        if (prescriptionId.isNotEmpty) {
          final prescription = await consultationService.getPrescription(prescriptionId);
          if (!mounted) return;
          if (prescription != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PrescriptionDetailScreen(prescription: prescription),
              ),
            );
            return;
          }
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No prescription found for this appointment'),
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
    Color statusColor =
        widget.appointment.status.toLowerCase() == 'confirmed' ||
            widget.appointment.status.toLowerCase() == 'pending'
        ? const Color(0xFF3B82F6)
        : widget.appointment.status.toLowerCase() == 'cancelled'
        ? const Color(0xFFEF4444)
        : widget.appointment.status.toLowerCase() == 'in_progress'
        ? const Color(0xFF8B5CF6)
        : const Color(0xFF22C55E);

    String statusLabel = widget.appointment.status.toLowerCase() == 'in_progress'
        ? 'CONSULTATION IN PROGRESS'
        : widget.appointment.status.toUpperCase();

    final isCompleted = widget.appointment.status.toLowerCase() == 'completed';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHovered
                  ? statusColor.withValues(alpha: 0.3)
                  : const Color(0xFFF1F4F9),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? const Color(0xFF000000).withValues(alpha: 0.06)
                    : const Color(0xFF000000).withValues(alpha: 0.04),
                blurRadius: _isHovered ? 24 : 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top Bar: Date, Status, Collapse button
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat(
                              'MMM dd, yyyy',
                            ).format(widget.appointment.date),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: Color(0xFFCBD5E1),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.appointment.timeSlot,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Collapse / expand toggle (X / chevron)
                    GestureDetector(
                      onTap: () => setState(() => _isCollapsed = !_isCollapsed),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _isCollapsed
                              ? const Color(0xFFF1F5F9)
                              : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _isCollapsed
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.close_rounded,
                          size: 18,
                          color: _isCollapsed
                              ? const Color(0xFF64748B)
                              : const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (!_isCollapsed) ...[
              const Divider(
                height: 1,
                color: Color(0xFFF1F5F9),
                thickness: 1.5,
              ),

              // Main Content Info
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    // Profile Image
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: const Color(0xFFF1F5F9),
                        image: DecorationImage(
                          image: AssetImage(
                            widget.selectedRole == "Patient"
                                ? ImagePaths.walkthrough1
                                : ImagePaths.user1,
                          ),
                          fit: widget.selectedRole == "Patient"
                              ? BoxFit.contain
                              : BoxFit.cover,
                        ),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Doctor Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.selectedRole == "Doctor"
                                ? widget.appointment.patientName
                                : (widget.appointment.doctor?.name ?? "Doctor"),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                              fontFamily: "Gilroy-Bold",
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                size: 14,
                                color: Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  "20 Cooper Square, New York, USA",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.qr_code_rounded,
                                size: 14,
                                color: Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "ID: #${widget.appointment.id.length > 8 ? widget.appointment.id.substring(widget.appointment.id.length - 8).toUpperCase() : widget.appointment.id.toUpperCase()}",
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),

                    // Remind Me Toggle (Only for Upcoming)
                    if (widget.appointment.status.toLowerCase() == 'pending' ||
                        widget.appointment.status.toLowerCase() == 'confirmed')
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              "Remind Me",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 12),
                            FlutterSwitch(
                              width: 38,
                              height: 20,
                              toggleSize: 14,
                              value: _remindMe,
                              borderRadius: 20,
                              padding: 3,
                              activeColor: AppColors.primaryColor,
                              inactiveColor: const Color(0xFFCBD5E1),
                              onToggle: (val) =>
                                  setState(() => _remindMe = val),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Bottom Actions
              if (widget.showActions)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Spacer(),
                      if (widget.appointment.status.toLowerCase() ==
                              'pending' ||
                          widget.appointment.status.toLowerCase() ==
                              'confirmed') ...[
                        _buildWebButton(
                          "Cancel Appointment",
                          onPressed: () {},
                          isOutlined: true,
                        ),
                        const SizedBox(width: 12),
                        // Doctor sees "Start Consultation"; Patient sees "View Details"
                        if (widget.selectedRole == 'Doctor' &&
                            widget.appointment.status.toLowerCase() == 'confirmed') ...[
                          _buildWebButton(
                            "Start Consultation",
                            onPressed: () async {
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
                                  appointmentId: widget.appointment.id ?? '',
                                  patientId: widget.appointment.patient?.id ?? '',
                                  doctorId: widget.appointment.doctor?.id ?? currentUserId,
                                );

                                if (context.mounted) Navigator.pop(context);

                                if (result['success'] == true && context.mounted) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (ctx) => ConsultationChatScreenV2(
                                        appointment: widget.appointment,
                                        isDoctor: true,
                                        currentUserId: currentUserId,
                                        currentUserName: currentUserName,
                                        consultationId: result['consultationId']?.toString(),
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
                          ),
                        ] else ...[
                          _buildWebButton(
                            "View Full Details",
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (ctx) =>
                                      ProfileOrAppointmentViewScreen(
                                        appointment: widget.appointment,
                                      ),
                                ),
                              );
                            },
                          ),
                        ],
                      ] else if (widget.appointment.status.toLowerCase() ==
                          'in_progress') ...[
                        // Consultation in Progress — Rejoin button
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF8B5CF6),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Consultation in Progress',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF8B5CF6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
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
                              final callService = CallService();
                              final sharedPref = SharedPref();

                              final userData = await sharedPref.getUserData();
                              final currentUserId = userData?.id ?? '';
                              final currentUserName = userData?.name ?? 'User';
                              final isDoctor = widget.selectedRole == 'Doctor';

                              // Start consultation session in backend
                              final result = await consultationService.startConsultationV2(
                                appointmentId: widget.appointment.id ?? '',
                                patientId: widget.appointment.patient?.id ?? '',
                                doctorId: widget.appointment.doctor?.id ?? '',
                              );

                              // Always close loading dialog first
                              if (Navigator.canPop(context)) Navigator.pop(context);

                              if (result['success'] == true) {
                                // Null-safe consultation ID — pass null if empty so screen doesn't re-create
                                final rawId = result['consultationId']?.toString() ?? '';
                                final consultationId = rawId.isNotEmpty ? rawId : null;

                                // Fire-and-forget: notify patient (never blocks the flow)
                                if (isDoctor && consultationId != null) {
                                  final patientId = widget.appointment.patient?.id ?? '';
                                  if (patientId.isNotEmpty) {
                                    callService.initiateCall(
                                      receiverId: patientId,
                                      channelName: consultationId,
                                      callerName: 'Dr. $currentUserName',
                                      callType: 'consultation',
                                    ).catchError((_) {});
                                  }
                                }

                                if (mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ConsultationChatScreenV2(
                                        appointment: widget.appointment,
                                        isDoctor: isDoctor,
                                        currentUserId: currentUserId,
                                        currentUserName: currentUserName,
                                        consultationId: consultationId,
                                      ),
                                    ),
                                  );
                                }
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(result['message'] ?? 'Failed to start consultation'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              if (Navigator.canPop(context)) Navigator.pop(context); // Close loading
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.video_call_rounded, size: 18),
                          label: const Text('Rejoin Consultation',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ] else if (widget.appointment.status.toLowerCase() ==
                          'cancelled') ...[
                        _buildWebButton(
                          "View Details",
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) =>
                                    ProfileOrAppointmentViewScreen(
                                      appointment: widget.appointment,
                                    ),
                              ),
                            );
                          },
                        ),
                      ] else if (isCompleted) ...[
                        // Completed: View Prescription + View Details
                        _buildWebButton(
                          "View Prescription",
                          onPressed: _viewPrescription,
                          icon: Icons.description_outlined,
                          color: const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 12),
                        _buildWebButton(
                          "View Details",
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) =>
                                    ProfileOrAppointmentViewScreen(
                                      appointment: widget.appointment,
                                    ),
                              ),
                            );
                          },
                        ),
                      ] else ...[
                        _buildWebButton(
                          "Send Message",
                          onPressed: () {
                            final targetUser = widget.selectedRole == "Doctor"
                                ? widget.appointment.patient
                                : widget.appointment.doctor;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) => ChatScreen(
                                  userId: targetUser?.id ?? "",
                                  userName: widget.selectedRole == "Doctor"
                                      ? widget.appointment.patientName
                                      : widget.appointment.doctorName,
                                  userImage: targetUser?.profilePicture,
                                ),
                              ),
                            );
                          },
                          icon: Icons.chat_bubble_rounded,
                        ),
                        const SizedBox(width: 12),
                        _buildWebButton(
                          "View Details",
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) =>
                                    ProfileOrAppointmentViewScreen(
                                      appointment: widget.appointment,
                                    ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ], // end if (!_isCollapsed)
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebButton(
    String label, {
    required VoidCallback onPressed,
    bool isOutlined = false,
    IconData? icon,
    Color? color,
  }) {
    final bgColor = color ?? AppColors.primaryColor;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: isOutlined ? Colors.white : bgColor,
        foregroundColor: isOutlined ? const Color(0xFF64748B) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isOutlined
              ? const BorderSide(color: Color(0xFFE2E8F0), width: 1.5)
              : BorderSide.none,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 8)],
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFamily: "Gilroy-Bold",
            ),
          ),
        ],
      ),
    );
  }
}
