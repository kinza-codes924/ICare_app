import 'package:easy_localization/easy_localization.dart';
import 'package:icare/widgets/drag_scroll.dart';
import 'package:flutter/material.dart';
import 'package:icare/widgets/success_dialog.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/custom_text_input.dart';
import 'package:icare/widgets/svg_wrapper.dart';
import 'package:icare/services/api_service.dart';
import 'package:dio/dio.dart' show DioException;

class ChangePassword extends StatefulWidget {
  const ChangePassword({super.key});

  @override
  State<ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<ChangePassword> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// Actually changes the password.
  ///
  /// This screen previously had no controllers and no network call at all -
  /// "Confirm Changes" only opened the success modal, so every user was told
  /// their password had changed when nothing had happened. The client asked
  /// directly whether this worked; it did not.
  Future<void> _submit() async {
    final current = _currentController.text;
    final next = _newController.text;
    final confirm = _confirmController.text;

    String? error;
    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      error = 'Please fill in all three fields';
    } else if (next.length < 6) {
      error = 'New password must be at least 6 characters';
    } else if (next != confirm) {
      error = 'New password and confirmation do not match';
    } else if (next == current) {
      error = 'New password must be different from your current one';
    }
    if (error != null) {
      _toast(error);
      return;
    }

    setState(() => _saving = true);
    try {
      final res = await ApiService().post('/auth/change_password', {
        'currentPassword': current,
        'newPassword': next,
        'confirmPassword': confirm,
      });
      if (!mounted) return;
      if (res.data['success'] == true) {
        _currentController.clear();
        _newController.clear();
        _confirmController.clear();
        _showSuccessModal(context);
      } else {
        _toast(res.data['message']?.toString() ?? 'Could not change password');
      }
    } catch (e) {
      if (!mounted) return;
      // The backend returns a plain message for a wrong current password, so
      // show that rather than a generic failure.
      String msg = 'Could not change password';
      if (e is DioException && e.response?.data is Map) {
        msg = e.response?.data['message']?.toString() ?? msg;
      }
      _toast(msg);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade600),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width > 600) {
      return _WebChangePassword(
        formKey: _formKey,
        currentController: _currentController,
        newController: _newController,
        confirmController: _confirmController,
        saving: _saving,
        onSubmit: _submit,
      );
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
      body: DragScroll(
        builder: (context, dragScrollCtrl) => SingleChildScrollView(
          controller: dragScrollCtrl,
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
                    maxLength: 64,
                    controller: _currentController,
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
                    maxLength: 64,
                    controller: _newController,
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
                    maxLength: 64,
                    controller: _confirmController,
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
                      onPressed: _saving ? null : _submit,
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
      ),
    );
  }
}

class _WebChangePassword extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController currentController;
  final TextEditingController newController;
  final TextEditingController confirmController;
  final bool saving;
  final VoidCallback onSubmit;
  const _WebChangePassword({
    required this.formKey,
    required this.currentController,
    required this.newController,
    required this.confirmController,
    required this.saving,
    required this.onSubmit,
  });

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
      body: DragScroll(
        builder: (context, dragScrollCtrl) => SingleChildScrollView(
          controller: dragScrollCtrl,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFF1F4F9),
                    width: 1.5,
                  ),
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
                        "Choose a strong password to keep your account safe and secure."
                            .tr(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF64748B),
                        ),
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
                            maxLength: 64,
                            controller: currentController,
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
                            maxLength: 64,
                            controller: newController,
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
                            maxLength: 64,
                            controller: confirmController,
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
                          onPressed: saving ? null : onSubmit,
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
      ),
    );
  }
}

void _showSuccessModal(BuildContext context) {
  showSuccessDialog(
    context,
    title: "Password Changed".tr(),
    message: "You've successfully changed your password".tr(),
  );
}
