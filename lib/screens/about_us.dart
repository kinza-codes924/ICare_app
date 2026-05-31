import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';

class AboutUs extends StatelessWidget {
  const AboutUs({super.key});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width > 600) {
      return const _WebAboutUs();
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: CustomBackButton(),
        title: CustomText(
          text: "About Us".tr(),
          fontWeight: FontWeight.bold,
          letterSpacing: -0.31,
          lineHeight: 1.0,
          fontSize: 16.78,
          fontFamily: "Gilroy-Bold",
          color: AppColors.primary500,
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: Utils.windowWidth(context) * 0.07, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomText(
              fontFamily: "Gilroy-Bold",
              width: Utils.windowWidth(context) * 0.86,
              text: "About iCare".tr(),
              color: AppColors.primaryColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            const SizedBox(height: 6),
            CustomText(
              fontFamily: "Gilroy-Regular",
              width: Utils.windowWidth(context) * 0.86,
              text: "Empowering patients and doctors with seamless healthcare technology.".tr(),
              color: AppColors.themeDarkGrey,
              fontSize: 13,
            ),
            const SizedBox(height: 24),
            _mobileSection("Our Mission".tr(),
                "iCare is on a mission to make quality healthcare accessible to every individual in Pakistan.".tr()),
            _mobileSection("Our Vision".tr(),
                "We envision a Pakistan where every person can manage their health digitally.".tr()),
            _mobileSection("What We Offer".tr(),
                "• Online doctor consultations across all specialties\n• Lab test bookings with home sample collection\n• Online pharmacy with doorstep medicine delivery\n• Digital prescriptions and health records\n• Health vitals tracking\n• Medical education courses\n• 24/7 emergency support"),
            _mobileSection("Why Choose iCare?".tr(),
                "iCare is built by healthcare professionals and technology experts who understand what patients truly need. Your health is our priority.".tr()),
            _mobileSection("About RM Health Solutions".tr(),
                "iCare is a product of RM Health Solutions (Private) Limited, a Pakistan-based health technology company.".tr()),
          ],
        ),
      ),
    );
  }

  Widget _mobileSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CustomText(fontFamily: "Gilroy-Bold", text: title, color: const Color(0xFF1E293B), fontSize: 15, fontWeight: FontWeight.bold),
        const SizedBox(height: 8),
        CustomText(fontFamily: "Gilroy-Regular", text: content, color: AppColors.themeDarkGrey, fontSize: 13),
      ]),
    );
  }
}

class _WebAboutUs extends StatelessWidget {
  const _WebAboutUs();

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
          text: "About Us",
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
              constraints: const BoxConstraints(maxWidth: 1200),
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF1F4F9), width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Color(0x0A000000), offset: Offset(0, 4), blurRadius: 20),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(color: AppColors.primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.favorite_rounded, color: AppColors.primaryColor, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("About iCare".tr(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Color(0xFF1E293B), fontFamily: "Gilroy-Bold")),
                      Text("RM Health Solutions (Private) Limited".tr(), style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontFamily: "Gilroy-Regular")),
                    ]),
                  ]),
                  const SizedBox(height: 12),
                  Text(
                    "Empowering patients and doctors with seamless healthcare technology.".tr(),
                    style: const TextStyle(fontSize: 16, color: Color(0xFF64748B), fontFamily: "Gilroy-Medium"),
                  ),
                  const SizedBox(height: 32),
                  const Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
                  const SizedBox(height: 32),
                  _buildSection("Our Mission".tr(),
                      "iCare is on a mission to make quality healthcare accessible to every individual in Pakistan.".tr()),
                  _buildSection("Our Vision".tr(),
                      "We envision a Pakistan where every person can manage their health digitally.".tr()),
                  _buildSection("What We Offer".tr(), null, bullets: [
                    "Online doctor consultations across all specialties".tr(),
                    "Lab test bookings with home sample collection".tr(),
                    "Online pharmacy with doorstep medicine delivery".tr(),
                    "Digital prescriptions and secure health records".tr(),
                    "Health vitals tracking — blood pressure, sugar, weight, oxygen, and more".tr(),
                    "Medical education courses for students and professionals".tr(),
                    "24/7 emergency support".tr(),
                  ]),
                  _buildSection("Why Choose iCare?".tr(),
                      "iCare is built by healthcare professionals and technology experts who understand what patients truly need. Your health is our priority.".tr()),
                  _buildSection("About RM Health Solutions".tr(),
                      "iCare is a product of RM Health Solutions (Private) Limited, a Pakistan-based health technology company.".tr()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String? content, {List<String>? bullets}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1E293B), fontFamily: "Gilroy-Bold")),
        const SizedBox(height: 12),
        if (content != null)
          Text(content, style: const TextStyle(fontSize: 15, color: Color(0xFF64748B), height: 1.7, fontFamily: "Gilroy-Regular")),
        if (bullets != null)
          ...bullets.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(top: 6, right: 10), child: Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981))),
              Expanded(child: Text(b, style: const TextStyle(fontSize: 15, color: Color(0xFF64748B), height: 1.5, fontFamily: "Gilroy-Regular"))),
            ]),
          )),
      ]),
    );
  }
}
