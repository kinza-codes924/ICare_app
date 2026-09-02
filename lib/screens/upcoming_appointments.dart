import 'package:easy_date_timeline/easy_date_timeline.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/models/appointment_detail.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/screens/consultation_chat_screen_v2.dart';
import 'package:icare/screens/select_payment_method.dart';
import 'package:icare/services/api_config.dart';
import 'package:icare/services/appointment_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:url_launcher/url_launcher.dart';

/// Real upcoming-appointments list — pick a date on the calendar strip to
/// see that day's appointments (confirmed/pending only). Previously this
/// screen showed 4 hardcoded placeholder cards regardless of real data.
class UpcomingAppointments extends ConsumerStatefulWidget {
  const UpcomingAppointments({super.key});

  @override
  ConsumerState<UpcomingAppointments> createState() => _UpcomingAppointmentsState();
}

class _UpcomingAppointmentsState extends ConsumerState<UpcomingAppointments> {
  final _appointmentService = AppointmentService();
  // Explicitly today, not left null — EasyDateTimeLinePicker's focusedDate
  // falls back to its firstDate (30 days ago) when null, which is why the
  // strip opened on a stale month (e.g. "stuck on July") instead of today.
  DateTime? _selectedDate = DateTime.now();
  bool _loading = true;
  String? _error;
  List<AppointmentDetail> _appointments = [];

