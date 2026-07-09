import 'package:flutter/material.dart';
import 'package:icare/models/lab.dart';
import 'package:icare/screens/book_lab.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/widgets/custom_text.dart';

class LabWidget extends StatelessWidget {
  const LabWidget({
    super.key,
    required this.lab,
    this.actionText = '',
    this.onActionBtnPressed,
  });
  final Lab lab;
  final String actionText;
  final VoidCallback? onActionBtnPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: AppColors.primaryColor.withValues(alpha: 0.04),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Lab Image with premium border and creative badge
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryColor.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: lab.photo!.startsWith('http')
                          ? Image.network(
                              lab.photo!,
                              fit: BoxFit.cover,
                              width: 85,
                              height: 85,
                              errorBuilder: (context, error, stackTrace) =>
                                  Image.asset(
                                    ImagePaths.lab1,
                                    fit: BoxFit.cover,
                                    width: 85,
                                    height: 85,
                                  ),
                            )
                          : Image.asset(
                              lab.photo!,
                              fit: BoxFit.cover,
                              width: 85,
                              height: 85,
                            ),
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),

              // Laboratory Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: CustomText(
                            text: lab.title!,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            fontFamily: "Gilroy-Bold",
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFEF3C7)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFD97706,
                                ).withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 16,
                                color: Color(0xFFD97706),
                              ),
                              const SizedBox(width: 6),
                              CustomText(
                                text: lab.rating,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF92400E),
                                letterSpacing: 0.2,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 15,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: CustomText(
                            text: lab.address,
                            color: const Color(0xFF64748B),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Quick Status Tags
                    Row(
                      children: [
                        _buildStatusTag(
                          "Verified Clinic",
                          const Color(0xFF6366F1),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusTag(
                          "Digital Results",
                          const Color(0xFF0EA5E9),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 24),

          // Detail Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText(
                      text: "Estimated Delivery",
                      color: const Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 14,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: CustomText(
                            text: lab.delivery,
                            color: const Color(0xFF0F172A),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // STUNNING ACTION BUTTON
              SizedBox(
                width: 160,
                child: CustomButton(
                  label: actionText,
                  height: 48,
                  borderRadius: 16,
                  labelSize: 13,
                  labelWeight: FontWeight.w900,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF334155)],
                  ),
                  onPressed:
                      onActionBtnPressed ??
                      () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => const BookLabScreen(),
                          ),
                        );
                      },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomText(
        text: label,
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
