import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/models/appointment_detail.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/screens/create_medical_record.dart';
import 'package:icare/screens/decline_appointment_redesign.dart';
import 'package:icare/screens/intake_notes_screen.dart';
import 'package:icare/screens/patient_profile_view.dart';
import 'package:icare/screens/soap_notes_screen.dart';
import 'package:icare/screens/video_call.dart';
import 'package:icare/services/appointment_service.dart';
import 'package:icare/screens/prescription_detail_screen.dart';
import 'package:icare/services/consultation_service.dart';
import 'package:icare/services/review_service.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/svg_wrapper.dart';
import 'package:intl/intl.dart';

class ProfileOrAppointmentViewScreen extends ConsumerWidget {
  final AppointmentDetail appointment;

  const ProfileOrAppointmentViewScreen({super.key, required this.appointment});

  static bool _isAppointmentPast(AppointmentDetail appt) {
    try {
      final parts = appt.timeSlot.split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final isPm = parts.length > 1 && parts[1].toUpperCase() == 'PM';
      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
      return DateTime(appt.date.year, appt.date.month, appt.date.day, hour, minute)
          .isBefore(DateTime.now());
    } catch (_) {
      return appt.date.isBefore(DateTime.now());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRole = ref.watch(authProvider).userRole;
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    if (isDesktop) {
      return _WebPatientProfileView(
        selectedRole: selectedRole,
        appointment: appointment,
      );
    }

    // Get the other person's info based on role
    final otherPerson = selectedRole == 'Doctor'
        ? appointment.patient
        : appointment.doctor;
    final formattedDate = DateFormat('MMMM dd, yyyy').format(appointment.date);

    final statusColor = appointment.status.toLowerCase() == 'confirmed'
        ? const Color(0xFF10B981)
        : appointment.status.toLowerCase() == 'pending'
        ? const Color(0xFFF59E0B)
        : const Color(0xFF94A3B8);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: CustomText(
          text: "Appointment Details",
          letterSpacing: -0.31,
          lineHeight: 1.0,
          fontSize: 16.78,
          fontFamily: "Gilroy-Bold",
          fontWeight: FontWeight.bold,
          color: AppColors.primary500,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ProfileInfoWidget(
              name: otherPerson?.name ?? 'User',
              // Doctors do not see patient contact details
              email: selectedRole == 'Doctor' ? '' : (otherPerson?.email ?? 'N/A'),
              appointmentId: appointment.id,
              patient: appointment.patient,
            ),
            // Status badge
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Text('Status:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      appointment.status.toUpperCase(),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor),
                    ),
                  ),
                ],
              ),
            ),
            DetailsInfoWidget(
              title: "Scheduled Appointment",
              data: {
                "Date": formattedDate,
                "Time": appointment.timeSlot,
                "Booking for": "Self",
              },
            ),
            DetailsInfoWidget(
              title: selectedRole == 'Doctor' ? "Patient Info" : "Doctor Info",
              data: selectedRole == 'Patient'
                  ? {
                      "Name": otherPerson?.name ?? 'N/A',
                      "Reason": appointment.reason ?? 'N/A',
                    }
                  : {
                      // Contact details hidden from doctor — only name + reason visible
                      "Name": otherPerson?.name ?? 'N/A',
                      "Reason": appointment.reason ?? 'N/A',
                    },
            ),
            if (selectedRole == "lab_technician") ...[Tests()],

            if (selectedRole == "Doctor") ...[
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ScallingConfig.scale(20),
                  vertical: ScallingConfig.scale(13),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CustomText(
                      text: "Soap Notes",
                      underline: true,
                      isBold: true,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) =>
                                SoapNotesScreen(appointment: appointment),
                          ),
                        );
                      },
                    ),
                    CustomText(
                      text: "Intake Notes",
                      underline: true,
                      isBold: true,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) =>
                                IntakeNotesScreen(appointment: appointment, isReadOnly: selectedRole == "Doctor"),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: ScallingConfig.scale(15)),

            if (selectedRole == "Doctor" && appointment.status.toLowerCase() == 'pending' && appointment.status.toLowerCase() != 'completed' && appointment.status.toLowerCase() != 'cancelled') ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomButton(
                    width: Utils.windowWidth(context) * 0.35,
                    borderRadius: 30,
                    label: "Accept",
                    onPressed: () async {
                      final result = await AppointmentService()
                          .updateAppointmentStatus(
                            appointmentId: appointment.id,
                            status: 'confirmed',
                          );
                      if (result['success'] && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Appointment accepted')),
                        );
                        Navigator.of(context).pop(true);
                      }
                    },
                  ),
                  SizedBox(width: ScallingConfig.scale(20)),
                  CustomButton(
                    borderRadius: 30,
                    labelColor: AppColors.primaryColor,
                    width: Utils.windowWidth(context) * 0.35,
                    label: "Decline",
                    outlined: true,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => DeclineAppointmentScreen(
                            appointment: appointment,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
            // Patient: Rate & Review after completed appointment
            if (selectedRole == "Patient" && appointment.status.toLowerCase() == 'completed') ...[
              const SizedBox(height: 16),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: ScallingConfig.scale(16)),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showReviewDialog(context, appointment),
                    icon: const Icon(Icons.star_rounded, size: 20),
                    label: const Text('Rate & Review Doctor', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _showReviewDialog(BuildContext context, AppointmentDetail appointment) async {
  final prefs = await SharedPreferences.getInstance();
  final reviewedKey = 'reviewed_${appointment.id}';
  final alreadyReviewed = prefs.getBool(reviewedKey) ?? false;
  if (!context.mounted) return;

  int selectedStars = 0;
  bool? satisfied;
  final reviewController = TextEditingController();
  bool submitting = false;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Rate Your Consultation',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: alreadyReviewed
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 48),
                  SizedBox(height: 12),
                  Text('You have already reviewed this consultation.', textAlign: TextAlign.center),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How would you rate your doctor?',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) => GestureDetector(
                        onTap: () => setDialogState(() => selectedStars = i + 1),
                        child: Icon(
                          i < selectedStars ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: const Color(0xFFF59E0B),
                          size: 40,
                        ),
                      )),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Are you satisfied with the consultation?',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDialogState(() => satisfied = true),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: satisfied == true ? const Color(0xFF10B981) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: satisfied == true ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Yes',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: satisfied == true ? Colors.white : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDialogState(() => satisfied = false),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: satisfied == false ? const Color(0xFFEF4444) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: satisfied == false ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'No',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: satisfied == false ? Colors.white : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Write a review (optional)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reviewController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Share your experience...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        actions: alreadyReviewed
            ? [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ]
            : [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Skip', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: (submitting || selectedStars == 0 || satisfied == null)
                      ? null
                      : () async {
                          setDialogState(() => submitting = true);
                          final result = await ReviewService().submitReview(
                            appointmentId: appointment.id,
                            doctorId: appointment.doctor?.id ?? '',
                            starRating: selectedStars,
                            satisfied: satisfied!,
                            reviewText: reviewController.text.trim(),
                          );
                          await prefs.setBool(reviewedKey, true);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(result['success'] == true
                                      ? 'Thank you for your review!'
                                      : 'Review saved locally.'),
                                  backgroundColor: const Color(0xFF10B981),
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: submitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Submit', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
      ),
    ),
  );
  reviewController.dispose();
}

