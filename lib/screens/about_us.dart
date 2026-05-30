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
          text: "About Us",
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
              text: "About iCare",
              color: AppColors.primaryColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            const SizedBox(height: 6),
            CustomText(
              fontFamily: "Gilroy-Regular",
              width: Utils.windowWidth(context) * 0.86,
              text: "Empowering patients and doctors with seamless healthcare technology.",
              color: AppColors.themeDarkGrey,
              fontSize: 13,
            ),
            const SizedBox(height: 24),
            _mobileSection("Our Mission",
                "iCare is on a mission to make quality healthcare accessible to every individual in Pakistan — regardless of location or circumstance. We connect patients with verified, certified doctors through secure online consultations, enable lab test bookings with home sample collection, and provide medicine delivery to your doorstep. Our goal is to eliminate barriers to healthcare and put your health in your hands."),
            _mobileSection("Our Vision",
                "We envision a Pakistan where every person can manage their health digitally — booking a doctor in seconds, tracking vitals from home, accessing prescriptions anytime, and never having to travel just to get a consultation. iCare is building the infrastructure for that future, one patient at a time."),
            _mobileSection("What We Offer",
                "• Online doctor consultations across all specialties\n• Lab test bookings with home sample collection\n• Online pharmacy with doorstep medicine delivery\n• Digital prescriptions and health records\n• Health vitals tracking (blood pressure, sugar, weight, and more)\n• Medical education courses for students and professionals\n• 24/7 emergency support"),
            _mobileSection("Why Choose iCare?",
                "iCare is built by healthcare professionals and technology experts who understand what patients truly need. We verify every doctor on our platform, ensure secure handling of your medical data, and continuously improve our services based on patient feedback. Your health is our priority."),
            _mobileSection("About RM Health Solutions",
                "iCare is a product of RM Health Solutions (Private) Limited, a Pakistan-based health technology company dedicated to transforming the healthcare experience through innovation. We work with doctors, laboratories, and pharmacies across Pakistan to build a connected healthcare ecosystem that works for everyone."),
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
                      const Text("About iCare", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Color(0xFF1E293B), fontFamily: "Gilroy-Bold")),
                      const Text("RM Health Solutions (Private) Limited", style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontFamily: "Gilroy-Regular")),
                    ]),
                  ]),
                  const SizedBox(height: 12),
                  const Text(
                    "Empowering patients and doctors with seamless healthcare technology.",
                    style: TextStyle(fontSize: 16, color: Color(0xFF64748B), fontFamily: "Gilroy-Medium"),
                  ),
                  const SizedBox(height: 32),
                  const Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
                  const SizedBox(height: 32),
                  _buildSection("Our Mission",
                      "iCare is on a mission to make quality healthcare accessible to every individual in Pakistan — regardless of location or circumstance. We connect patients with verified, certified doctors through secure online consultations, enable lab test bookings with home sample collection, and provide medicine delivery to your doorstep. Our goal is to eliminate barriers to healthcare and put your health in your hands."),
                  _buildSection("Our Vision",
                      "We envision a Pakistan where every person can manage their health digitally — booking a doctor in seconds, tracking vitals from home, accessing prescriptions anytime, and never having to travel just to get a consultation. iCare is building the infrastructure for that future, one patient at a time."),
                  _buildSection("What We Offer", null, bullets: const [
                    "Online doctor consultations across all specialties",
                    "Lab test bookings with home sample collection",
                    "Online pharmacy with doorstep medicine delivery",
                    "Digital prescriptions and secure health records",
                    "Health vitals tracking — blood pressure, sugar, weight, oxygen, and more",
                    "Medical education courses for students and professionals",
                    "24/7 emergency support",
                  ]),
                  _buildSection("Why Choose iCare?",
                      "iCare is built by healthcare professionals and technology experts who understand what patients truly need. We verify every doctor on our platform, ensure secure and confidential handling of your medical data, and continuously improve our services based on patient and doctor feedback. Your health is our priority — not just a transaction."),
                  _buildSection("About RM Health Solutions",
                      "iCare is a product of RM Health Solutions (Private) Limited, a Pakistan-based health technology company dedicated to transforming the healthcare experience through innovation. We partner with doctors, laboratories, and pharmacies across Pakistan to build a connected healthcare ecosystem that truly works for patients, providers, and the healthcare system as a whole."),
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
