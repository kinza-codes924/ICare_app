import 'package:flutter/material.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/legal_page_back_button.dart';

class RefundPolicy extends StatelessWidget {
  const RefundPolicy({super.key});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width > 600) {
      return const _WebRefundPolicy();
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: LegalPageBackButton(),
        title: CustomText(
          text: "Refund Policy",
          fontSize: 16.78,
          fontFamily: "Gilroy-Bold",
          fontWeight: FontWeight.bold,
          color: AppColors.primary500,
          letterSpacing: -0.31,
          lineHeight: 1.0,
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: Utils.windowWidth(context) * 0.075,
          vertical: 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomText(
              text: "iCare – RM Health Solutions (Private) Limited\nEffective Date: 01/07/2026",
              fontFamily: "Gilroy-Medium",
              fontSize: 12,
              color: AppColors.themeDarkGrey,
            ),
            SizedBox(height: Utils.windowHeight(context) * 0.02),
            ..._sections.map((s) => _MobilePolicySection(title: s[0], body: s[1])),
          ],
        ),
      ),
    );
  }
}

class _MobilePolicySection extends StatelessWidget {
  final String title;
  final String body;
  const _MobilePolicySection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: Utils.windowHeight(context) * 0.025),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText(
            text: title,
            fontFamily: "Gilroy-Bold",
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.primary500,
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.left,
            style: const TextStyle(
              fontFamily: "Gilroy-Regular",
              color: AppColors.themeDarkGrey,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

const List<List<String>> _sections = [
  [
    "REFUND POLICY",
    "Due to the digital nature of services:\n• Telehealth consultations are generally non-refundable once completed.\n• Course purchases may not be refundable once access to materials has been granted.",
  ],
];

class _WebRefundPolicy extends StatelessWidget {
  const _WebRefundPolicy();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: LegalPageBackButton(),
        title: CustomText(
          text: "Refund Policy",
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
                boxShadow: const [BoxShadow(color: Color(0x0A000000), offset: Offset(0, 4), blurRadius: 20)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Refund Policy",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                      fontFamily: "Gilroy-Bold",
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "iCare – RM Health Solutions (Private) Limited\nEffective Date: 01/07/2026",
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF94A3B8),
                      fontFamily: "Gilroy-Medium",
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
                  const SizedBox(height: 32),
                  ..._sections.map((s) => _buildSection(s[0], s[1])),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
              fontFamily: "Gilroy-Bold",
            ),
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF64748B),
              height: 1.6,
              fontFamily: "Gilroy-Regular",
            ),
          ),
        ],
      ),
    );
  }
}
