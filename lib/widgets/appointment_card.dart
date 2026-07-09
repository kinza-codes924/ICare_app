import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/svg_wrapper.dart';
import 'package:icare/screens/video_call.dart';

class AppointmentCard extends StatelessWidget {
  const AppointmentCard({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Utils.windowWidth(context) > 600;

    // ─── MOBILE: exact original ────────────────────────────────────────────
    if (!isDesktop) {
      return Container(
        width: Utils.windowWidth(context) * 0.75,
        margin: EdgeInsets.only(top: ScallingConfig.verticalScale(12)),
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: ScallingConfig.verticalScale(12),
        ),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppColors.veryLightGrey.withValues(alpha: 0.5),
              offset: const Offset(0, 2),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomText(
              text: "Dec 05, 2023 - 10:00 AM",
              color: AppColors.primary500,
              fontSize: 12,
              fontFamily: "Gilroy-SemiBold",
            ),
            SizedBox(height: ScallingConfig.scale(10)),
            Row(
              children: [
                Container(
                  width: Utils.windowWidth(context) * 0.22,
                  height: Utils.windowWidth(context) * 0.22,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.asset(ImagePaths.user1, fit: BoxFit.cover),
                ),
                SizedBox(width: ScallingConfig.scale(12)),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      CustomText(
                        width: double.infinity,
                        text: "Emily Jordan",
                        isSemiBold: true,
                        textAlign: TextAlign.start,
                      ),
                      SizedBox(height: ScallingConfig.scale(5)),
                      Row(
                        children: [
                          SvgWrapper(assetPath: ImagePaths.location),
                          SizedBox(width: Utils.windowWidth(context) * 0.025),
                          CustomText(
                            text: "20 Cooper Square, USA",
                            fontSize: 12,
                            color: AppColors.darkGreyColor,
                          ),
                        ],
                      ),
                      SizedBox(height: ScallingConfig.scale(6)),
                      Row(
                        children: [
                          SvgWrapper(assetPath: ImagePaths.scan),
                          SizedBox(width: Utils.windowWidth(context) * 0.025),
                          CustomText(
                            text: "Booking ID: #DR452SA54",
                            fontSize: 12,
                            color: AppColors.darkGreyColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // ─── DESKTOP: premium redesign ─────────────────────────────────────────
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            offset: const Offset(0, 4),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient accent bar at top
          Container(
            height: 4,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              gradient: LinearGradient(
                colors: [Color(0xFF0036BC), Color(0xFF14B1FF)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date/time badges + status
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0036BC).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: AppColors.primaryColor,
                          ),
                          const SizedBox(width: 6),
                          CustomText(
                            text: "Dec 05, 2023",
                            color: AppColors.primaryColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14B1FF).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: AppColors.secondaryColor,
                          ),
                          const SizedBox(width: 6),
                          CustomText(
                            text: "10:00 AM",
                            color: AppColors.secondaryColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Confirmed badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2EC447).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF2EC447),
                            ),
                          ),
                          const SizedBox(width: 6),
                          CustomText(
                            text: "Confirmed",
                            fontSize: 12,
                            color: const Color(0xFF2EC447),
                            fontWeight: FontWeight.w600,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Patient row
                Row(
                  children: [
                    // Avatar with ring
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primaryColor.withValues(alpha: 0.15),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryColor.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(17),
                        child: Image.asset(
                          ImagePaths.user1,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomText(
                            text: "Emily Jordan",
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: SvgWrapper(
                                  assetPath: ImagePaths.location,
                                ),
                              ),
                              const SizedBox(width: 10),
                              CustomText(
                                text: "20 Cooper Square, USA",
                                fontSize: 13,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: SvgWrapper(assetPath: ImagePaths.scan),
                              ),
                              const SizedBox(width: 10),
                              CustomText(
                                text: "Booking ID: ",
                                fontSize: 13,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                              CustomText(
                                text: "#DR452SA54",
                                fontSize: 13,
                                color: AppColors.primaryColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Action buttons
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.message_outlined,
                        color: AppColors.primaryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => const VideoCall(
                              channelName: 'call_appointment',
                              remoteUserName: 'Emily Jordan',
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.videocam_rounded,
                          color: AppColors.primaryColor,
                          size: 22,
                        ),
                      ),
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
