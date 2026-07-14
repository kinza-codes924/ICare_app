import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/services/payment_service.dart';
import 'package:icare/services/appointment_service.dart';
import 'package:icare/services/consultation_service.dart';
import 'package:icare/screens/consultation_chat_screen_v2.dart';
import 'package:icare/models/appointment_detail.dart';
import 'package:icare/models/user.dart';

/// Landing page for Safepay's redirect after checkout. This may be a brand
/// new browser tab with no memory of the app's in-flight flow (e.g. Connect
/// Now's payment screen), so it resolves the payment itself: if it was a
/// Connect Now instant-consultation payment, it starts the consultation and
/// enters the chat directly instead of just linking to the dashboard.
class PaymentSuccessScreen extends StatefulWidget {
  final bool cancelled;
  final String? paymentId;
  const PaymentSuccessScreen({super.key, this.cancelled = false, this.paymentId});

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    if (!widget.cancelled && (widget.paymentId ?? '').isNotEmpty) {
      _resolvePayment();
    }
  }

  Future<void> _resolvePayment() async {
    if (!mounted) return;
    setState(() => _resolving = true);
    try {
      final result = await PaymentService().verifyPayment(widget.paymentId!);
      if (!mounted) return;
      if (result['status'] == 'paid' && result['type'] == 'appointment') {
        final apptId = result['refId']?.toString();
        if (apptId != null && apptId.isNotEmpty) {
          final appt = await AppointmentService().getAppointmentById(apptId);
          final channelName = appt?['channel_name']?.toString() ?? '';
          if (channelName.startsWith('connect_now_') && appt != null && mounted) {
            await _enterConsultationChat(apptId, appt, channelName);
            return; // navigated away — no further UI to build here
          }
        }
      }
    } catch (_) {
      // Fall through to the generic static message below — the original
      // tab's polling, the webhook, and reconcile-mine will still fulfil it.
    }
    if (mounted) setState(() => _resolving = false);
  }

  Future<void> _enterConsultationChat(
    String appointmentId,
    Map<String, dynamic> appt,
    String channelName,
  ) async {
    final patientId = appt['patient_id']?.toString() ?? '';
    final doctorId = appt['doctor_id']?.toString() ?? '';

    final userData = await SharedPref().getUserData();
    final patientName = (userData?.name.trim().isNotEmpty == true) ? userData!.name.trim() : 'Patient';
    String doctorName = 'Doctor';
    try {
      final profile = await AppointmentService().getDoctorProfile(doctorId);
      doctorName = profile?['name']?.toString() ?? profile?['username']?.toString() ?? 'Doctor';
    } catch (_) {}

    final result = await ConsultationService().startConsultationV2(
      appointmentId: appointmentId,
      patientId: patientId,
      doctorId: doctorId,
      channelName: channelName,
    );

    if (!mounted) return;

    if (result['success'] != true) {
      setState(() => _resolving = false);
      return;
    }

    final appointment = AppointmentDetail(
      id: appointmentId,
      patient: User(id: patientId, name: patientName, email: '', phoneNumber: '', role: 'patient'),
      doctor: User(id: doctorId, name: doctorName, email: '', phoneNumber: '', role: 'doctor'),
      status: 'confirmed',
      timeSlot: 'Now',
      date: DateTime.now(),
      channelName: channelName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ConsultationChatScreenV2(
          consultationId: result['consultationId']?.toString(),
          appointment: appointment,
          isDoctor: false,
          currentUserId: patientId,
          currentUserName: patientName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.cancelled ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: _resolving
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 24),
                    Text(
                      'Confirming your payment…',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.cancelled ? Icons.cancel_rounded : Icons.check_circle_rounded,
                        color: color,
                        size: 54,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      widget.cancelled ? 'Payment Cancelled' : 'Payment Successful!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        fontFamily: 'Gilroy-Bold',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.cancelled
                          ? 'You cancelled the payment — no money was charged. You can try again anytime.'
                          : 'Your payment has been received. If you still have the iCare tab open, it will '
                            'update automatically — otherwise everything you paid for is being activated '
                            'on your account right now.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, color: Color(0xFF64748B), height: 1.55),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.go('/dashboard'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text('Go to Dashboard',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'You can safely close this tab.',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
