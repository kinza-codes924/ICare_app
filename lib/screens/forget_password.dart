import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/screens/verify_code.dart';
import 'package:icare/services/auth_service.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/auth_left_panel.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/custom_text_input.dart';

class ForgetPassword extends StatefulWidget {
  const ForgetPassword({super.key});

  @override
  State<ForgetPassword> createState() => _ForgetPasswordState();
}

class _ForgetPasswordState extends State<ForgetPassword> {
  final TextEditingController emailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  bool isLoading = false;

  void _handleSendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final result = await _authService.forgotPassword(
        email: emailController.text.trim(),
      );

      if (result['success']) {
        if (mounted) {
          final emailSent = result['emailSent'] == true;
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(children: [
                Icon(Icons.mark_email_read_rounded,
                  color: const Color(0xFF10B981), size: 22),
                const SizedBox(width: 8),
                const Text('Code Sent',
                  style: TextStyle(fontFamily: 'Gilroy-Bold', fontSize: 18)),
              ]),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'A verification code has been sent to ${emailController.text.trim()}. Please check your email.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('The code is valid for 10 minutes.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK', style: TextStyle(color: Color(0xFF0036BC), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => VerifyCode(email: emailController.text.trim()),
              ),
            );
          }
        }
      } else {
        _showError(result['message']);
      }
    } catch (e) {
      _showError('An error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    final isDesktop = ResponsiveHelper.isDesktop(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: null,

      body: isDesktop
          ? _buildDesktopLayout()
          : _buildMobileLayout(isTablet: isTablet),
    );
  }

  Widget _buildDesktopLayout() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return SizedBox(
      width: screenWidth,
      height: screenHeight,
      child: Row(
        children: [
          // ══════════════════════════════════════════════════════════════
          // LEFT HERO PANEL — gradient + branding
          // ══════════════════════════════════════════════════════════════
          const Expanded(
            flex: 5,
            child: AuthLeftPanel(),
          ),

          // ══════════════════════════════════════════════════════════════
          // RIGHT FORM PANEL
          // ══════════════════════════════════════════════════════════════
          Expanded(
            flex: 5,
            child: Container(
              color: const Color(0xFFF8FAFD),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Container(
                    width: 460,
                    padding: const EdgeInsets.all(48),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0036BC).withValues(alpha: 0.06),
                          blurRadius: 40,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Back Icon Button
                        Align(
                          alignment: Alignment.topLeft,
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 18,
                                color: Color(0xFF0B2D6E),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Header
                        Text(
                          "Forgot Password?".tr(),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0B2D6E),
                            fontFamily: "Gilroy-Bold",
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Enter your email or phone to receive a verification code".tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[500],
                            fontFamily: "Gilroy-Medium",
                          ),
                        ),
                        const SizedBox(height: 36),

                        // Form
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              CustomInputField(
                                hintText: "Email or Phone Number".tr(),
                                leadingIcon: const Icon(
                                  Icons.mail_outline_rounded,
                                  color: Color(0xFF94A3B8),
                                  size: 22,
                                ),
                                controller: emailController,
                                bgColor: const Color(0xFFF8FAFC),
                                borderRadius: 14,
                                borderColor: const Color(0xFFE2E8F0),
                                borderWidth: 1.5,
                                validator: (val) {
                                  if (val == null || val.isEmpty) {
                                    return "This field is required".tr();
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 40),
                              // Send Button
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: () {
                                    if (_formKey.currentState!.validate()) {
                                      _handleSendOTP();
                                    }
                                  },
                                  child: isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          "Send Verification Code".tr(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            fontFamily: "Gilroy-Bold",
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              // Back to Login link for those who don't see the top button
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  "Back to Login".tr(),
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    fontFamily: "Gilroy-SemiBold",
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widgets for desktop layout
  Widget _buildDecorativeCircle({
    double? top,
    double? left,
    double? right,
    double? bottom,
    required double size,
    required double opacity,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 18),
        ),
        const SizedBox(width: 16),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamily: "Gilroy-Medium",
          ),
        ),
      ],
    );
  }

  Widget _buildCopyright() {
    return Positioned(
      bottom: 30,
      left: 0,
      right: 0,
      child: Center(
        child: Text(
          "© 2026 iCare Health Technologies",
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout({bool isTablet = false}) {
    return Stack(
      children: [
        Container(
          width: Utils.windowWidth(context),
          height: Utils.windowHeight(context),
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage(ImagePaths.backgroundImage),
              fit: BoxFit.cover,
            ),
          ),
        ),

        Container(
          width: Utils.windowWidth(context),
          height: isTablet
              ? Utils.windowHeight(context) * 0.35
              : double.infinity,

          padding: EdgeInsets.symmetric(
            horizontal: ScallingConfig.moderateScale(15),
            vertical: ScallingConfig.moderateScale(isTablet ? 20 : 100),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: ScallingConfig.moderateScale(30)),
              CustomText(
                text: "Forget Password".tr(),
                fontWeight: FontWeight.w900,
                textAlign: TextAlign.center,
                fontSize: 22,
                color: AppColors.primaryColor,
              ),
              SizedBox(height: 3),
              CustomText(
                maxLines: 2,
                textAlign: TextAlign.center,
                text:
                    "Please enter your email or phone number to reset password".tr(),
                fontSize: 13,
                width: Utils.windowHeight(context) * 0.4,
                color: AppColors.themeBlack,
              ),
              SizedBox(height: 20),
            ],
          ),
        ),

        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: isTablet
                ? Utils.windowWidth(context) * 0.7
                : double.infinity,
            height: Utils.windowHeight(context) * 0.67,
            decoration: BoxDecoration(
              color: isTablet
                  ? AppColors.bgColor.withAlpha(70)
                  : AppColors.bgColor,
              // color: AppColors.grayColor.withAlpha(60),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(40),
                topRight: Radius.circular(40),
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 50 : 15,
              vertical: 30,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomInputField(
                      hintText: "Email or Phone Number".tr(),
                      leadingIcon: Icon(
                        Icons.person_outline,
                        color: AppColors.primary500,
                      ),
                      controller: emailController,
                      bgColor: AppColors.white,
                      borderRadius: 30,
                      borderColor: AppColors.veryLightGrey,
                      borderWidth: 2,
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return "Please enter your username".tr();
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 50),

                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () {
                          _handleSendOTP();
                        },
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                "Send".tr(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "Back to Login".tr(),
                          style: const TextStyle(
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: ScallingConfig.scale(isTablet ? 20 : 40),
          child: CustomBackButton(),
        ),
      ],
    );
  }
}