class ProfileInfoWidget extends StatelessWidget {
  final String name;
  final String email;
  final String appointmentId;
  final dynamic patient;

  const ProfileInfoWidget({
    super.key,
    required this.name,
    required this.email,
    required this.appointmentId,
    required this.patient,
  });

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Container(
      width: Utils.windowWidth(context),
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppColors.white),
      child: Row(
        children: [
          Container(
            width: Utils.windowWidth(context) * 0.25,
            height: Utils.windowWidth(context) * 0.25,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryColor,
                ),
              ),
            ),
          ),
          SizedBox(width: ScallingConfig.scale(12)),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: CustomText(
                        text: name,
                        isSemiBold: true,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(width: ScallingConfig.scale(10)),
                    CustomText(
                      text: "View Full Details",
                      underline: true,
                      onTap: () {
                        if (patient != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) =>
                                  PatientProfileView(patient: patient),
                            ),
                          );
                        }
                      },
                      isSemiBold: true,
                    ),
                  ],
                ),
                SizedBox(height: ScallingConfig.scale(10)),
                Row(
                  children: [
                    SvgWrapper(assetPath: ImagePaths.scan),
                    SizedBox(width: Utils.windowWidth(context) * 0.025),
                    CustomText(
                      text:
                          "Booking ID: #${appointmentId.substring(appointmentId.length - 8)}",
                      fontSize: 12,
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

class DetailsInfoWidget extends StatelessWidget {
  const DetailsInfoWidget({super.key, this.title = '', required this.data});

  final String title;
  final Map<String, String> data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      margin: EdgeInsets.only(top: 12),
      child: SizedBox(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomText(text: title, fontSize: 14, isBold: true),
            ...data.entries.map((item) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CustomText(
                      text: item.key,
                      fontSize: 12,
                      color: AppColors.darkGreyColor,
                    ),
                    CustomText(
                      text: item.value,
                      isBold: true,
                      color: AppColors.darkGreyColor,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class ConsultationTypeCard extends StatelessWidget {
  const ConsultationTypeCard({
    super.key,
    this.chat = false,
    this.call = true,
    required this.duration,
    required this.title,
    required this.description,
  });

  final bool chat;
  final bool call;
  final String duration;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Utils.windowWidth(context) * 0.9,
      padding: EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.darkGreyColor.withAlpha(50)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.darkGreyColor.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.darkGreyColor.withAlpha(40)),
            ),
            child: SvgWrapper(
              assetPath: chat
                  ? ImagePaths.message
                  : call
                  ? ImagePaths.calll
                  : '',
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomText(
                text: title,
                fontFamily: "Gilroy-Medium",
                isBold: true,

                color: AppColors.themeDarkGrey,
                fontSize: 12,
              ),
              CustomText(
                text: description,
                fontSize: 12,
                fontFamily: "Gilroy-Regular",
                color: AppColors.themeDarkGrey,
              ),
            ],
          ),
          CustomText(text: duration),
          Icon(
            Icons.radio_button_checked,
            size: ScallingConfig.scale(20),
            color: AppColors.darkGreyColor.withAlpha(90),
          ),
        ],
      ),
    );
  }
}

