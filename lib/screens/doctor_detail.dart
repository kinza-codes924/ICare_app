import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icare/models/doctor.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/screens/book_appointment.dart';
import 'package:icare/screens/login.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';

class DoctorDetailScreen extends ConsumerWidget {
  const DoctorDetailScreen({super.key, required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isDesktop = Utils.windowWidth(context) > 600;
    final averageRating = doctor.averageRating;
    final selectedRole = ref.watch(authProvider).userRole;

    // Mobile view with standard AppBar
    if (!isDesktop) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          leading: CustomBackButton(),
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: CustomText(
            text: "Doctor Details",
            fontFamily: "Gilroy-Bold",
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0F172A),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.favorite_border_rounded,
                color: Color(0xFFEF4444),
              ),
              onPressed: () {},
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Doctor Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
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
                  // Avatar
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                    backgroundImage: (doctor.user.profilePicture != null && doctor.user.profilePicture!.isNotEmpty)
                        ? NetworkImage(doctor.user.profilePicture!)
                        : null,
                    child: (doctor.user.profilePicture == null || doctor.user.profilePicture!.isEmpty)
                        ? Text(
                            doctor.user.name.isNotEmpty ? doctor.user.name.substring(0, 1).toUpperCase() : 'D',
                            style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.primaryColor),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  // Name
                  Text(
                    doctor.user.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  // Specialization
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      doctor.specialization ?? 'General Practitioner',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Stats Row
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.work_history_rounded,
                    label: 'Experience',
                    value: (doctor.experience != null && doctor.experience!.isNotEmpty && doctor.experience != '0')
                        ? doctor.experience!
                        : 'Not set',
                    color: const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.star_rounded,
                    label: 'Rating',
                    value: averageRating > 0
                        ? averageRating.toStringAsFixed(1)
                        : 'New',
                    color: const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.people_rounded,
                    label: 'Reviews',
                    value: '${doctor.reviewCount}',
                    color: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.payments_rounded,
                    label: 'Fee',
                    value: (doctor.consultationFee != null && doctor.consultationFee! > 0)
                        ? 'PKR ${doctor.consultationFee!.toInt()}'
                        : 'Free',
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Contact Information (Doctor-only view)
            if (selectedRole == 'Doctor') ...[
              _buildInfoCard(
                title: 'Contact Information',
                icon: Icons.contact_phone_rounded,
                iconColor: const Color(0xFF3B82F6),
                children: [
                  _buildInfoItem(
                    icon: Icons.email_rounded,
                    label: 'Email',
                    value: doctor.user.email,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoItem(
                    icon: Icons.phone_rounded,
                    label: 'Phone',
                    value: doctor.user.phoneNumber,
                  ),
                ],
              ),
            ],

            // Qualifications
            if (doctor.degrees.isNotEmpty ||
                (doctor.licenseNumber != null &&
                    doctor.licenseNumber!.isNotEmpty)) ...[
              const SizedBox(height: 16),
              _buildInfoCard(
                title: 'Qualifications',
                icon: Icons.school_rounded,
                iconColor: const Color(0xFF8B5CF6),
                children: [
                  if (doctor.degrees.isNotEmpty) ...[
                    _buildInfoItem(
                      icon: Icons.workspace_premium_rounded,
                      label: 'Degrees',
                      value: doctor.degrees.join(', '),
                    ),
                    if (doctor.licenseNumber != null &&
                        doctor.licenseNumber!.isNotEmpty)
                      const SizedBox(height: 12),
                  ],
                  if (doctor.licenseNumber != null &&
                      doctor.licenseNumber!.isNotEmpty)
                    _buildInfoItem(
                      icon: Icons.badge_rounded,
                      label: 'License',
                      value: doctor.licenseNumber!,
                    ),
                ],
              ),
            ],

            // Clinic Information
            if (doctor.clinicName != null && doctor.clinicName!.isNotEmpty ||
                doctor.clinicAddress != null &&
                    doctor.clinicAddress!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildInfoCard(
                title: 'Clinic Information',
                icon: Icons.local_hospital_rounded,
                iconColor: const Color(0xFFEF4444),
                children: [
                  if (doctor.clinicName != null &&
                      doctor.clinicName!.isNotEmpty) ...[
                    _buildInfoItem(
                      icon: Icons.business_rounded,
                      label: 'Clinic Name',
                      value: doctor.clinicName!,
                    ),
                    if (doctor.clinicAddress != null &&
                        doctor.clinicAddress!.isNotEmpty)
                      const SizedBox(height: 12),
                  ],
                  if (doctor.clinicAddress != null &&
                      doctor.clinicAddress!.isNotEmpty)
                    _buildInfoItem(
                      icon: Icons.location_on_rounded,
                      label: 'Address',
                      value: doctor.clinicAddress!,
                    ),
                ],
              ),
            ],

            // Availability
            if (doctor.availableDays.isNotEmpty ||
                doctor.availableTime != null) ...[
              const SizedBox(height: 16),
              _buildInfoCard(
                title: 'Availability',
                icon: Icons.calendar_month_rounded,
                iconColor: const Color(0xFF06B6D4),
                children: [
                  if (doctor.availableDays.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.event_available_rounded,
                          size: 20,
                          color: const Color(0xFF06B6D4),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: doctor.availableDays.map((day) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF06B6D4,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF06B6D4,
                                    ).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  day,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF06B6D4),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                    if (doctor.availableTime != null)
                      const SizedBox(height: 12),
                  ],
                  if (doctor.availableTime != null)
                    _buildInfoItem(
                      icon: Icons.access_time_rounded,
                      label: 'Working Hours',
                      value:
                          '${doctor.availableTime!.start} - ${doctor.availableTime!.end}',
                    ),
                ],
              ),
            ],

            const SizedBox(height: 100),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Book Appointment Button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final isLoggedIn = ref.read(authProvider).isLoggedIn;
                      if (!isLoggedIn) {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Row(
                              children: [
                                Icon(Icons.lock_rounded, color: Color(0xFF0036BC)),
                                SizedBox(width: 10),
                                Text('Login Required', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                              ],
                            ),
                            content: const Text(
                              'You need to be logged in to book an appointment. Please sign in to continue.',
                              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => LoginScreen()),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0036BC),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Sign In', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) =>
                              BookAppointmentScreen(doctor: doctor),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.calendar_today_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Book Appointment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Desktop view with gradient header
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Stunning App Bar with Gradient
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            automaticallyImplyLeading: false,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.primaryColor),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.favorite_border_rounded,
                      color: Color(0xFFEF4444),
                    ),
                    onPressed: () {},
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Gradient Background
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primaryColor,
                          AppColors.primaryColor.withValues(alpha: 0.8),
                          const Color(0xFF6366F1),
                        ],
                      ),
                    ),
                  ),
                  // Decorative Circles
                  Positioned(
                    top: -50,
                    right: -50,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -30,
                    left: -30,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  // Doctor Info
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(isDesktop ? 32 : 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Avatar with glow effect
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: isDesktop ? 70 : 60,
                              backgroundColor: Colors.white,
                              child: CircleAvatar(
                                radius: isDesktop ? 65 : 55,
                                backgroundColor: const Color(0xFFF0F9FF),
                                backgroundImage: (doctor.user.profilePicture != null && doctor.user.profilePicture!.isNotEmpty)
                                    ? NetworkImage(doctor.user.profilePicture!)
                                    : null,
                                child: (doctor.user.profilePicture == null || doctor.user.profilePicture!.isEmpty)
                                    ? Text(
                                        doctor.user.name.isNotEmpty ? doctor.user.name.substring(0, 1).toUpperCase() : 'D',
                                        style: TextStyle(fontSize: isDesktop ? 56 : 48, fontWeight: FontWeight.w900, color: AppColors.primaryColor),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Name
                          Text(
                            doctor.user.name,
                            style: TextStyle(
                              fontSize: isDesktop ? 32 : 26,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          // Specialization Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              doctor.specialization ?? 'General Practitioner',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFFF8FAFC),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Stats Cards
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 24 : 16,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildGlassStatCard(
                            icon: Icons.work_history_rounded,
                            label: 'Experience',
                            value: (doctor.experience != null && doctor.experience!.isNotEmpty && doctor.experience != '0')
                                ? doctor.experience!
                                : 'Not set',
                            color: const Color(0xFF3B82F6),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildGlassStatCard(
                            icon: Icons.star_rounded,
                            label: 'Rating',
                            value: averageRating > 0
                                ? averageRating.toStringAsFixed(1)
                                : 'New',
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildGlassStatCard(
                            icon: Icons.people_rounded,
                            label: 'Reviews',
                            value: '${doctor.reviewCount}',
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Contact Information Card (Doctor-only view)
                  if (selectedRole == 'Doctor') ...[
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 24 : 16,
                      ),
                      child: _buildModernCard(
                        title: 'Contact Information',
                        icon: Icons.contact_phone_rounded,
                        iconColor: const Color(0xFF3B82F6),
                        child: Column(
                          children: [
                            _buildContactItem(
                              icon: Icons.email_rounded,
                              label: 'Email Address',
                              value: doctor.user.email,
                              color: const Color(0xFF3B82F6),
                            ),
                            const SizedBox(height: 16),
                            _buildContactItem(
                              icon: Icons.phone_rounded,
                              label: 'Phone Number',
                              value: doctor.user.phoneNumber,
                              color: const Color(0xFF10B981),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Qualifications Card
                  if (doctor.degrees.isNotEmpty ||
                      (doctor.licenseNumber != null &&
                          doctor.licenseNumber!.isNotEmpty)) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 24 : 16,
                      ),
                      child: _buildModernCard(
                        title: 'Qualifications',
                        icon: Icons.school_rounded,
                        iconColor: const Color(0xFF8B5CF6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (doctor.degrees.isNotEmpty) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF8B5CF6,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.workspace_premium_rounded,
                                      size: 20,
                                      color: Color(0xFF8B5CF6),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Degrees',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: doctor.degrees.map((
                                            degree,
                                          ) {
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    const Color(
                                                      0xFF8B5CF6,
                                                    ).withValues(alpha: 0.1),
                                                    const Color(
                                                      0xFF8B5CF6,
                                                    ).withValues(alpha: 0.05),
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFF8B5CF6,
                                                  ).withValues(alpha: 0.2),
                                                ),
                                              ),
                                              child: Text(
                                                degree,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF8B5CF6),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (doctor.degrees.isNotEmpty &&
                                doctor.licenseNumber != null &&
                                doctor.licenseNumber!.isNotEmpty)
                              const SizedBox(height: 16),
                            if (doctor.licenseNumber != null &&
                                doctor.licenseNumber!.isNotEmpty)
                              _buildContactItem(
                                icon: Icons.badge_rounded,
                                label: 'License Number',
                                value: doctor.licenseNumber!,
                                color: const Color(0xFF8B5CF6),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Clinic Information Card
                  if (doctor.clinicName != null &&
                          doctor.clinicName!.isNotEmpty ||
                      doctor.clinicAddress != null &&
                          doctor.clinicAddress!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 24 : 16,
                      ),
                      child: _buildModernCard(
                        title: 'Clinic Information',
                        icon: Icons.local_hospital_rounded,
                        iconColor: const Color(0xFFEF4444),
                        child: Column(
                          children: [
                            if (doctor.clinicName != null &&
                                doctor.clinicName!.isNotEmpty) ...[
                              _buildContactItem(
                                icon: Icons.business_rounded,
                                label: 'Clinic Name',
                                value: doctor.clinicName!,
                                color: const Color(0xFFEF4444),
                              ),
                              if (doctor.clinicAddress != null &&
                                  doctor.clinicAddress!.isNotEmpty)
                                const SizedBox(height: 16),
                            ],
                            if (doctor.clinicAddress != null &&
                                doctor.clinicAddress!.isNotEmpty)
                              _buildContactItem(
                                icon: Icons.location_on_rounded,
                                label: 'Address',
                                value: doctor.clinicAddress!,
                                color: const Color(0xFFEF4444),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Availability Card
                  if (doctor.availableDays.isNotEmpty ||
                      doctor.availableTime != null) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 24 : 16,
                      ),
                      child: _buildModernCard(
                        title: 'Availability',
                        icon: Icons.calendar_month_rounded,
                        iconColor: const Color(0xFF06B6D4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (doctor.availableDays.isNotEmpty) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF06B6D4,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.event_available_rounded,
                                      size: 20,
                                      color: Color(0xFF06B6D4),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Available Days',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: doctor.availableDays.map((
                                            day,
                                          ) {
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    const Color(0xFF06B6D4),
                                                    const Color(
                                                      0xFF06B6D4,
                                                    ).withValues(alpha: 0.8),
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(
                                                      0xFF06B6D4,
                                                    ).withValues(alpha: 0.3),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Text(
                                                day,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (doctor.availableDays.isNotEmpty &&
                                doctor.availableTime != null)
                              const SizedBox(height: 16),
                            if (doctor.availableTime != null)
                              _buildContactItem(
                                icon: Icons.access_time_rounded,
                                label: 'Working Hours',
                                value:
                                    '${doctor.availableTime!.start} - ${doctor.availableTime!.end}',
                                color: const Color(0xFF06B6D4),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: EdgeInsets.all(isDesktop ? 24 : 16),
          child: Row(
            children: [
              // Book Appointment Button
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryColor,
                        AppColors.primaryColor.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryColor.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        final isLoggedIn = ref.read(authProvider).isLoggedIn;
                        if (!isLoggedIn) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Row(
                                children: [
                                  Icon(Icons.lock_rounded, color: Color(0xFF0036BC)),
                                  SizedBox(width: 10),
                                  Text('Login Required', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                ],
                              ),
                              content: const Text(
                                'You need to be logged in to book an appointment. Please sign in to continue.',
                                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => LoginScreen()),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0036BC),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Sign In', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                          return;
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) =>
                                BookAppointmentScreen(doctor: doctor),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Book Appointment',
                              style: TextStyle(
                                fontSize: isDesktop ? 18 : 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Mobile view helper methods
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Desktop view helper methods
  Widget _buildGlassStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildModernCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      iconColor.withValues(alpha: 0.2),
                      iconColor.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