  static const _navy = Color(0xFF0F172A);
  static const _slate = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _appointmentService.getMyAppointmentsDetailed();
      if (!mounted) return;
      if (result['success'] == true) {
        final all = (result['appointments'] as List<AppointmentDetail>?) ?? [];
        setState(() {
          _appointments = all.where((a) => a.status == 'confirmed' || a.status == 'pending' || a.status == 'in_progress').toList()
            ..sort((a, b) => a.date.compareTo(b.date));
          _loading = false;
        });
      } else {
        setState(() { _error = result['message']?.toString() ?? 'Could not load appointments'; _loading = false; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  List<AppointmentDetail> get _appointmentsForSelectedDate {
    final day = _selectedDate ?? DateTime.now();
    return _appointments.where((a) => _isSameDay(a.date, day)).toList();
  }

  // What's coming up on any LATER date, so an empty day can point the patient
  // at where their appointments actually are. Capped — this is a hint, not a
  // second full list.
  List<AppointmentDetail> get _upcomingAfterSelected {
    final day = _selectedDate ?? DateTime.now();
    final cutoff = DateTime(day.year, day.month, day.day);
    final later = _appointments
        .where((a) => DateTime(a.date.year, a.date.month, a.date.day).isAfter(cutoff))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return later.take(5).toList();
  }

  Widget _upcomingJumpTile(AppointmentDetail appt) {
    final unpaid = appt.status.toLowerCase() == 'pending' &&
        appt.paymentStatus.toLowerCase() != 'paid';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        // Jump the picker to that date so the full card is one tap away.
        onTap: () => setState(() => _selectedDate = appt.date),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (unpaid ? const Color(0xFFEF4444) : _navy).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.event_rounded,
                  size: 16, color: unpaid ? const Color(0xFFEF4444) : _navy),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    appt.doctor?.name != null ? withDoctorTitle(appt.doctor!.name) : 'Doctor',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _navy),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat('EEE, d MMM').format(appt.date)}  ·  ${appt.timeSlot}',
                    style: const TextStyle(fontSize: 12, color: _slate, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (unpaid)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Payment Pending',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFEF4444))),
              )
            else
              const Icon(Icons.chevron_right_rounded, size: 18, color: _slate),
          ]),
        ),
      ),
    );
  }

  void _openConsultation(AppointmentDetail appt) {
    final user = ref.read(authProvider).user;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConsultationChatScreenV2(
          appointment: appt,
          isDoctor: false,
          currentUserId: user?.id ?? '',
          currentUserName: user?.name ?? 'Patient',
        ),
      ),
    );
  }

  void _onTileTap(AppointmentDetail appt) {
    // A patient never "starts" a consultation — that's the doctor's action.
    // Only join if a session is already actually live; otherwise this is a
    // plain, view-only details sheet, no action button.
    if (appt.status == 'in_progress') {
      _openConsultation(appt);
      return;
    }
    _showAppointmentDetails(appt);
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: _slate),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(fontSize: 13.5, color: _slate, fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13.5, color: _navy, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showAppointmentDetails(AppointmentDetail appt) {
    final statusLabel = appt.status == 'confirmed'
        ? 'Confirmed'
        : (appt.paymentStatus.toLowerCase() != 'paid'
            ? 'Payment pending — not booked yet'
            : 'Pending');
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(appt.doctor?.name != null ? withDoctorTitle(appt.doctor!.name) : 'Doctor',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _navy)),
            const SizedBox(height: 4),
            Text((appt.consultationType ?? 'Consultation').toUpperCase(),
                style: const TextStyle(fontSize: 11, color: _slate, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
            const SizedBox(height: 20),
            _detailRow(Icons.calendar_today_rounded, 'Date', DateFormat('EEEE, d MMM yyyy').format(appt.date)),
            _detailRow(Icons.access_time_rounded, 'Time', appt.timeSlot),
            _detailRow(Icons.info_outline_rounded, 'Status', statusLabel),
            const SizedBox(height: 8),
            Text(
              'This consultation will open here once your doctor starts the session — you\'ll be notified.',
              style: const TextStyle(fontSize: 12.5, color: _slate, height: 1.5),
            ),
            const SizedBox(height: 16),
            if (appt.status == 'confirmed' || appt.status == 'completed')
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openInvoice(appt),
                  icon: const Icon(Icons.receipt_long_rounded, size: 18),
                  label: const Text('View Invoice'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryColor,
                    side: BorderSide(color: AppColors.primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _openInvoice(AppointmentDetail appt) async {
    final url = '${ApiConfig.baseUrl}/invoices/appointment/${appt.id}/pdf';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open invoice — please try again')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Utils.windowWidth(context) > 600;
    return isDesktop ? _buildDesktop(context) : _buildMobile(context);
  }

  // ─── MOBILE ───────────────────────────────────────────────────────────────
  Widget _buildMobile(BuildContext context) {
    final list = _appointmentsForSelectedDate;
    return Scaffold(
      appBar: AppBar(
        title: CustomText(
          text: "Upcoming Appointments".tr(),
          fontSize: 16.78,
          fontFamily: "Gilroy-Bold",
          letterSpacing: -0.31,
          lineHeight: 1.0,
          color: AppColors.primary500,
          fontWeight: FontWeight.bold,
        ),
        leading: CustomBackButton(),
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Column(
          children: [
            _dateStrip(itemExtent: ScallingConfig.scale(70), compact: true),
            SizedBox(height: ScallingConfig.scale(20)),
            Expanded(child: _bodyContent(list, padding: EdgeInsets.symmetric(horizontal: ScallingConfig.scale(20)))),
            SizedBox(height: Utils.windowHeight(context) * 0.08),
          ],
        ),
      ),
    );
  }

  // ─── DESKTOP ──────────────────────────────────────────────────────────────
  Widget _buildDesktop(BuildContext context) {
    final list = _appointmentsForSelectedDate;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              bottom: 24, left: 48, right: 48,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 4)),
              ],
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => goBackOrHome(context),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(14)),
                            child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 22),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CustomText(text: "Upcoming Appointments".tr(), fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: -0.5),
                              const SizedBox(height: 2),
                              CustomText(text: "Select a date to view your appointments", fontSize: 13, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w400),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: AppColors.primaryColor.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.event_note_rounded, size: 16, color: AppColors.primaryColor),
                              const SizedBox(width: 6),
                              CustomText(text: "${list.length} Appointments", fontSize: 13, color: AppColors.primaryColor, fontWeight: FontWeight.w700),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _dateStrip(itemExtent: 80, compact: false),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: _bodyContent(list, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shared pieces ────────────────────────────────────────────────────────

  Widget _dateStrip({required double itemExtent, required bool compact}) {
    return EasyDateTimeLinePicker.itemBuilder(
      focusedDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      itemExtent: itemExtent,
      itemBuilder: (context, date, isSelected, isDisabled, isToday, onTap) {
        if (compact) {
          return InkWell(
            onTap: onTap,
            child: Container(
              width: ScallingConfig.scale(60),
              height: ScallingConfig.scale(40),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.secondaryColor : AppColors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: ScallingConfig.scale(10)),
                  CustomText(fontSize: 22, fontFamily: "Gilroy-SemiBold", text: date.day.toString(),
                      color: isSelected ? AppColors.white : AppColors.darkGray400),
                  SizedBox(height: ScallingConfig.scale(10)),
                  CustomText(fontSize: 14, fontFamily: "Gilroy-SemiBold", text: DateFormat('EEE').format(date),
                      color: isSelected ? AppColors.white : AppColors.darkGray400),
                ],
              ),
            ),
          );
        }
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 70, height: 90,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryColor : isToday ? AppColors.primaryColor.withValues(alpha: 0.06) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: isToday && !isSelected ? Border.all(color: AppColors.primaryColor.withValues(alpha: 0.2), width: 1.5) : null,
              boxShadow: isSelected ? [BoxShadow(color: AppColors.primaryColor.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))] : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(date.day.toString(), style: TextStyle(fontFamily: "Gilroy", fontSize: 20, fontWeight: FontWeight.w800, color: isSelected ? Colors.white : const Color(0xFF0F172A))),
                const SizedBox(height: 4),
                Text(DateFormat('EEE').format(date), style: TextStyle(fontFamily: "Gilroy", fontSize: 12, fontWeight: FontWeight.w500, color: isSelected ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF94A3B8))),
              ],
            ),
          ),
        );
      },
      onDateChange: (date) => setState(() => _selectedDate = date),
    );
  }

  Widget _bodyContent(List<AppointmentDetail> list, {required EdgeInsets padding}) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: _slate), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ]),
        ),
      );
    }
    if (list.isEmpty) {
      // Picking an empty date used to be a dead end — the patient had to hunt
      // day by day to find where their next appointment actually was. Show
      // what's coming up instead, each row jumping to its own date.
      final upcoming = _upcomingAfterSelected;
      return ListView(
        padding: padding,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 28),
          Center(
            child: Column(
              children: [
                const Icon(Icons.event_busy_rounded, size: 40, color: Color(0xFFCBD5E1)),
                const SizedBox(height: 12),
                Text(
                  'No appointments on ${DateFormat('d MMMM yyyy').format(_selectedDate ?? DateTime.now())}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: _slate, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (upcoming.isNotEmpty) ...[
            const SizedBox(height: 28),
            const Text('Your next appointments',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _navy)),
            const SizedBox(height: 10),
            ...upcoming.map(_upcomingJumpTile),
          ],
        ],
      );
    }
    return ListView.builder(
      padding: padding,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (ctx, i) => _appointmentTile(list[i]),
    );
  }

  Widget _appointmentTile(AppointmentDetail appt) {
    final confirmed = appt.status == 'confirmed' || appt.status == 'in_progress';
    // An unpaid booking is still 'pending', so it showed the same amber
    // "Pending" chip as a paid booking awaiting the doctor — the patient had no
    // way to tell that a cancelled payment hadn't actually booked them a slot.
    final unpaid = !confirmed && appt.paymentStatus.toLowerCase() != 'paid';
    final statusColor = confirmed
        ? const Color(0xFF10B981)
        : (unpaid ? const Color(0xFFEF4444) : const Color(0xFFF59E0B));
    final photo = appt.doctor?.profilePicture;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        onTap: () => _onTileTap(appt),
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipOval(
                  child: Container(
                    width: 48, height: 48,
                    color: AppColors.primaryColor.withValues(alpha: 0.08),
                    child: (photo != null && photo.isNotEmpty)
                        ? Image.network(photo, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(Icons.person_rounded, color: AppColors.primaryColor, size: 26))
                        : Icon(Icons.person_rounded, color: AppColors.primaryColor, size: 26),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(appt.doctor?.name != null ? withDoctorTitle(appt.doctor!.name) : 'Doctor',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900, color: _navy)),
                      const SizedBox(height: 3),
                      Text((appt.consultationType ?? 'Consultation').toUpperCase(),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: _slate, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(confirmed ? 'Confirmed' : (unpaid ? 'Payment Pending' : 'Pending'),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 14, color: _slate),
                const SizedBox(width: 6),
                Text(DateFormat('EEEE, d MMM yyyy').format(appt.date), style: const TextStyle(fontSize: 12.5, color: _navy, fontWeight: FontWeight.w600)),
                const SizedBox(width: 16),
                const Icon(Icons.access_time_rounded, size: 14, color: _slate),
                const SizedBox(width: 6),
                Text(appt.timeSlot, style: const TextStyle(fontSize: 12.5, color: _navy, fontWeight: FontWeight.w600)),
              ],
            ),
            // The slot isn't held until it's paid for, so give the patient the
            // way to finish rather than only telling them it's outstanding.
            if (unpaid) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _proceedToPayment(appt),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.payment_rounded, size: 18),
                  label: const Text('Proceed to payment to confirm your booking',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _proceedToPayment(AppointmentDetail appt) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectPaymentMethod(
          appointmentId: appt.id,
          amount: appt.consultationFee,
          // Same as the booking flow: an app booking is paid online, never
          // "Pay at Clinic".
          isInstant: true,
          onPaymentSuccess: (successContext, {voucherCode}) {
            Navigator.of(successContext).pop();
            _load();
          },
        ),
      ),
    );
  }
}