class Tests extends StatelessWidget {
  const Tests({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: ScallingConfig.scale(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText(
            // width: Utils.windowWidth(context) * 0.9,
            text: "Test Names",
            fontSize: 14,
            isBold: true,
          ),
          SizedBox(height: ScallingConfig.scale(10)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CustomText(
                text: "NO. 1",
                fontSize: 12,
                color: AppColors.darkGreyColor,
              ),
              CustomText(
                text: "Complete Blood Count",
                isBold: true,
                color: AppColors.darkGreyColor,
              ),
            ],
          ),
          SizedBox(height: ScallingConfig.scale(10)),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CustomText(
                text: "NO. 2",
                fontSize: 12,
                color: AppColors.darkGreyColor,
              ),
              CustomText(
                text: "Blood Sugar",
                isBold: true,
                color: AppColors.darkGreyColor,
              ),
            ],
          ),
          SizedBox(height: ScallingConfig.scale(10)),
        ],
      ),
    );
  }
}

class _WebPatientProfileView extends StatefulWidget {
  final String selectedRole;
  final AppointmentDetail appointment;

  const _WebPatientProfileView({
    required this.selectedRole,
    required this.appointment,
  });

  @override
  State<_WebPatientProfileView> createState() => _WebPatientProfileViewState();
}

class _WebPatientProfileViewState extends State<_WebPatientProfileView> {
  Map<String, dynamic>? _doctorProfile;

  @override
  void initState() {
    super.initState();
    // Fetch doctor profile for all patient-view appointments (for picture + credentials)
    if (widget.selectedRole == 'Patient' &&
        widget.appointment.doctor?.id.isNotEmpty == true) {
      _fetchDoctorProfile();
    }
  }

