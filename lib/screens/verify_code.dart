import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/screens/reset_password.dart';
import 'package:icare/services/auth_service.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/auth_left_panel.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class VerifyCode extends StatefulWidget {
  final String email;
  const VerifyCode({super.key, required this.email});

  @override
  State<VerifyCode> createState() => _VerifyCodeState();
}

class _VerifyCodeState extends State<VerifyCode> {
  final TextEditingController codeController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  bool isLoading = false;

  void _handleVerifyOTP() async {
    if (codeController.text.length != 6) {
      _showError('Please enter the 6-digit code');
      return;
    }

    setState(() => isLoading = true);

    try {
      final result = await _authService.verifyOTP(
        email: widget.email,
        code: codeController.text.trim(),
      );

      if (result['success']) {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => ResetPassword(email: widget.email),
            ),
          );
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

  void _handleResendOTP() async {
    setState(() => isLoading = true);

    try {
      final result = await _authService.forgotPassword(email: widget.email);

      if (result['success']) {
        debugPrint('New OTP for testing: ${result['otp']}');
        _showSuccess('OTP resent successfully');
      } else {
        _showError(result['message']);
      }
    } catch (e) {
      _showError('Failed to resend OTP');
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

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    final isDesktop = ResponsiveHelper.isDesktop(context);

    return Scaffold(
      appBar: null,
      backgroundColor: Colors.white,
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
                    width: 480,
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
                          "Verification Code".tr(),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0B2D6E),
                            fontFamily: "Gilroy-Bold",
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "We've sent a 5-digit verification code to your registered account".tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[500],
                            fontFamily: "Gilroy-Medium",
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Form
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              PinCodeTextField(
                                appContext: context,
                                length: 6,
                                controller: codeController,
                                animationType: AnimationType.fade,
                                keyboardType: TextInputType.number,
                                textStyle: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0B2D6E),
                                ),
                                pinTheme: PinTheme(
                                  shape: PinCodeFieldShape.box,
                                  borderRadius: BorderRadius.circular(12),
                                  fieldHeight: 64,
                                  fieldWidth: 54,
                                  inactiveColor: const Color(0xFFE2E8F0),
                                  activeColor: AppColors.primaryColor,
                                  selectedColor: AppColors.primaryColor,
                                  activeFillColor: const Color(0xFFF8FAFC),
                                  inactiveFillColor: const Color(0xFFF8FAFC),
                                  selectedFillColor: Colors.white,
                                  borderWidth: 1.5,
                                ),
                                cursorColor: AppColors.primaryColor,
                                enableActiveFill: true,
                                onChanged: (value) {},
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Didn't receive the code?".tr(),
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: isLoading
                                        ? null
                                        : _handleResendOTP,
                                    child: Text(
                                      "Resend".tr(),
                                      style: const TextStyle(
                                        color: AppColors.primaryColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 40),
                              // Confirm Button
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
                                  onPressed: isLoading
                                      ? null
                                      : _handleVerifyOTP,
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
                                          "Confirm & Verify".tr(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            fontFamily: "Gilroy-Bold",
                                          ),
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
          padding: EdgeInsets.symmetric(
            horizontal: ScallingConfig.moderateScale(15),
            vertical: ScallingConfig.moderateScale(isTablet ? 60 : 100),
          ),
          child: Column(
            crossAxisAlignment: isTablet
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,

            children: [
              SizedBox(height: ScallingConfig.moderateScale(30)),
              CustomText(
                text: "Verification Code".tr(),
                fontWeight: FontWeight.w900,
                fontSize: 22,
                color: AppColors.primaryColor,
              ),
              SizedBox(height: 3),
              CustomText(
                maxLines: 2,
                textAlign: isTablet ? TextAlign.center : TextAlign.start,
                text:
                    "Forgot Password To Enjoy The Best Doctor Consultation Experience",
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
            height: isTablet
                ? Utils.windowHeight(context) * 0.6
                : Utils.windowHeight(context) * 0.7,
            width: isTablet
                ? Utils.windowWidth(context) * 0.7
                : double.infinity,
            decoration: BoxDecoration(
              color: isTablet
                  ? AppColors.bgColor.withAlpha(70)
                  : AppColors.bgColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(40),
                topRight: Radius.circular(40),
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isTablet
                  ? ScallingConfig.scale(50)
                  : ScallingConfig.scale(15),
              vertical: 30,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PinCodeTextField(
                      appContext: context,
                      length: 6,
                      controller: codeController,
                      animationType: AnimationType.fade,

                      keyboardType: TextInputType.number,
                      pinTheme: PinTheme(
                        shape: PinCodeFieldShape.circle,
                        borderRadius: BorderRadius.circular(50),
                        fieldHeight: 60,
                        fieldWidth: 60,
                        inactiveColor: isTablet
                            ? AppColors.white
                            : Colors.grey.shade300,
                        activeColor: Colors.blue,

                        selectedColor: Colors.blueAccent,
                        activeFillColor: Colors.red,
                        inactiveFillColor: Colors.white,
                        selectedFillColor: Colors.white,
                      ),
                      cursorColor: Colors.blue,
                      enableActiveFill: false,
                      onChanged: (value) {},
                    ),
                    Container(
                      alignment: Alignment.topRight,
                      child: TextButton(
                        onPressed: isLoading ? null : _handleResendOTP,
                        child: Text(
                          "Resend Code".tr(),
                          style: TextStyle(
                            color: isTablet
                                ? AppColors.white
                                : AppColors.themeBlack,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

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
                        onPressed: isLoading ? null : _handleVerifyOTP,
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
                                "Confirm".tr(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: ScallingConfig.scale(30),
          left: ScallingConfig.scale(isTablet ? 10 : -10),
          child: CustomBackButton(),
        ),
      ],
    );
  }
}
