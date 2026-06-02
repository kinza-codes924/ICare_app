import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/models/doctor.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/screens/active_orders.dart';
import 'package:icare/screens/completed-reports.dart';
import 'package:icare/screens/filters.dart';
import 'package:icare/screens/lab_filters.dart';
import 'package:icare/screens/public_home.dart';
import 'package:icare/screens/patient_dashboard.dart';
import 'package:icare/screens/pharmacy_home.dart';
import 'package:icare/screens/profile_edit.dart';
import 'package:icare/screens/upcoming_appointments.dart';
import 'package:icare/screens/video_call.dart';
import 'package:icare/models/user.dart' as app_user;
import 'package:icare/services/doctor_service.dart';
import 'package:icare/services/user_service.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/appointment_card.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/widgets/custom_record_card.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/custom_text_input.dart';
import 'package:icare/widgets/instructor_home.dart';
import 'package:icare/widgets/laboratory.dart';
import 'package:icare/widgets/student_home.dart';
import 'package:icare/widgets/svg_wrapper.dart';
import 'package:easy_date_timeline/easy_date_timeline.dart';
import 'package:intl/intl.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTime? _selectedDate;
  final PageController _pageController = PageController();
  int _currentSlide = 0;
  final DoctorService _doctorService = DoctorService();
  final UserService _userService = UserService();
  List<Doctor> _topDoctors = [];
  bool _loadingDoctors = false;

  @override
  void initState() {
    super.initState();
    _loadTopDoctors();
    _refreshUserProfile();
  }

  Future<void> _refreshUserProfile() async {
    final token = ref.read(authProvider).token;
    if (token == null || token.isEmpty) return;

    final currentName = ref.read(authProvider).user?.name ?? '';
    // Skip refresh if we already have a real name stored
    final hasRealName = currentName.isNotEmpty &&
        currentName.toLowerCase() != 'user' &&
        currentName.length > 1;
    if (hasRealName) return;

    // Only refresh when name is missing/default
    final result = await _userService.getUserProfile(token: token);
    if (result['success'] == true && result['user'] != null && mounted) {
      try {
        final fetched = app_user.User.fromJson(result['user'] as Map<String, dynamic>);
        final fetchedName = fetched.name;
        // Only update if backend has a real name
        if (fetchedName.isNotEmpty && fetchedName.toLowerCase() != 'user') {
          await ref.read(authProvider.notifier).setUser(fetched);
        }
      } catch (_) {}
    }
  }

  Future<void> _loadTopDoctors() async {
    setState(() => _loadingDoctors = true);
    final result = await _doctorService.getAllDoctors();
    if (result['success']) {
      final doctors = (result['doctors'] as List)
          .map((json) => Doctor.fromJson(json))
          .toList();
      setState(() {
        _topDoctors = doctors.where((d) => d.isOnline).take(3).toList();
        _loadingDoctors = false;
      });
    } else {
      setState(() => _loadingDoctors = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final selectedRole = auth.userRole;
    final userName = auth.user?.name ?? 'User';
    final bool isDesktop = Utils.windowWidth(context) > 600;
    Widget content;

    // Default View (Patient/Default)
    content = Container(
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 1300 : double.infinity,
          ),
          child: Column(
            children: [
              if (isDesktop) ...[
                // Desktop: Premium Welcome Header
                Container(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 30,
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomText(
                              text: "Welcome back,".tr(),
                              fontSize: 15,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                            const SizedBox(height: 4),
                            CustomText(
                              text: userName,
                              fontSize: 32,
                              color: const Color(0xFF0F172A),
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          width: 450,
                          margin: const EdgeInsets.only(top: 10),
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                                blurRadius: 25,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: CustomInputField(
                            width: 450,
                            height: 52,
                            margin: EdgeInsets.zero,
                            hintText: "Search for doctors, labs, courses...".tr(),
                            trailingIcon: SvgWrapper(
                              assetPath: ImagePaths.filters,
                              onPress: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (ctx) => FiltersScreen(),
                                ),
                              ),
                            ),
                            leadingIcon: const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF94A3B8),
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // Mobile: Original search bar
                CustomInputField(
                  width: Utils.windowWidth(context) * 0.9,
                  hintText: "Search".tr(),
                  trailingIcon: SvgWrapper(
                    assetPath: ImagePaths.filters,
                    onPress: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (ctx) => FiltersScreen()),
                      );
                    },
                  ),
                  leadingIcon: SvgWrapper(assetPath: ImagePaths.search),
                ),
              ],

              // Slider Section
              if (isDesktop) ...[
                // Desktop: Premium Hero Slider
                Container(
                  color: Colors.white,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      SizedBox(
                        width: Utils.windowWidth(context),
                        height: 380,
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) =>
                              setState(() => _currentSlide = index),
                          itemCount: 3,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 30,
                                vertical: 10,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF0F172A),
                                      Color(0xFF1E293B),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF0F172A,
                                      ).withValues(alpha: 0.15),
                                      blurRadius: 30,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(28),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Opacity(
                                        opacity: 0.35,
                                        child: Image.asset(
                                          ImagePaths.newBanner,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              const Color(
                                                0xFF0F172A,
                                              ).withValues(alpha: 0.6),
                                              Colors.transparent,
                                            ],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ),
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: Image.asset(
                                          ImagePaths.newBanner,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        bottom: 28,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            3,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeOutQuint,
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              height: 6,
                              width: _currentSlide == index ? 28 : 6,
                              decoration: BoxDecoration(
                                color: _currentSlide == index
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Mobile: Responsive full-width banner with PageView
                SizedBox(
                  width: Utils.windowWidth(context),
                  height: Utils.windowWidth(context) * 0.55,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) =>
                        setState(() => _currentSlide = index),
                    itemCount: 2,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            ImagePaths.newBanner,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Dot indicators
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    2,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 6,
                      width: _currentSlide == index ? 20 : 6,
                      decoration: BoxDecoration(
                        color: _currentSlide == index
                            ? AppColors.primaryColor
                            : AppColors.primaryColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Appointments Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    CustomText(
                      text: "Today’s Appointments".tr(),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary500,
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.themeRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: CustomText(
                        text: "20 min left".tr(),
                        fontSize: 12,
                        color: AppColors.themeRed,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const DoctorConsultationCard(),

              // Calendar and other elements
              const SizedBox(height: 10),
              EasyDateTimeLinePicker.itemBuilder(
                focusedDate: _selectedDate,
                firstDate: DateTime(2024, 3, 18),
                lastDate: DateTime(2030, 3, 18),
                itemExtent: isDesktop ? 80 : ScallingConfig.scale(70),
                itemBuilder:
                    (context, date, isSelected, isDisabled, isToday, onTap) {
                      return InkWell(
                        onTap: onTap,
                        child: Container(
                          width: isDesktop ? 70 : ScallingConfig.scale(60),
                          height: isDesktop ? 100 : ScallingConfig.scale(120),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.secondaryColor
                                : AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FittedBox(
                                child: CustomText(
                                  fontSize: 20,
                                  fontFamily: "Gilroy-SemiBold",
                                  text: date.day.toString(),
                                  color: isSelected
                                      ? AppColors.white
                                      : AppColors.darkGray400,
                                ),
                              ),
                              const SizedBox(height: 2),
                              CustomText(
                                fontSize: 12,
                                fontFamily: "Gilroy-SemiBold",
                                text: DateFormat('EEE').format(date).toString(),
                                color: isSelected
                                    ? AppColors.white
                                    : AppColors.darkGray400,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                onDateChange: (date) {
                  setState(() {
                    _selectedDate = date;
                  });
                },
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: isDesktop
                      ? double.infinity
                      : Utils.windowWidth(context) * 0.9,
                  child: const AppointmentCard(),
                ),
              ),
              const SizedBox(height: 28),
              // Stunning "View All" Button
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => const UpcomingAppointments(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryColor.withValues(alpha: 0.06),
                          AppColors.secondaryColor.withValues(alpha: 0.06),
                        ],
                      ),
                      border: Border.all(
                        color: AppColors.primaryColor.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomText(
                          text: "View All Upcoming Appointments".tr(),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryColor,
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: AppColors.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );

    if (selectedRole == "Laboratory") {
      if (isDesktop) {
        // ═══════════════════════════════════════════════════════════════
        // WEB LAYOUT FOR LAB TECHNICIAN
        // ═══════════════════════════════════════════════════════════════
        content = Container(
          decoration: const BoxDecoration(color: Color(0xFFF0F4F8)),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 36,
                  vertical: 28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ═══════════════════════════════════════════════════════
                    // WELCOME HEADER
                    // ═══════════════════════════════════════════════════════
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomText(
                              text:
                                  "${'Good'.tr()} ${TimeOfDay.now().hour < 12
                                      ? 'Morning'.tr()
                                      : TimeOfDay.now().hour < 17
                                      ? 'Afternoon'.tr()
                                      : 'Evening'.tr()},",
                              fontSize: 14,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                            const SizedBox(height: 4),
                            CustomText(
                              text: userName,
                              fontSize: 30,
                              color: const Color(0xFF0F172A),
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Date badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 16,
                                color: Color(0xFF3B82F6),
                              ),
                              const SizedBox(width: 8),
                              CustomText(
                                text: DateFormat(
                                  'EEEE, MMM d, yyyy',
                                ).format(DateTime.now()),
                                fontSize: 13,
                                color: const Color(0xFF475569),
                                fontWeight: FontWeight.w600,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          width: 380,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF0F172A,
                                ).withValues(alpha: 0.03),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: CustomInputField(
                            width: 380,
                            height: 48,
                            margin: EdgeInsets.zero,
                            hintText: "Search tests, patients...".tr(),
                            trailingIcon: SvgWrapper(
                              assetPath: ImagePaths.filters,
                              onPress: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (ctx) => const LabFilters(),
                                ),
                              ),
                            ),
                            leadingIcon: const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF94A3B8),
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ═══════════════════════════════════════════════════════
                    // STATISTICS CARDS ROW
                    // ═══════════════════════════════════════════════════════
                    Row(
                      children: [
                        Expanded(
                          child: _buildPremiumStatCard(
                            context: context,
                            label: "Active Orders".tr(),
                            number: "120",
                            subtitle: "+12 from yesterday".tr(),
                            icon: Icons.science_rounded,
                            gradientColors: [
                              const Color(0xFF3B82F6),
                              const Color(0xFF1D4ED8),
                            ],
                            bgAccent: const Color(0xFFDBEAFE),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) => const ActiveOrdersScreen(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _buildPremiumStatCard(
                            context: context,
                            label: "Completed".tr(),
                            number: "32",
                            subtitle: "This month".tr(),
                            icon: Icons.check_circle_rounded,
                            gradientColors: [
                              const Color(0xFF10B981),
                              const Color(0xFF059669),
                            ],
                            bgAccent: const Color(0xFFD1FAE5),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) =>
                                    const CompletedReportsScreen(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _buildPremiumStatCard(
                            context: context,
                            label: "Pending Tests".tr(),
                            number: "15",
                            subtitle: "3 urgent".tr(),
                            icon: Icons.pending_actions_rounded,
                            gradientColors: [
                              const Color(0xFFF59E0B),
                              const Color(0xFFD97706),
                            ],
                            bgAccent: const Color(0xFFFEF3C7),
                            onTap: () {},
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _buildPremiumStatCard(
                            context: context,
                            label: "Revenue".tr(),
                            number: "PKR 4.2K",
                            subtitle: "+8% this week".tr(),
                            icon: Icons.trending_up_rounded,
                            gradientColors: [
                              const Color(0xFF8B5CF6),
                              const Color(0xFF7C3AED),
                            ],
                            bgAccent: const Color(0xFFEDE9FE),
                            onTap: () {},
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ═══════════════════════════════════════════════════════
                    // MAIN CONTENT — TWO COLUMNS
                    // ═══════════════════════════════════════════════════════
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LEFT COLUMN (wider)
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ─── Laboratories Section ─────────────────
                              _buildSectionHeader(
                                "Laboratories".tr(),
                                "Browse All".tr(),
                                () {},
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Laboratory(margin: EdgeInsets.zero),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    child: Laboratory(margin: EdgeInsets.zero),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 32),

                              // ─── New Test Requests ───────────────────
                              _buildSectionHeader(
                                "New Test Requests".tr(),
                                "View All".tr(),
                                () {},
                              ),
                              const SizedBox(height: 16),
                              // Premium Table-style requests
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 20,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // Table header
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(20),
                                            ),
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.grey.shade200,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              "Patient".tr(),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                                color: Color(0xFF64748B),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              "Test".tr(),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                                color: Color(0xFF64748B),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              "Date & Time".tr(),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                                color: Color(0xFF64748B),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              "Status".tr(),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                                color: Color(0xFF64748B),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 80),
                                        ],
                                      ),
                                    ),
                                    // Table rows
                                    ..._buildTestRequestRows(context),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 24),

                        // RIGHT COLUMN (narrower — activity & quick actions)
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              // ─── Quick Actions Card ───────────────────
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF0B2D6E),
                                      Color(0xFF1565C0),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF0B2D6E,
                                      ).withValues(alpha: 0.25),
                                      blurRadius: 24,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Quick Actions".tr(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "Frequently used shortcuts".tr(),
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    _buildQuickActionBtn(
                                      icon: Icons.add_circle_rounded,
                                      label: "New Lab Report".tr(),
                                      color: const Color(0xFF6366F1),
                                      onTap: () {},
                                    ),
                                    const SizedBox(height: 10),
                                    _buildQuickActionBtn(
                                      icon: Icons.person_add_rounded,
                                      label: "Register Patient".tr(),
                                      color: const Color(0xFF10B981),
                                      onTap: () {},
                                    ),
                                    const SizedBox(height: 10),
                                    _buildQuickActionBtn(
                                      icon: Icons.upload_file_rounded,
                                      label: "Upload Results".tr(),
                                      color: const Color(0xFF0EA5E9),
                                      onTap: () {},
                                    ),
                                    const SizedBox(height: 10),
                                    _buildQuickActionBtn(
                                      icon: Icons.video_call_rounded,
                                      label: "Start Video Call".tr(),
                                      color: const Color(0xFFF59E0B),
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (ctx) => const VideoCall(
                                            channelName: 'call_quick',
                                            remoteUserName: 'Doctor',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              // ─── Recent Activity Timeline ─────────────
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 20,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Recent Activity".tr(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 18,
                                            color: Color(0xFF0F172A),
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            "Today".tr(),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF3B82F6),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    _buildActivityItem(
                                      icon: Icons.check_circle_rounded,
                                      color: const Color(0xFF10B981),
                                      title: "CBC Report completed".tr(),
                                      sub: "Patient: Alyana · 15 min ago".tr(),
                                    ),
                                    _buildActivityItem(
                                      icon: Icons.science_rounded,
                                      color: const Color(0xFF3B82F6),
                                      title: "New blood test sample".tr(),
                                      sub: "Patient: Hamza · 42 min ago".tr(),
                                    ),
                                    _buildActivityItem(
                                      icon: Icons.notifications_rounded,
                                      color: const Color(0xFFF59E0B),
                                      title: "Urgent: X-Ray pending".tr(),
                                      sub: "Patient: Sara · 1 hr ago".tr(),
                                    ),
                                    _buildActivityItem(
                                      icon: Icons.upload_file_rounded,
                                      color: const Color(0xFF8B5CF6),
                                      title: "Report uploaded to portal".tr(),
                                      sub: "Patient: Ali · 2 hrs ago".tr(),
                                      isLast: true,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        );
      } else {
        // ═══════════════════════════════════════════════════════════════
        // MOBILE LAYOUT FOR LAB TECHNICIAN (ORIGINAL - UNTOUCHED)
        // ═══════════════════════════════════════════════════════════════
        content = Center(
          child: Column(
            children: [
              CustomInputField(
                width: Utils.windowWidth(context) * 0.9,
                hintText: "Search".tr(),
                trailingIcon: SvgWrapper(
                  assetPath: ImagePaths.filters,
                  onPress: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => const LabFilters()),
                    );
                  },
                ),
                leadingIcon: SvgWrapper(assetPath: ImagePaths.search),
              ),
              SizedBox(height: ScallingConfig.scale(20)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomRecordCard(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const ActiveOrdersScreen(),
                        ),
                      );
                    },
                    label: "Active Orders".tr(),
                    number: "120",
                    icon: SvgWrapper(assetPath: ImagePaths.lab_tech),
                  ),
                  SizedBox(width: ScallingConfig.scale(10)),
                  CustomRecordCard(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const CompletedReportsScreen(),
                        ),
                      );
                    },
                    color: AppColors.primaryColor,
                    label: "Completed Reports".tr(),
                    number: "32",
                    icon: SvgWrapper(assetPath: ImagePaths.lab_tech),
                  ),
                ],
              ),
              SizedBox(height: ScallingConfig.scale(20)),
              CustomText(
                width: Utils.windowWidth(context) * 0.85,
                text: "Laboratories".tr(),
                fontFamily: "Gilroy-Bold",
                fontSize: 16.78,
                color: AppColors.primary500,
                fontWeight: FontWeight.bold,
              ),
              SizedBox(height: ScallingConfig.scale(10)),
              const Laboratory(),
              SizedBox(height: ScallingConfig.scale(10)),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ScallingConfig.scale(25.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CustomText(
                      text: "New Test Requests".tr(),
                      fontFamily: "Gilroy-Bold",
                      fontSize: 16.78,
                      color: AppColors.primary500,
                      fontWeight: FontWeight.bold,
                    ),
                    CustomText(
                      text: "View All".tr(),
                      fontFamily: "Gilroy-SemiBold",
                      fontSize: 14.78,
                      underline: true,
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ],
                ),
              ),
              SizedBox(height: ScallingConfig.scale(20)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ScallingConfig.scale(10),
                  vertical: ScallingConfig.verticalScale(10),
                ),
                width: Utils.windowWidth(context) * 0.85,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      clipBehavior: Clip.hardEdge,
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset(
                        ImagePaths.user13,
                        fit: BoxFit.cover,
                        width: ScallingConfig.scale(80),
                        height: ScallingConfig.scale(80),
                      ),
                    ),
                    SizedBox(width: ScallingConfig.scale(20)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomText(
                          text: "Alyana",
                          fontFamily: "Gilroy-Bold",
                          fontSize: 14,
                          color: AppColors.themeDarkGrey,
                        ),
                        SizedBox(height: ScallingConfig.scale(10)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            TimeStampWidget(title: "Date".tr(), data: "01-AUG-2025"),
                            const SizedBox(width: 10),
                            TimeStampWidget(
                              title: "Time".tr(),
                              data: "07 PM - 08 PM",
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: Utils.windowHeight(context) * 0.1),
            ],
          ),
        );
      }
    } else if (selectedRole == "Patient") {
      if (isDesktop) {
        content = const _PatientPublicHomeContent();
      } else {
        content = const PatientDashboard();
      }
    } else if (selectedRole == "Instructor") {
      content = const InstructorHome();
    } else if (selectedRole == "Pharmacy") {
      content = const PharmacyHome();
    } else if (selectedRole == "Student") {
      content = const StudentHome();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 0),
      child: Container(
        color: Colors.white,
        child: content,
      ),
    );
  }

  // Helper function for web stat cards
  Widget _buildWebStatCard({
    required BuildContext context,
    required String label,
    required String number,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.grey[400],
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 20),
            CustomText(
              text: number,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
            const SizedBox(height: 4),
            CustomText(
              text: label,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Lab Technician Dashboard Helper Methods
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPremiumStatCard({
    required BuildContext context,
    required String label,
    required String number,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required Color bgAccent,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: gradientColors[0].withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: gradientColors[0].withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: bgAccent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: gradientColors[0],
                      size: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                number,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: bgAccent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: gradientColors[0],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    String actionText,
    VoidCallback onTap,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primaryColor.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionText,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: AppColors.primaryColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withValues(alpha: 0.4),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required Color color,
    required String title,
    required String sub,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 28,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTestRequestRows(BuildContext context) {
    final testData = [
      {
        "name": "Alyana",
        "test": "Complete Blood Count",
        "date": "01-AUG-2025",
        "time": "07 PM",
        "status": "Pending",
        "statusColor": "amber",
      },
      {
        "name": "Hamza Khan",
        "test": "Lipid Profile",
        "date": "01-AUG-2025",
        "time": "08 PM",
        "status": "In Progress",
        "statusColor": "blue",
      },
      {
        "name": "Sara Ahmed",
        "test": "X-Ray Chest",
        "date": "02-AUG-2025",
        "time": "10 AM",
        "status": "Urgent",
        "statusColor": "red",
      },
      {
        "name": "Ali Raza",
        "test": "Urine Analysis",
        "date": "02-AUG-2025",
        "time": "11 AM",
        "status": "Pending",
        "statusColor": "amber",
      },
    ];

    return testData.asMap().entries.map((entry) {
      final i = entry.key;
      final data = entry.value;
      final isLast = i == testData.length - 1;

      Color statusBg;
      Color statusFg;
      if (data["statusColor"] == "red") {
        statusBg = const Color(0xFFFEE2E2);
        statusFg = const Color(0xFFEF4444);
      } else if (data["statusColor"] == "blue") {
        statusBg = const Color(0xFFDBEAFE);
        statusFg = const Color(0xFF3B82F6);
      } else {
        statusBg = const Color(0xFFFEF3C7);
        statusFg = const Color(0xFFF59E0B);
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: Colors.grey.shade100)),
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(20))
              : null,
        ),
        child: Row(
          children: [
            // Patient
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primaryColor.withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: Image.asset(
                        ImagePaths.user13,
                        fit: BoxFit.cover,
                        width: 42,
                        height: 42,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    data["name"]!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            // Test
            Expanded(
              flex: 2,
              child: Text(
                data["test"]!,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Date & Time
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 13,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "${data['date']} · ${data['time']}",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Status
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  data["status"]!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusFg,
                  ),
                ),
              ),
            ),
            // Action
            const SizedBox(width: 12),
            SizedBox(
              width: 68,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        "View".tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class TimeStampWidget extends StatelessWidget {
  const TimeStampWidget({super.key, this.title = '', this.data = ""});
  final String title;
  final String data;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomText(text: title),
        CustomText(
          text: data,
          fontSize: 10,
          bgColor: AppColors.veryLightGrey,
          padding: EdgeInsets.symmetric(
            horizontal: ScallingConfig.scale(10),
            vertical: ScallingConfig.scale(5),
          ),
          color: AppColors.darkGreyColor,
          borderradius: 10,
        ),
      ],
    );
  }
}

class ProfileInfoWidget extends ConsumerWidget {
  const ProfileInfoWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: Utils.windowWidth(context),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(color: AppColors.white),
      child: Row(
        children: [
          Container(
            width: Utils.windowWidth(context) * 0.25,
            height: Utils.windowWidth(context) * 0.25,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
            child: Image.asset(ImagePaths.user1, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CustomText(
                      text: ref.watch(authProvider).user?.name ?? "User",
                      isSemiBold: true,
                    ),
                    const SizedBox(width: 50),
                    CustomText(
                      text: "View Profile".tr(),
                      underline: true,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => const ProfileEditScreen(),
                          ),
                        );
                      },
                      isSemiBold: true,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const SvgWrapper(assetPath: ImagePaths.location),
                    SizedBox(width: Utils.windowWidth(context) * 0.025),
                    CustomText(
                      text: "20 Cooper Square, USA".tr(),
                      fontSize: 12,
                      color: AppColors.darkGreyColor,
                    ),
                  ],
                ),
                Row(
                  children: [
                    const SvgWrapper(assetPath: ImagePaths.scan),
                    SizedBox(width: Utils.windowWidth(context) * 0.025),
                    const CustomText(
                      text: "Booking ID: #DR452SA54",
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

class DoctorConsultationCard extends StatelessWidget {
  const DoctorConsultationCard({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Utils.windowWidth(context) > 600;

    if (!isDesktop) {
      // ─── MOBILE ORIGINAL DESIGN ───
      return Container(
        width: Utils.windowWidth(context) * 0.85,
        padding: EdgeInsets.symmetric(
          horizontal: ScallingConfig.scale(10),
          vertical: ScallingConfig.verticalScale(12),
        ),
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.lightGrey100,
              offset: Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ScallingConfig.scale(8),
                  vertical: ScallingConfig.verticalScale(3),
                ),
                decoration: BoxDecoration(
                  color: AppColors.darkGreyColor.withAlpha(40),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: CustomText(
                  text: "Video Consultation".tr(),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            SizedBox(height: Utils.windowHeight(context) * 0.017),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ScallingConfig.scale(10),
              ),
              child: Consumer(
                builder: (context, ref, child) {
                  final userName = ref.watch(authProvider).user?.name ?? 'User';
                  return Row(
                    children: [
                      CircleAvatar(
                        radius: ScallingConfig.scale(30),
                        backgroundColor: AppColors.primaryColor.withValues(
                          alpha: 0.1,
                        ),
                        child: Text(
                          userName.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryColor,
                          ),
                        ),
                      ),
                      SizedBox(width: ScallingConfig.scale(20)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomText(
                            text: userName,
                            fontSize: 16.78,
                            fontWeight: FontWeight.w400,
                            isBold: true,
                          ),
                          CustomText(
                            text: "9:00 Am",
                            fontSize: 16.78,
                            fontWeight: FontWeight.w400,
                            isBold: true,
                          ),
                        ],
                      ),
                      Spacer(),
                      CustomButton(
                        width: Utils.windowWidth(context) * 0.2,
                        height: ScallingConfig.verticalScale(25),
                        borderRadius: 20,
                        label: "Join".tr(),
                        labelSize: 14,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => VideoCall(
                                channelName: 'call_join',
                                remoteUserName: 'Doctor',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    // ─── DESKTOP PREMIUM DESIGN ───
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 50,
            offset: const Offset(0, 25),
          ),
          BoxShadow(
            color: AppColors.primaryColor.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: Stack(
          children: [
            // Artistic background splash
            Positioned(
              right: -50,
              bottom: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.secondaryColor.withValues(alpha: 0.08),
                      AppColors.secondaryColor.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Live Indicator Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.themeGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.themeGreen.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.themeGreen,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.themeGreen,
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        CustomText(
                          text: "LIVE SESSION".tr(),
                          fontSize: 12,
                          color: AppColors.themeGreen,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Consumer(
                    builder: (context, ref, child) {
                      final auth = ref.watch(authProvider);
                      final userName = auth.user?.name ?? 'User';
                      return Row(
                        children: [
                          // Premium Avatar with ring
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.secondaryColor.withValues(
                                  alpha: 0.2,
                                ),
                                width: 3,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 45,
                              backgroundColor: AppColors.primaryColor
                                  .withValues(alpha: 0.1),
                              child: Text(
                                userName.substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primaryColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 28),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomText(
                                  text: userName,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -0.5,
                                ),
                                const SizedBox(height: 4),
                                CustomText(
                                  text: auth.user?.role ?? 'User',
                                  fontSize: 15,
                                  color: AppColors.darkGray400,
                                  fontWeight: FontWeight.w500,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.videocam_rounded,
                                      size: 20,
                                      color: AppColors.primaryColor.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    CustomText(
                                      text: "Starts in 20 min".tr(),
                                      fontSize: 15,
                                      color: AppColors.primaryColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Flagship Button
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: CustomButton(
                              width: isDesktop ? 220 : 130,
                              height: 64,
                              borderRadius: 20,
                              label: isDesktop ? "Join Session Now".tr() : "Join".tr(),
                              labelSize: 18,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF0036BC), Color(0xFF14B1FF)],
                              ),
                              boxShadow: BoxShadow(
                                color: AppColors.primaryColor.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                              trailingIcon: const Icon(
                                Icons.bolt_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (ctx) => const VideoCall(
                                      channelName: 'call_quick',
                                      remoteUserName: 'Doctor',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Patient logged-in home: same content as public home, no top navbar ────────
class _PatientPublicHomeContent extends StatelessWidget {
  const _PatientPublicHomeContent();

  @override
  Widget build(BuildContext context) => const PublicHomeBody();
}