  Future<void> _fetchDoctorProfile() async {
    try {
      final apiService = AppointmentService();
      final result = await apiService.getDoctorProfile(widget.appointment.doctor!.id);
      if (mounted && result != null) {
        setState(() => _doctorProfile = result);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final selectedRole = widget.selectedRole;
    final appointment = widget.appointment;
    final otherPerson = selectedRole == 'Doctor'
        ? appointment.patient
        : appointment.doctor;
    final profileName = otherPerson?.name ?? 'User';
    final formattedDate = DateFormat('MMMM dd, yyyy').format(appointment.date);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: const Text(
          "Appointment Details",
          style: TextStyle(
            fontSize: 18,
            fontFamily: "Gilroy-Bold",
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column - Patient Info Card
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(32),
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
                        // Doctor/Patient Avatar
                        Builder(builder: (_) {
                          final picUrl = selectedRole == 'Patient'
                              ? (_doctorProfile?['profilePicture']?.toString() ?? appointment.doctor?.profilePicture ?? '')
                              : (appointment.patient?.profilePicture ?? '');
                          return Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primaryColor, width: 3),
                              color: AppColors.primaryColor.withValues(alpha: 0.1),
                            ),
                            child: ClipOval(
                              child: picUrl.isNotEmpty
                                  ? Image.network(picUrl, fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Center(
                                        child: Text(profileName.isNotEmpty ? profileName[0].toUpperCase() : 'U',
                                          style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: AppColors.primaryColor)),
                                      ))
                                  : Center(
                                      child: Text(profileName.isNotEmpty ? profileName[0].toUpperCase() : 'U',
                                        style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: AppColors.primaryColor)),
                                    ),
                            ),
                          );
                        }),
                        const SizedBox(height: 24),
                        Text(
                          profileName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            fontFamily: "Gilroy-Bold",
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Doctor contact details (email/phone) never shown to patient
                        // Patient contact details shown only to doctor
                        if (selectedRole == 'Doctor') ...[
                          _buildInfoRow(Icons.email_outlined, otherPerson?.email ?? 'N/A'),
                          const SizedBox(height: 8),
                          _buildInfoRow(Icons.phone_outlined, otherPerson?.phoneNumber ?? 'N/A'),
                          const SizedBox(height: 8),
                        ],
                        _buildInfoRow(
                          Icons.qr_code_rounded,
                          "Booking ID: #${appointment.id.substring(appointment.id.length - 8)}",
                        ),
                        const SizedBox(height: 32),
                        // View Full Details — only for Doctor role (patient object exists)
                        if (selectedRole == 'Doctor' && appointment.patient != null)
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (ctx) => PatientProfileView(
                                    patient: appointment.patient!,
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                              "View Full Details →",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                // Right Column - Details
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      // Scheduled Appointment
                      _buildWebDetailsCard(
                        "Scheduled Appointment",
                        Icons.calendar_today_rounded,
                        appointment.status.toLowerCase() == 'confirmed'
                            ? const Color(0xFF10B981)
                            : appointment.status.toLowerCase() == 'completed'
                                ? const Color(0xFF3B82F6)
                                : appointment.status.toLowerCase() == 'cancelled'
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF6366F1),
                        {
                          "Date": formattedDate,
                          "Time": appointment.timeSlot,
                          "Status": appointment.status.toUpperCase(),
                          "Type": (appointment.channelName?.isNotEmpty == true ||
                                  appointment.consultationType?.toLowerCase().contains('video') == true ||
                                  appointment.consultationType?.toLowerCase().contains('online') == true)
                              ? "Video / Online"
                              : "In-Person",
                        },
                      ),
                      const SizedBox(height: 24),
                      // Patient/Doctor Info
                      _buildWebDetailsCard(
                        selectedRole == 'Doctor'
                            ? "Patient Info"
                            : "Doctor Info",
                        Icons.person_outline_rounded,
                        const Color(0xFF3B82F6),
                        selectedRole == 'Patient'
                            ? {
                                "Name": otherPerson?.name ?? 'N/A',
                                if (_doctorProfile != null) ...{
                                  if (_doctorProfile!['specialization'] != null &&
                                      _doctorProfile!['specialization'].toString().isNotEmpty)
                                    "Specialization": _doctorProfile!['specialization'].toString(),
                                  if (_doctorProfile!['licenseNumber'] != null &&
                                      _doctorProfile!['licenseNumber'].toString().isNotEmpty)
                                    "PMDC No.": _doctorProfile!['licenseNumber'].toString(),
                                  if (_doctorProfile!['experience'] != null &&
                                      _doctorProfile!['experience'].toString().isNotEmpty)
                                    "Experience": "${_doctorProfile!['experience']} yrs",
                                  if (_doctorProfile!['rating'] != null)
                                    "Rating": "${_doctorProfile!['rating']} ★ (${_doctorProfile!['totalReviews'] ?? 0} reviews)",
                                },
                                if (appointment.reason != null &&
                                    appointment.reason!.isNotEmpty &&
                                    !appointment.reason!.contains('Channel:'))
                                  "Reason": appointment.reason!,
                              }
                            : {
                                // Only name shown to doctor — no contact details
                                "Name": otherPerson?.name ?? 'N/A',
                                if (appointment.reason != null &&
                                    appointment.reason!.isNotEmpty &&
                                    !appointment.reason!.contains('Channel:'))
                                  "Reason": appointment.reason!,
                              },
                      ),
                      // Patient viewing completed appointment → show prescription button
                      if (selectedRole == 'Patient' &&
                          appointment.status.toLowerCase() == 'completed') ...[
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => const Center(child: CircularProgressIndicator()),
                              );
                              try {
                                final svc = ConsultationService();
                                final res = await svc.getConsultationByAppointmentId(appointment.id);
                                if (!context.mounted) return;
                                Navigator.pop(context);
                                if (res['success'] == true && res['consultation'] != null) {
                                  final consultation = res['consultation'] as Map;
                                  // Try prescriptionId — string or populated object
                                  dynamic rawPrescId = consultation['prescriptionId'];
                                  String prescriptionId = '';

                                  if (rawPrescId is Map) {
                                    prescriptionId = rawPrescId['_id']?.toString() ?? '';
                                  } else if (rawPrescId is String) {
                                    prescriptionId = rawPrescId;
                                  }

                                  // Fallback: check 'prescription' field (nested object)
                                  if (prescriptionId.isEmpty && consultation['prescription'] is Map) {
                                    final prescMap = consultation['prescription'] as Map;
                                    prescriptionId = prescMap['_id']?.toString() ?? prescMap['id']?.toString() ?? '';
                                  }

                                  if (prescriptionId.isNotEmpty) {
                                    final prescription = await svc.getPrescription(prescriptionId);
                                    if (!context.mounted) return;
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
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('No prescription found for this appointment'),
                                      backgroundColor: Colors.orange,
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
                            icon: const Icon(Icons.description_outlined, size: 20),
                            label: const Text("View Prescription"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showReviewDialog(context, appointment),
                            icon: const Icon(Icons.star_rounded, size: 20, color: Color(0xFFF59E0B)),
                            label: const Text('Rate & Review Doctor', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFF59E0B))),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              side: const BorderSide(color: Color(0xFFF59E0B)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                      if (selectedRole == "lab_technician") ...[
                        const SizedBox(height: 24),
                        _buildWebDetailsCard(
                          "Test Names",
                          Icons.biotech_rounded,
                          const Color(0xFF8B5CF6),
                          {
                            "NO. 1": "Complete Blood Count",
                            "NO. 2": "Blood Sugar",
                          },
                        ),
                      ],
                      if (selectedRole == "Doctor") ...[
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (ctx) => IntakeNotesScreen(
                                    appointment: appointment,
                                    isReadOnly: widget.selectedRole == "Doctor",
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.description_outlined,
                              size: 20,
                            ),
                            label: const Text("Intake Notes"),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 20,
                              ),
                              side: const BorderSide(
                                color: AppColors.primaryColor,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (selectedRole == "Doctor") ...[
                        const SizedBox(height: 24),
                        if (appointment.status.toLowerCase() == 'confirmed' ||
                            appointment.status.toLowerCase() == 'in_progress') ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final me = await SharedPref().getUserData();
                                if (!context.mounted) return;
                                // Update status to in_progress so patient sees Rejoin button
                                try {
                                  await AppointmentService().updateAppointmentStatus(
                                    appointmentId: appointment.id ?? '',
                                    status: 'in_progress',
                                  );
                                } catch (_) {}
                                if (!context.mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => VideoCall(
                                      channelName: appointment.id ?? 'consultation',
                                      remoteUserName: otherPerson?.name ?? 'Patient',
                                      isAudioOnly: false,
                                      appointmentId: appointment.id,
                                      patientId: otherPerson?.id,
                                      currentUserName: me?.name ?? 'Doctor',
                                      currentUserId: me?.id ?? '',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.play_circle_outline_rounded, size: 22),
                              label: const Text("Start Consultation"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (appointment.status.toLowerCase() == 'pending' && appointment.status.toLowerCase() != 'completed' && appointment.status.toLowerCase() != 'cancelled') ...[
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final result = await AppointmentService()
                                        .updateAppointmentStatus(
                                          appointmentId: appointment.id,
                                          status: 'confirmed',
                                        );
                                    if (result['success'] && context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Appointment accepted'),
                                        ),
                                      );
                                      Navigator.of(context).pop(true);
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 22,
                                  ),
                                  label: const Text("Accept Appointment"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                    textStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (ctx) =>
                                            DeclineAppointmentScreen(
                                              appointment: appointment,
                                            ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.cancel_outlined,
                                    size: 22,
                                  ),
                                  label: const Text("Decline"),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFEF4444),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                    ),
                                    side: const BorderSide(
                                      color: Color(0xFFEF4444),
                                      width: 2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
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

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildWebDetailsCard(
    String title,
    IconData icon,
    Color color,
    Map<String, String> data,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  fontFamily: "Gilroy-Bold",
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...data.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    entry.value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsultationCard(
    String title,
    String description,
    String duration,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.access_time_rounded, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                duration,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
