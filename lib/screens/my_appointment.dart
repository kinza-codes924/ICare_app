import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/svg_wrapper.dart';

class MyAppointment extends StatelessWidget {
  const MyAppointment({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Utils.windowWidth(context) > 900;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFD),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 16,
                          color: AppColors.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Back to Dashboard",
                          style: TextStyle(
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Appointment Details",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Review your scheduled appointment information and payment summary.",
                    style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 32),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      image: const DecorationImage(
                                        image: AssetImage(ImagePaths.user1),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              "Emily Jordan",
                                              style: TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            TextButton.icon(
                                              onPressed: () {},
                                              icon: const Icon(
                                                Icons.visibility_outlined,
                                                size: 18,
                                              ),
                                              label: const Text("View Full Details"),
                                              style: TextButton.styleFrom(
                                                foregroundColor:
                                                    AppColors.primaryColor,
                                                textStyle: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Color(0xFF10B981).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                size: 14,
                                                color: Color(0xFF10B981),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                "Confirmed",
                                                style: TextStyle(
                                                  color: Color(0xFF10B981),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.location_on_rounded,
                                              size: 16,
                                              color: Color(0xFF94A3B8),
                                            ),
                                            const SizedBox(width: 6),
                                            const Text(
                                              "20 Cooper Square, USA",
                                              style: TextStyle(
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryColor
                                                .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.qr_code_scanner_rounded,
                                                size: 14,
                                                color: AppColors.primaryColor,
                                              ),
                                              const SizedBox(width: 6),
                                              const Text(
                                                "Booking ID: #DR452SA54",
                                                style: TextStyle(
                                                  color: AppColors.primaryColor,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            GridView(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 24,
                                    mainAxisSpacing: 24,
                                    mainAxisExtent: 220,
                                  ),
                              children: [
                                _WebInfoCard(
                                  title: "Scheduled Appointment",
                                  icon: Icons.calendar_today_rounded,
                                  accentColor: const Color(0xFF6366F1),
                                  data: {
                                    "Date": "December, 05, 2025",
                                    "Time": "10:00 AM – 10:30 AM",
                                    "Duration": "30 minutes",
                                    "Booking for": "Self",
                                  },
                                ),
                                _WebInfoCard(
                                  title: "Patient Info",
                                  icon: Icons.person_outline_rounded,
                                  accentColor: const Color(0xFF0EA5E9),
                                  data: {
                                    "Gender": "Female",
                                    "Age": "32",
                                    "Guardians": "Guardians",
                                    "Problem": "N/A",
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      // Right Column
                      SizedBox(
                        width: 340,
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Payment Summary",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 20),
                              _WebPaymentRow(
                                label: "Consultation Fee",
                                value: "PKR 2,000",
                              ),
                              _WebPaymentRow(
                                label: "Service Charges",
                                value: "PKR 100",
                              ),
                              _WebPaymentRow(
                                label: "App Deduction",
                                value: "-PKR 200",
                                isNegative: true,
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Divider(height: 1),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Total Balance",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const Text(
                                    "PKR 1,900",
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    "Proceed to Payment",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () {},
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: const BorderSide(
                                      color: Colors.redAccent,
                                      width: 1,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    "Cancel Appointment",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bgColor,
        automaticallyImplyLeading: false,
        leading: CustomBackButton(),
        title: CustomText(
          text: "My Appointment",
          fontSize: 16.78,
          letterSpacing: -0.31,
          lineHeight: 1.0,
          fontFamily: "Gilroy-Bold",
          fontWeight: FontWeight.bold,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ProfileInfoWidget(),
            DetailsInfoWidget(
              title: "Scheduled Appointment",
              data: {
                "Date": "December, 05, 2025",
                "Time": "10:00 AM – 10:30 AM (30 minutes)",
                "Booking for": "Self",
              },
            ),
            DetailsInfoWidget(
              title: "Patient Info",
              data: {
                "Gender": "Female",
                "Age": "32",
                "Patient Guardians": "Guardians",
                "Problem": "N/A",
              },
            ),
            SizedBox(height: ScallingConfig.scale(10)),
            AmountContainer(leadingText: "PKR", trailingText: "2000"),
            SizedBox(height: ScallingConfig.scale(20)),
            HorizontalText(
              padding: EdgeInsets.symmetric(
                horizontal: ScallingConfig.scale(15),
                vertical: ScallingConfig.scale(10),
              ),
              leadingText: "Service charges",
              trailingText: "PKR 2000",
            ),
            HorizontalText(
              padding: EdgeInsets.symmetric(
                horizontal: ScallingConfig.scale(15),
                vertical: ScallingConfig.scale(10),
              ),
              leadingText: "App Deduction (20%)",
              trailingText: "-PKR 200",
            ),
            HorizontalText(
              padding: EdgeInsets.symmetric(
                horizontal: ScallingConfig.scale(15),
                vertical: ScallingConfig.scale(10),
              ),
              leadingText: "Total Balance",
              trailingText: "PKR 1800",
            ),
            SizedBox(height: ScallingConfig.scale(20)),
          ],
        ),
      ),
    );
  }
}

class ProfileInfoWidget extends StatelessWidget {
  const ProfileInfoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Utils.windowWidth(context),
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppColors.white),
      child: Row(
        children: [
          Container(
            width: Utils.windowWidth(context) * 0.25,
            height: Utils.windowWidth(context) * 0.25,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
            child: Image.asset(ImagePaths.user1, fit: BoxFit.cover),
          ),
          SizedBox(width: ScallingConfig.scale(12)),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CustomText(text: "Emily Jordan", isSemiBold: true),
                    // Spacer(),
                    SizedBox(width: ScallingConfig.scale(50)),
                    CustomText(
                      text: "View Full Details",
                      underline: true,
                      onTap: () {},

                      isSemiBold: true,
                    ),
                  ],
                ),
                SizedBox(height: ScallingConfig.scale(6)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 12, color: Color(0xFF10B981)),
                      const SizedBox(width: 4),
                      Text(
                        "Confirmed",
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: ScallingConfig.scale(10)),
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
                    CustomText(text: "Booking ID: #DR452SA54", fontSize: 12),
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

class DetailsInfoWidget extends StatelessWidget {
  const DetailsInfoWidget({super.key, this.title = '', required this.data});

  final String title;
  final Map<String, String> data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      margin: EdgeInsets.only(top: 12),
      child: SizedBox(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomText(text: title, fontSize: 14, isBold: true),
            ...data.entries.map((item) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CustomText(
                      text: item.key,
                      fontSize: 12,
                      color: AppColors.darkGreyColor,
                    ),
                    CustomText(
                      text: item.value,
                      isBold: true,
                      color: AppColors.darkGreyColor,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class HorizontalText extends StatelessWidget {
  const HorizontalText({
    super.key,
    this.leadingText,
    this.trailingText,
    this.padding,
  });
  final String? leadingText;
  final String? trailingText;
  final EdgeInsets? padding;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CustomText(
                text: leadingText ?? "",
                fontFamily: "Gilroy-Regular",
                fontSize: 14.78,
                fontWeight: FontWeight.bold,
                color: AppColors.primary500,
              ),
              CustomText(
                text: trailingText ?? "",
                fontFamily: "Gilroy-Bold",
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGreyColor,
              ),
            ],
          ),
          SizedBox(height: ScallingConfig.scale(5)),
          Divider(),
        ],
      ),
    );
  }
}

class AmountContainer extends StatelessWidget {
  const AmountContainer({super.key, this.leadingText, this.trailingText});

  final String? leadingText;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Utils.windowWidth(context) * 0.85,
      padding: EdgeInsets.symmetric(
        horizontal: ScallingConfig.scale(20),
        vertical: ScallingConfig.verticalScale(20),
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.lightGrey200),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CustomText(
            text: leadingText ?? "",
            fontFamily: "Gilroy-Medium",
            fontSize: 16,
            // fontWeight: FontWeight.bold,
            color: AppColors.primary500,
          ),
          CustomText(
            text: trailingText ?? "",
            fontFamily: "Gilroy-SemiBold",
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppColors.darkGreyColor,
          ),
        ],
      ),
    );
  }
}

class _WebInfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final Map<String, String> data;

  const _WebInfoCard({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...data.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    e.key,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    e.value,
                    style: const TextStyle(
                      color: Color(0xFF334155),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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
}

class _WebPaymentRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isNegative;

  const _WebPaymentRow({
    required this.label,
    required this.value,
    this.isNegative = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isNegative ? Colors.redAccent : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}
