import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/custom_text_input.dart';
import 'package:icare/widgets/svg_wrapper.dart';

class ChangePassword extends StatefulWidget {
  const ChangePassword({super.key});

  @override
  State<ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<ChangePassword> {
  final TextEditingController emailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width > 600) {
      return _WebChangePassword(formKey: _formKey);
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: CustomBackButton(),
        title: CustomText(
          text: "Change Password".tr(),
          fontFamily: "Gilroy-Bold",
          fontSize: 16,
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: ScallingConfig.scale(20),
            vertical: ScallingConfig.verticalScale(20),
          ),

          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomInputField(
                  maxLines: 1,
                  hintText: "Current Password".tr(),
                  leadingIcon: SvgWrapper(assetPath: ImagePaths.key),
                  isPassword: true,
                  bgColor: AppColors.white,
                  borderRadius: 30,
                  borderColor: AppColors.veryLightGrey,
                  borderWidth: 2,
                ),
                SizedBox(height: ScallingConfig.scale(10)),
                CustomInputField(
                  maxLines: 1,
                  hintText: "New Password".tr(),
                  leadingIcon: SvgWrapper(assetPath: ImagePaths.key),
                  isPassword: true,
                  bgColor: AppColors.white,
                  borderRadius: 30,
                  borderColor: AppColors.veryLightGrey,
                  borderWidth: 2,
                ),
                SizedBox(height: ScallingConfig.scale(10)),
                CustomInputField(
                  maxLines: 1,
                  hintText: "Confirm Password".tr(),
                  leadingIcon: SvgWrapper(assetPath: ImagePaths.key),
                  isPassword: true,
                  bgColor: AppColors.white,
                  borderRadius: 30,
                  borderColor: AppColors.veryLightGrey,
                  borderWidth: 2,
                  // validator: (val) {
                  //   if (val == null || val.isEmpty) {
                  //     return "Please enter your username";
                  //   }
                  //   return null;
                  // },
                ),
                SizedBox(height: ScallingConfig.scale(10)),

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
                      // if (_formKey.currentState!.validate()) {
                      //   _showSuccessModal(context);
                      // }
                      _showSuccessModal(context);
                    },
                    child: Text(
                      "Confirm".tr(),
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WebChangePassword extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  const _WebChangePassword({required this.formKey});

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
          text: "Change Password".tr(),
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
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF1F4F9), width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    offset: Offset(0, 4),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_reset_rounded,
                        size: 40,
                        color: AppColors.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Update your Password".tr(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                        fontFamily: "Gilroy-Bold",
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Choose a strong password to keep your account safe and secure.".tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, color: Color(0xFF64748B)),
                    ),

                    const SizedBox(height: 32),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Current Password".tr(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        CustomInputField(
                          maxLines: 1,
                          hintText: "Enter current password".tr(),
                          leadingIcon: SvgWrapper(assetPath: ImagePaths.key),
                          isPassword: true,
                          bgColor: const Color(0xFFF8FAFC),
                          borderRadius: 12,
                          borderColor: const Color(0xFFE2E8F0),
                          borderWidth: 1.5,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "New Password".tr(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        CustomInputField(
                          maxLines: 1,
                          hintText: "Enter new password".tr(),
                          leadingIcon: SvgWrapper(assetPath: ImagePaths.key),
                          isPassword: true,
                          bgColor: const Color(0xFFF8FAFC),
                          borderRadius: 12,
                          borderColor: const Color(0xFFE2E8F0),
                          borderWidth: 1.5,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Confirm Password".tr(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        CustomInputField(
                          maxLines: 1,
                          hintText: "Confirm your password".tr(),
                          leadingIcon: SvgWrapper(assetPath: ImagePaths.key),
                          isPassword: true,
                          bgColor: const Color(0xFFF8FAFC),
                          borderRadius: 12,
                          borderColor: const Color(0xFFE2E8F0),
                          borderWidth: 1.5,
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          _showSuccessModal(context);
                        },
                        child: Text(
                          "Confirm Changes".tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: "Gilroy-SemiBold",
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
      ),
    );
  }
}

void _showSuccessModal(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) {
      bool isWeb = MediaQuery.of(context).size.width > 600;
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isWeb ? 24 : 20),
        ),
        child: Container(
          constraints: BoxConstraints(maxWidth: isWeb ? 400 : double.infinity),
          padding: EdgeInsets.all(isWeb ? 40 : 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: isWeb ? 80 : 70,
                width: isWeb ? 80 : 70,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: isWeb ? 48 : 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Password Changed".tr(),
                style: TextStyle(
                  fontSize: isWeb ? 22 : 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                  fontFamily: isWeb ? "Gilroy-Bold" : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "You've successfully changed your password".tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isWeb ? 15 : 13,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(isWeb ? 12 : 30),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                  },
                  child: Text(
                    "Go Back".tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
