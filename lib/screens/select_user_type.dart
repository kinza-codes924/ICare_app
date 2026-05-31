import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/screens/login.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/user_type_card.dart';

class SelectUserType extends ConsumerStatefulWidget {
  const SelectUserType({super.key});

  @override
  ConsumerState<SelectUserType> createState() => _SelectUserTypeState();
}

class _SelectUserTypeState extends ConsumerState<SelectUserType> {
  // Sign Up is for Patients only.
  // Doctors, Pharmacy, Lab sign up via Work With Us.
  final List<Map<String, dynamic>> userTypes = [
    {
      "id": 1,
      "title": "I am a Patient",
      "description":
          "Consult verified doctors, access prescriptions & manage your complete health journey.",
      "role": "patient",
      "image": ImagePaths.userType1,
    },
  ];

  int? selected_id;

  void onSelect(int id) {
    setState(() {
      selected_id = id;
    });
  }

  @override
  void dispose() {
    selected_id = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        if (constraints.maxWidth < 600) {
          return _buildMobileLayout(context);
        } else if (constraints.maxWidth < 1200) {
          return _buildDesktopLayout(context, true);
        } else {
          return _buildDesktopLayout(context, false);
        }
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Container(
      width: Utils.windowWidth(context),
      height: Utils.windowHeight(context),
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/images/bgImage.jpeg"),
          fit: BoxFit.cover,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: ScallingConfig.verticalScale(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(height: ScallingConfig.scale(50)),
            CustomText(
              text: "Welcome to Your Healthcare Journey".tr(),
              fontSize: 28,
              maxLines: 2,
              padding: EdgeInsets.only(left: ScallingConfig.moderateScale(12)),
              color: AppColors.themeBlue,
              width: Utils.windowWidth(context) * 0.7,
              fontWeight: FontWeight.w700,
              isBold: true,
            ),
            CustomText(
              text: "Your role helps personalize your experience".tr(),
              padding: EdgeInsets.only(
                top: ScallingConfig.verticalScale(8),
                left: ScallingConfig.moderateScale(12),
              ),
              width: Utils.windowWidth(context) * 0.8,
              textAlign: TextAlign.start,
              fontSize: 14,
              maxLines: 2,
              color: Colors.grey[600],
              isSemiBold: true,
            ),
            SizedBox(height: ScallingConfig.scale(20)),
            Expanded(
              child: Stack(
                children: [
                  Container(
                    clipBehavior: Clip.hardEdge,
                    width: Utils.windowWidth(context),
                    padding: EdgeInsets.symmetric(
                      horizontal: ScallingConfig.scale(10),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(40),
                        topRight: Radius.circular(40),
                      ),
                    ),
                    child: Center(
                      child: ListView.builder(
                        padding: EdgeInsets.only(
                          bottom: ScallingConfig.verticalScale(60),
                        ),
                        itemCount: userTypes.length,
                        itemBuilder: (ctx, i) {
                          return UserTypeCard(
                            image: userTypes[i]["image"],
                            title: userTypes[i]["title"],
                            description: userTypes[i]["description"],
                            benefits: userTypes[i]["benefits"] ?? [],
                            onPressed: () {
                              ref
                                  .read(authProvider.notifier)
                                  .setUserRole(userTypes[i]["role"]);
                              onSelect(userTypes[i]["id"]);
                            },
                            isSelected: selected_id == userTypes[i]["id"],
                          );
                        },
                      ),
                    ),
                  ),
                  if (selected_id != null)
                    Positioned(
                      bottom: ScallingConfig.verticalScale(20),
                      left: ScallingConfig.scale(20),
                      child: CustomButton(
                        width: Utils.windowWidth(context) * 0.9,
                        label: "Continue to Login".tr(),
                        borderRadius: ScallingConfig.moderateScale(30),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => const LoginScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, bool isTablet) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Row(
        children: [
          // ── Left Hero Panel ───────────────────────────────────────
          Expanded(
            flex: 4,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF001E6C),
                    Color(0xFF0036BC),
                    Color(0xFF035BE5),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -80,
                    left: -80,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -100,
                    right: -50,
                    child: Container(
                      width: 350,
                      height: 350,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.03),
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 50),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 32, spreadRadius: 0, offset: Offset(0, 8)),
                                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, spreadRadius: 0, offset: Offset(0, 2)),
                              ],
                            ),
                            child: Image.asset('assets/Asset 1.png', fit: BoxFit.contain, filterQuality: FilterQuality.high),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            "Welcome to iCare".tr(),
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              fontFamily: "Gilroy-Bold",
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Your Virtual Healthcare Platform".tr(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.95),
                              fontFamily: "Gilroy-Bold",
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Secure consultations, prescriptions & health records".tr(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.75),
                              fontFamily: "Gilroy-Medium",
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 48),
                          Column(
                            children: [
                              _buildTrustIndicator(
                                Icons.shield_rounded,
                                "HIPAA Compliant & Secure".tr(),
                              ),
                              const SizedBox(height: 12),
                              _buildTrustIndicator(
                                Icons.verified_user_rounded,
                                "Licensed Healthcare Providers".tr(),
                              ),
                              const SizedBox(height: 12),
                              _buildTrustIndicator(
                                Icons.star_rounded,
                                "Trusted by 10,000+ Patients".tr(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Right Panel: Role Cards ──────────────────────────────
          Expanded(
            flex: 6,
            child: Container(
              color: const Color(0xFFF8FAFD),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: GridView.builder(
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: userTypes.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isTablet ? 2 : 3,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                          childAspectRatio: isTablet ? 1.3 : 1.5,
                        ),
                        itemBuilder: (ctx, i) {
                          return UserTypeCard(
                            image: userTypes[i]["image"],
                            title: userTypes[i]["title"],
                            description: userTypes[i]["description"],
                            benefits: userTypes[i]["benefits"] ?? [],
                            isSelected: selected_id == userTypes[i]["id"],
                            onPressed: () {
                              ref
                                  .read(authProvider.notifier)
                                  .setUserRole(userTypes[i]["role"]);
                              onSelect(userTypes[i]["id"]);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (selected_id != null)
                          Text(
                            "Role selected: ${userTypes.firstWhere((e) => e['id'] == selected_id)['role'].toString().replaceAll('_', ' ').toUpperCase()}",
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              fontFamily: "Gilroy-Medium",
                            ),
                          ),
                        const Spacer(),
                        SizedBox(
                          height: 52,
                          width: 200,
                          child: ElevatedButton.icon(
                            onPressed: selected_id == null
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const LoginScreen(),
                                      ),
                                    );
                                  },
                            icon: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                            label: const Text(
                              "Continue to Login",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                fontFamily: "Gilroy-Bold",
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              disabledBackgroundColor: const Color(0xFFCBD5E1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildTrustIndicator(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 20),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 15,
            fontWeight: FontWeight.w600,
            fontFamily: "Gilroy-Medium",
          ),
        ),
      ],
    );
  }
}
