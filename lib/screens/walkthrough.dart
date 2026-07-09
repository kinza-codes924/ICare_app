import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/screens/login.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:intro_slider/intro_slider.dart';

class Walkthrough extends ConsumerStatefulWidget {
  const Walkthrough({super.key});

  @override
  ConsumerState<Walkthrough> createState() => _WalkthroughState();
}

class _WalkthroughState extends ConsumerState<Walkthrough> {
  final List<ContentConfig> listContentConfig = [
    ContentConfig(
      title: "More Comfortable Chat With the Doctor".tr(),
      description:
          "Book an appointment with doctor. Chat with doctor via appointment letter and get consultation.".tr(),
      pathImage: "assets/images/walkthrough1.png",
    ),
    ContentConfig(
      title: "More Comfortable Chat With the Doctor".tr(),
      description:
          "Book an appointment with doctor. Chat with doctor via appointment letter and get consultation.".tr(),
      pathImage: "assets/images/walkthrough2.png",
    ),
    ContentConfig(
      title: "More Comfortable Chat With the Doctor".tr(),
      description:
          "Book an appointment with doctor. Chat with doctor via appointment letter and get consultation.".tr(),
      pathImage: "assets/images/walkthrough3.png",
    ),
  ];
  int currentIndex = 0;
  late Function goToTab;

  void onDonePress() {
    debugPrint("🎯 Onboarding Complete!");
    // Navigate to home screen here
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;
    if (isDesktop) {
      return _buildWebLayout();
    }
    return _buildMobileLayout();
  }

