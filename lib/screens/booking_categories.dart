import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/models/app_enums.dart';
import 'package:icare/models/appointment_detail.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/screens/video_call.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/boooking_card.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/test_appointment.dart';

class BookingCategories extends StatefulWidget {
  const BookingCategories({
    super.key,
    required this.appointments,
    this.initialTabIndex = 0,
  });
  final List<AppointmentDetail> appointments;
  final int initialTabIndex;

  @override
  State<BookingCategories> createState() => _BookingCategoriesState();
}

class _BookingCategoriesState extends State<BookingCategories>
    with SingleTickerProviderStateMixin {
  late TabController controller;

  @override
  void initState() {
    super.initState();
    controller = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width > 600) {
      return _WebBookingCategories(
        tabController: controller,
        appointments: widget.appointments,
      );
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: CustomBackButton(),
        title: CustomText(text: "Upcoming".tr()),
        bottom: TabBar(
          controller: controller,
          indicatorWeight: 6,
          indicatorColor: AppColors.themeBlack,
          tabs: [
            CustomText(
              text: "Upcoming".tr(),
              padding: EdgeInsets.only(bottom: 5),
              width: Utils.windowWidth(context) * 0.25,
              textAlign: TextAlign.center,
            ),
            CustomText(
              text: "Pending".tr(),
              padding: EdgeInsets.only(bottom: 5),
              width: Utils.windowWidth(context) * 0.25,
              textAlign: TextAlign.center,
            ),
            CustomText(
              padding: EdgeInsets.only(bottom: 5),
              width: Utils.windowWidth(context) * 0.25,
              textAlign: TextAlign.center,
              text: "Completed".tr(),
            ),
            CustomText(
              text: "Cancelled".tr(),
              padding: EdgeInsets.only(bottom: 5),
              width: Utils.windowWidth(context) * 0.25,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: controller,
        children: [
          // Tab 0: Upcoming (confirmed)
          UpcomingBOokingsList(
            status: BookingStatus.upcoming,
            data: widget.appointments
                .where((a) => a.status.toLowerCase() == 'confirmed')
                .toList(),
          ),
          // Tab 1: Pending
          UpcomingBOokingsList(
            status: BookingStatus.upcoming,
            data: widget.appointments
                .where((a) => a.status.toLowerCase() == 'pending')
                .toList(),
          ),
          // Tab 2: Completed
          UpcomingBOokingsList(
            status: BookingStatus.completed,
            data: widget.appointments
                .where((a) => a.status.toLowerCase() == 'completed')
                .toList(),
          ),
          // Tab 3: Cancelled
          UpcomingBOokingsList(
            status: BookingStatus.cancelled,
            data: widget.appointments
                .where((a) => a.status.toLowerCase() == 'cancelled')
                .toList(),
          ),
        ],
      ),
    );
  }
}

class UpcomingBOokingsList extends ConsumerWidget {
  const UpcomingBOokingsList({super.key, this.data, this.status});
  final List<dynamic>? data;
  final BookingStatus? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRole = ref.watch(authProvider).userRole;
    final currentUser = ref.watch(authProvider).user;
    return ListView.builder(
      itemCount: data!.length,
      padding: EdgeInsets.only(
        right: ScallingConfig.scale(20),
        bottom: ScallingConfig.scale(40),
        left: ScallingConfig.scale(20),
      ),
      itemBuilder: (ctx, i) {
        final appointment = data![i] as AppointmentDetail;
        if (selectedRole == "lab_technician") return TestAppointment(status: status);

        final isInProgress = appointment.status.toLowerCase() == 'in_progress';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BookingCard(appointment: appointment, showActions: !isInProgress),
            if (isInProgress)
              Padding(
                padding: EdgeInsets.only(bottom: ScallingConfig.scale(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fiber_manual_record, color: Color(0xFF8B5CF6), size: 10),
                          SizedBox(width: 8),
                          Text('Consultation in Progress'.tr(),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        String channelName = appointment.id;
                        final notes = appointment.reason ?? '';
                        final match = RegExp(r'Channel:\s*(\S+)').firstMatch(notes);
                        if (match != null) channelName = match.group(1)!;
                        Navigator.of(ctx).push(
                          MaterialPageRoute(
                            builder: (_) => VideoCall(
                              channelName: channelName,
                              remoteUserName: selectedRole == 'Doctor'
                                  ? appointment.patientName
                                  : appointment.doctorName,
                              appointmentId: appointment.id,
                              currentUserName: currentUser?.name ?? '',
                              currentUserId: currentUser?.id ?? '',
                              patientId: appointment.patient?.id,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.video_call_rounded, size: 18),
                      label: Text('Rejoin Consultation'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PREMIUM WEB BOOKING CATEGORIES
// ═══════════════════════════════════════════════════════════════════════════════

class _WebBookingCategories extends StatefulWidget {
  final TabController tabController;
  final List<AppointmentDetail> appointments;
  const _WebBookingCategories({
    required this.tabController,
    required this.appointments,
  });

  @override
  State<_WebBookingCategories> createState() => _WebBookingCategoriesState();
}

class _WebBookingCategoriesState extends State<_WebBookingCategories> {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.tabController.index;
    widget.tabController.addListener(() {
      if (widget.tabController.indexIsChanging) {
        setState(() {
          _selectedTab = widget.tabController.index;
        });
      }
    });
  }

  static const List<Map<String, dynamic>> _tabs = [
    {
      "label": "Upcoming",
      "icon": Icons.schedule_rounded,
      "color": Color(0xFF3B82F6),
      "status": BookingStatus.upcoming,
    },
    {
      "label": "Pending",
      "icon": Icons.hourglass_empty_rounded,
      "color": Color(0xFFF59E0B),
      "status": BookingStatus.upcoming,
    },
    {
      "label": "Completed",
      "icon": Icons.check_circle_outline_rounded,
      "color": Color(0xFF22C55E),
      "status": BookingStatus.completed,
    },
    {
      "label": "Cancelled",
      "icon": Icons.cancel_outlined,
      "color": Color(0xFFEF4444),
      "status": BookingStatus.cancelled,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: CustomBackButton(),
        title: CustomText(
          text: "Booking Details".tr(),
          fontFamily: "Gilroy-Bold",
          fontSize: 20,
          color: AppColors.primaryColor,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.31,
          lineHeight: 1.0,
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Left Sidebar ──
                  SizedBox(
                    width: 280,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Filter by Status".tr(),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                            fontFamily: "Gilroy-Bold",
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Select a category to view your bookings".tr(),
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Tab buttons
                        ...List.generate(_tabs.length, (index) {
                          final tab = _tabs[index];
                          final isSelected = _selectedTab == index;
                          final Color color = tab["color"];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedTab = index;
                                  });
                                  widget.tabController.animateTo(index);
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? color.withValues(alpha: 0.08)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? color.withValues(alpha: 0.3)
                                          : const Color(0xFFE2E8F0),
                                      width: 1.5,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: color.withValues(alpha: 0.1),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? color.withValues(alpha: 0.15)
                                              : const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          tab["icon"],
                                          color: isSelected
                                              ? color
                                              : const Color(0xFF94A3B8),
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          (tab["label"] as String).tr(),
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? color
                                                : const Color(0xFF64748B),
                                            fontFamily: "Gilroy-SemiBold",
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? color.withValues(alpha: 0.15)
                                              : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          widget.appointments
                                              .where((a) {
                                                if (index == 0) {
                                                  return a.status.toLowerCase() == 'confirmed';
                                                }
                                                if (index == 1) {
                                                  return a.status.toLowerCase() == 'pending';
                                                }
                                                if (index == 2) {
                                                  return a.status.toLowerCase() == 'completed';
                                                }
                                                return a.status.toLowerCase() == 'cancelled';
                                              })
                                              .length
                                              .toString(),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: isSelected
                                                ? color
                                                : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),

                        const SizedBox(height: 28),

                        // Stats summary
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFF1F4F9),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Quick Stats".tr(),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                  fontFamily: "Gilroy-Bold",
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildStatRow(
                                "Total Bookings".tr(),
                                widget.appointments.length.toString(),
                                const Color(0xFF3B82F6),
                              ),
                              const SizedBox(height: 12),
                              _buildStatRow(
                                "In Progress".tr(),
                                widget.appointments
                                    .where((a) => a.status.toLowerCase() == 'in_progress')
                                    .length
                                    .toString(),
                                const Color(0xFF8B5CF6),
                              ),
                              const SizedBox(height: 12),
                              _buildStatRow(
                                "Upcoming".tr(),
                                widget.appointments
                                    .where(
                                      (a) =>
                                          a.status.toLowerCase() == 'pending' ||
                                          a.status.toLowerCase() == 'confirmed',
                                    )
                                    .length
                                    .toString(),
                                const Color(0xFF3B82F6),
                              ),
                              const SizedBox(height: 12),
                              _buildStatRow(
                                "Cancelled".tr(),
                                widget.appointments
                                    .where(
                                      (a) =>
                                          a.status.toLowerCase() == 'cancelled',
                                    )
                                    .length
                                    .toString(),
                                const Color(0xFFEF4444),
                              ),
                              const SizedBox(height: 12),
                              _buildStatRow(
                                "Completed".tr(),
                                widget.appointments
                                    .where(
                                      (a) =>
                                          a.status.toLowerCase() == 'completed',
                                    )
                                    .length
                                    .toString(),
                                const Color(0xFF22C55E),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 32),

                  // ── Right: Booking Cards ──
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tab header
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 20,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                            border: Border.all(
                              color: const Color(0xFFF1F4F9),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _tabs[_selectedTab]["icon"],
                                color: _tabs[_selectedTab]["color"],
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "${(_tabs[_selectedTab]["label"] as String).tr()} ${'Bookings'.tr()}",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                  fontFamily: "Gilroy-Bold",
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: (_tabs[_selectedTab]["color"] as Color)
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "${widget.appointments.where((a) {
                                    if (_selectedTab == 0) return a.status.toLowerCase() == 'confirmed';
                                    if (_selectedTab == 1) return a.status.toLowerCase() == 'pending';
                                    if (_selectedTab == 2) return a.status.toLowerCase() == 'completed';
                                    return a.status.toLowerCase() == 'cancelled';
                                  }).length} ${'bookings'.tr()}",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _tabs[_selectedTab]["color"],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Booking cards list
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(20),
                            ),
                            border: Border.all(
                              color: const Color(0xFFF1F4F9),
                              width: 1.5,
                            ),
                          ),
                          child: _WebBookingList(
                            status: _tabs[_selectedTab]["status"],
                            data: widget.appointments.where((a) {
                              if (_selectedTab == 0) {
                                return a.status.toLowerCase() == 'confirmed';
                              }
                              if (_selectedTab == 1) {
                                return a.status.toLowerCase() == 'pending';
                              }
                              if (_selectedTab == 2) {
                                return a.status.toLowerCase() == 'completed';
                              }
                              return a.status.toLowerCase() == 'cancelled';
                            }).toList(),
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
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _WebBookingList extends ConsumerWidget {
  const _WebBookingList({required this.status, required this.data});
  final BookingStatus status;
  final List<dynamic> data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRole = ref.watch(authProvider).userRole;
    final currentUser = ref.watch(authProvider).user;
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: data.length,
      separatorBuilder: (context, index) =>
          const Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1),
      itemBuilder: (ctx, i) {
        final appointment = data[i] as AppointmentDetail;
        if (selectedRole == "lab_technician") return TestAppointment(status: status);

        final isInProgress = appointment.status.toLowerCase() == 'in_progress';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BookingCard(appointment: appointment, showActions: !isInProgress),
            if (isInProgress)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.05),
                  border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10, height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF8B5CF6), shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Consultation in Progress',
                        style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Use stored channelName, fallback to notes, then appointment id
                        String channelName = appointment.channelName?.isNotEmpty == true
                            ? appointment.channelName!
                            : appointment.id;
                        final notes = appointment.reason ?? '';
                        final match = RegExp(r'Channel:\s*(\S+)').firstMatch(notes);
                        if (match != null && channelName == appointment.id) {
                          channelName = match.group(1)!;
                        }
                        Navigator.of(ctx).push(
                          MaterialPageRoute(
                            builder: (_) => VideoCall(
                              channelName: channelName,
                              remoteUserName: selectedRole == 'Doctor'
                                  ? appointment.patientName
                                  : appointment.doctorName,
                              appointmentId: appointment.id,
                              currentUserName: currentUser?.name ?? '',
                              currentUserId: currentUser?.id ?? '',
                              patientId: appointment.patient?.id,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.video_call_rounded, size: 18),
                      label: const Text(
                        'Rejoin',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
