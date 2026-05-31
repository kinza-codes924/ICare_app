import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/screens/create_profile.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/custom_text.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    if (isDesktop) {
      return _WebProfileInitial(ref: ref);
    }

    return Center(
      child: CustomButton(
        label: "Create Profile".tr(),
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (ctx) => const CreateProfile()));
        },
      ),
    );
  }
}

class _WebProfileInitial extends StatelessWidget {
  final WidgetRef ref;
  const _WebProfileInitial({required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: Container(
          width: 800,
          padding: const EdgeInsets.all(60),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Illustration / Icon
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.account_circle_rounded,
                    size: 100,
                    color: AppColors.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              CustomText(
                text: "Complete Your Profile".tr(),
                fontSize: 32,
                fontFamily: "Gilroy-Bold",
                color: const Color(0xFF1E293B),
                fontWeight: FontWeight.w800,
              ),
              const SizedBox(height: 16),
              CustomText(
                text:
                    "To get the most out of ICare, please set up your medical profile. This helps us provide personalized recommendations and seamless care.".tr(),
                fontSize: 16,
                color: Color(0xFF64748B),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 54),
              SizedBox(
                width: 320,
                height: 64,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => const CreateProfile(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    "Create Profile Now".tr(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: "Gilroy-Bold",
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 320,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(authProvider.notifier).setUserLogout();
                    context.go('/login');
                  },
                  icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  label: Text(
                    'Logout'.tr(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.redAccent,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {},
                child: Text(
                  "Why do I need this?".tr(),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