  // ══════════════════════════════════════════════════════════════════════
  // MOBILE LAYOUT — completely untouched original
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildMobileLayout() {
    return Scaffold(
      body: IntroSlider(
        refFuncGoToTab: (refFunc) {
          goToTab = refFunc;
        },
        onTabChangeCompleted: (index) {
          setState(() => currentIndex = index);
        },

        navigationBarConfig: NavigationBarConfig(navPosition: NavPosition.top),
        isShowDoneBtn: false,
        isShowNextBtn: false,
        isShowSkipBtn: false,
        isShowPrevBtn: false,
        indicatorConfig: IndicatorConfig(isShowIndicator: false),
        listCustomTabs: listContentConfig.asMap().entries.map((entry) {
          final int index = entry.key;
          final ContentConfig item = entry.value;
          return Stack(
            children: [
              Container(
                width: Utils.windowWidth(context),
                height: Utils.windowHeight(context),
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage("assets/images/bgImage.jpeg"),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: kIsWeb
                          ? ScallingConfig.scale(300)
                          : double.infinity,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          flex: kIsWeb ? 4 : 6,

                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Image.asset(
                              item.pathImage!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),

                        Container(
                          clipBehavior: Clip.hardEdge,
                          padding: EdgeInsets.symmetric(
                            horizontal: ScallingConfig.moderateScale(20),
                            vertical: ScallingConfig.moderateScale(25),
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(
                                ScallingConfig.moderateScale(22.6),
                              ),
                              topLeft: Radius.circular(
                                ScallingConfig.moderateScale(22.6),
                              ),
                            ),
                          ),

                          child: SingleChildScrollView(
                            child: Column(
                              spacing: 25,
                              children: [
                                Text(
                                  item.title!,
                                  style: TextStyle(
                                    fontSize: ScallingConfig.moderateScale(
                                      23.7,
                                    ),
                                    color: AppColors.primary500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                Text(
                                  item.description!,
                                  style: TextStyle(
                                    color: AppColors.grayColor,
                                    fontSize: ScallingConfig.moderateScale(
                                      12.5,
                                    ),
                                  ),
                                ),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    listContentConfig.length,
                                    (dotIndex) => AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 10,
                                      ),
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                      ),
                                      height: 8,
                                      width: currentIndex == dotIndex ? 20 : 8,
                                      decoration: BoxDecoration(
                                        color: currentIndex == dotIndex
                                            ? Colors.red
                                            : Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),

                                CustomButton(
                                  label: index != 2 ? "Next".tr() : "Done".tr(),
                                  onPressed: () {
                                    if (index != 2) {
                                      goToTab(currentIndex + 1);
                                    } else {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (ctx) {
                                            return const LoginScreen();
                                          },
                                        ),
                                      );
                                    }
                                  },
                                  borderRadius: 40,
                                ),
                                SizedBox(height: ScallingConfig.scale(20)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: Utils.windowHeight(context) * 0.09,
                right: Utils.windowWidth(context) * 0.08,
                child: CustomButton(
                  width: ScallingConfig.scale(70),
                  borderRadius: 20,
                  gradient: LinearGradient(
                    begin: AlignmentGeometry.topRight,
                    end: AlignmentGeometry.bottomLeft,
                    colors: [
                      AppColors.white.withValues(alpha: 0.56),
                      AppColors.white.withValues(alpha: 0.015),
                    ],
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => const LoginScreen()),
                    );
                  },
                  labelColor: AppColors.primaryColor,
                  label: "Skip".tr(),
                  labelSize: 14,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // WEB / DESKTOP LAYOUT — premium responsive design
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildWebLayout() {
    final item = listContentConfig[currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Row(
        children: [
          // ── Left Panel: Illustration ────────────────────────────────
          Expanded(
            flex: 5,
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
                  // Decorative circles
                  Positioned(
                    top: -100,
                    left: -100,
                    child: Container(
                      width: 350,
                      height: 350,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -80,
                    right: -40,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.03),
                      ),
                    ),
                  ),
                  // Illustration image - properly fitted
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(80),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: Tween<double>(
                                    begin: 0.95,
                                    end: 1.0,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                        child: ConstrainedBox(
                          key: ValueKey<int>(currentIndex),
                          constraints: const BoxConstraints(
                            maxWidth: 500,
                            maxHeight: 500,
                          ),
                          child: Image.asset(
                            item.pathImage!,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Step indicator on the left
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        "Step ${currentIndex + 1} of ${listContentConfig.length}",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          fontFamily: "Gilroy-Medium",
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Right Panel: Content ───────────────────────────────────
          Expanded(
            flex: 5,
            child: Container(
              color: const Color(0xFFF8FAFD),
              child: Center(
                child: SingleChildScrollView(
                  child: Container(
                    width: 520,
                    margin: const EdgeInsets.symmetric(vertical: 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 56,
                      vertical: 56,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF0036BC,
                          ).withValues(alpha: 0.06),
                          blurRadius: 40,
                          offset: const Offset(0, 16),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // iCare Logo badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withValues(
                              alpha: 0.06,
                            ),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Text(
                            "iCare Onboarding",
                            style: TextStyle(
                              color: AppColors.primaryColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              fontFamily: "Gilroy-Bold",
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Title
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            item.title!,
                            key: ValueKey<String>("title_$currentIndex"),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0B2D6E),
                              fontFamily: "Gilroy-Bold",
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Description
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            item.description!,
                            key: ValueKey<String>("desc_$currentIndex"),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                              fontFamily: "Gilroy-Medium",
                              height: 1.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Dot indicators
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            listContentConfig.length,
                            (dotIndex) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              height: 10,
                              width: currentIndex == dotIndex ? 36 : 10,
                              decoration: BoxDecoration(
                                color: currentIndex == dotIndex
                                    ? AppColors.primaryColor
                                    : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Navigation buttons
                        Row(
                          children: [
                            // Skip button
                            Expanded(
                              child: SizedBox(
                                height: 54,
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (ctx) => const LoginScreen(),
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text(
                                    "Skip",
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      fontFamily: "Gilroy-SemiBold",
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Next / Done button
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 54,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    if (currentIndex <
                                        listContentConfig.length - 1) {
                                      setState(() {
                                        currentIndex++;
                                      });
                                    } else {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (ctx) => const LoginScreen(),
                                        ),
                                      );
                                    }
                                  },
                                  icon: Icon(
                                    currentIndex < listContentConfig.length - 1
                                        ? Icons.arrow_forward_rounded
                                        : Icons.check_rounded,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    currentIndex < listContentConfig.length - 1
                                        ? "Next"
                                        : "Get Started",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      fontFamily: "Gilroy-Bold",
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ),
                          ],
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
    );
  }
}
