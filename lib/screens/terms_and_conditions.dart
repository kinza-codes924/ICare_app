import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';

class TermsAndConditions extends StatelessWidget {
  const TermsAndConditions({super.key});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width > 600) {
      return const _WebTermsAndConditions();
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: CustomBackButton(),
        title: CustomText(
          text: "Terms & Conditions".tr(),
          fontWeight: FontWeight.bold,
          letterSpacing: -0.31,
          lineHeight: 1.0,
          fontSize: 16.78,
          fontFamily: "Gilroy-Bold",
          color: AppColors.primary500,
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
              text: "iCare – RM Health Solutions (Private) Limited\nEffective Date: 11/05/2026\n\nBy accessing, registering with, or using the Platform, you acknowledge that you have read, understood, and agreed to be legally bound by these Terms & Conditions.",
              fontFamily: "Gilroy-Medium",
              fontSize: 12,
              color: AppColors.themeDarkGrey,
            ),
            SizedBox(height: Utils.windowHeight(context) * 0.02),
            ..._sections.map((s) => _MobileTermsSection(title: s[0], body: s[1])),
          ],
        ),
      ),
    );
  }
}

class _MobileTermsSection extends StatelessWidget {
  final String title;
  final String body;
  const _MobileTermsSection({required this.title, required this.body});

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
            style: TextStyle(
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
  ["ABOUT THE PLATFORM",
    "Welcome to iCare, a digital healthcare and telemedicine platform operated by RM Health Solutions (Private) Limited (\"iCare,\" \"Company,\" \"we,\" \"our,\" or \"us\"). These Terms & Conditions govern your access to and use of the iCare website, mobile applications, telemedicine services, software systems, pharmacy integrations, laboratory services, communication platforms, AI-enabled tools, community features, and all related digital healthcare services (collectively referred to as the \"Platform\").\n\nBy accessing, registering with, or using the Platform, you acknowledge that you have read, understood, and agreed to be legally bound by these Terms & Conditions. Electronic acceptance of these Terms constitutes legally binding consent equivalent to a physical signature under applicable electronic transaction and telecommunication laws."],
  ["ELIGIBILITY & USER REPRESENTATIONS",
    "The Platform is intended solely for individuals who are at least eighteen (18) years of age and legally capable of entering into binding agreements. By using the Platform, you represent and warrant that all information provided by you is accurate, complete, current, and lawful.\n\niCare reserves the right to suspend, restrict, or terminate access where false, misleading, fraudulent, or incomplete information is provided."],
  ["NATURE OF THE PLATFORM",
    "iCare operates as a technology-enabled healthcare facilitation platform that connects users with licensed healthcare professionals, pharmacies, laboratories, clinics, and related healthcare service providers. Except where expressly stated otherwise, iCare does not directly provide medical diagnosis, medical treatment, emergency healthcare services, or clinical decision-making.\n\nThe Platform facilitates telemedicine consultations, appointment scheduling, electronic prescriptions, medical record management, healthcare communication, pharmacy coordination, laboratory integrations, AI-assisted operational services, mental health consultations, community interactions, and related healthcare support services.\n\nThe Platform and services are provided on an \"as is\" and \"as available\" basis without warranties of any kind. iCare does not guarantee uninterrupted availability, error-free operation, successful consultation outcomes, or uninterrupted access to healthcare professionals or third-party providers."],
  ["EMERGENCY SERVICES DISCLAIMER",
    "The Platform is not intended for medical emergencies, critical care situations, or life-threatening conditions. Users experiencing medical emergencies must immediately contact emergency services, visit the nearest hospital, or seek in-person medical attention. The Platform does not replace emergency medical services, physical examinations, or independent clinical judgment by qualified healthcare professionals."],
  ["TELEMEDICINE CONSENT",
    "By using the Platform, users expressly consent to telemedicine and electronic healthcare services. Users understand and acknowledge that telemedicine services may involve inherent limitations and risks including technical failures, internet disruptions, connectivity issues, communication delays, limitations in physical examination, reduced diagnostic certainty, data transmission failures, or interruptions beyond the control of iCare.\n\nConsultations may occur through video calls, audio calls, chat systems, asynchronous communication, or other electronic methods. Users further consent to the recording, storage, monitoring, and review of consultations for medical documentation, legal compliance, operational quality assurance, security monitoring, training, dispute resolution, and healthcare continuity purposes."],
  ["DOCTOR RELATIONSHIP DISCLAIMER",
    "Use of the Platform does not guarantee the establishment of an ongoing or continuing doctor-patient relationship beyond the specific consultation session unless expressly agreed between the patient and the healthcare professional independently.\n\nHealthcare professionals using the Platform may operate either as employees or independent contractors. Medical practitioners remain solely and independently responsible for clinical judgment, diagnoses, prescriptions, treatment decisions, medical advice, patient management, and compliance with applicable healthcare laws and licensing obligations.\n\niCare shall not be liable for medical negligence, malpractice, incorrect diagnosis, delayed diagnosis, prescription complications, treatment outcomes, professional misconduct, or independent actions or omissions of healthcare professionals."],
  ["AI & TECHNOLOGY DISCLAIMER",
    "The Platform may use AI-enabled technologies, automated systems, or digital assistance tools for functions including appointment routing, operational automation, symptom triage support, communication assistance, and administrative services.\n\nSuch AI-enabled systems are intended solely for operational support and do not replace licensed medical professionals, professional healthcare advice, independent medical judgment, or emergency medical services. Users must not rely solely upon AI-generated responses or automated systems for medical decisions or treatment purposes."],
  ["USER ACCOUNTS & RESPONSIBILITIES",
    "Users may create accounts using mobile verification systems, social logins, email registration, or other authentication methods approved by iCare. Users are solely responsible for maintaining the confidentiality and security of their accounts, passwords, devices, authentication credentials, and login information.\n\nUsers agree not to share accounts, impersonate others, provide misleading information, misuse healthcare services, abuse healthcare professionals, engage in unlawful conduct, upload harmful or malicious material, interfere with Platform operations, or attempt unauthorized access to systems or data.\n\nUsers are solely responsible for providing accurate, complete, updated, and truthful medical and personal information. iCare shall not be liable for consequences arising from false, incomplete, inaccurate, outdated, or misleading information submitted by users."],
  ["DATA, RECORDS & AUTHORIZATION",
    "Users authorize iCare to collect, process, store, maintain, and manage personal information, medical records, consultation histories, prescriptions, uploaded documents, audio or video consultation recordings, technical information, communication records, and related healthcare data in accordance with applicable laws and the Privacy Policy.\n\nMedical records may be retained permanently unless deletion is requested and legally permissible. Users retain ownership of their personal medical records; however, by using the Platform, users grant iCare a limited, non-exclusive, worldwide, royalty-free license to process, store, analyze, use, and manage anonymized or aggregated data for operational purposes, analytics, healthcare research, AI training, and business intelligence in accordance with applicable laws."],
  ["THIRD-PARTY SERVICES",
    "The Platform may integrate pharmacies, laboratories, clinics, payment processors, cloud infrastructure providers, communication systems, and other third-party service providers. Third-party pharmacies and laboratories remain independently responsible for medicine quality, laboratory accuracy, product authenticity, regulatory compliance, delivery operations, and healthcare services independently provided by them.\n\niCare acts primarily as a facilitating technology platform and shall not be liable for delays, defects, delivery failures, medication reactions, laboratory inaccuracies, independent negligence, service interruptions, or third-party operational failures."],
  ["ELECTRONIC PRESCRIPTIONS",
    "Electronic prescriptions may be issued through digitally signed systems by authorized healthcare professionals. Prescriptions issued through telemedicine services may be subject to legal, clinical, geographic, jurisdictional, pharmacy, or regulatory limitations and may not be accepted in all locations or by all pharmacies.\n\nUsers acknowledge that narcotic medications may be restricted or prohibited through telemedicine services depending upon applicable laws and professional regulations."],
  ["PAYMENTS & REFUNDS",
    "Payments for consultations, subscriptions, healthcare services, pharmacy services, or related Platform services may be processed through banks, payment gateways, EasyPaisa, JazzCash, credit cards, debit cards, digital wallets, or authorized third-party payment providers.\n\nConsultation fees become non-refundable once consultations commence or where patients fail to attend scheduled appointments. Where healthcare professionals fail to attend scheduled consultations, iCare may arrange rescheduling, assign alternative healthcare professionals, or provide refunds at its discretion.\n\nInternet disruptions, technical failures, connectivity problems, software interruptions, or third-party outages may result in delays or rescheduling without liability to iCare."],
  ["USER-GENERATED CONTENT",
    "Users may post reviews, ratings, comments, feedback, community discussions, or other user-generated content through the Platform. Users agree not to post defamatory, abusive, misleading, unlawful, fraudulent, offensive, medically inaccurate, threatening, discriminatory, harmful, or inappropriate content.\n\niCare reserves the right to monitor, moderate, restrict, investigate, suspend, or remove content that violates laws, regulations, ethical standards, professional obligations, community guidelines, or Platform policies."],
  ["INTELLECTUAL PROPERTY",
    "All Platform software, systems, branding, logos, trademarks, interfaces, designs, content, technology, databases, source code, graphics, operational systems, and intellectual property rights are owned by or licensed to RM Health Solutions (Private) Limited.\n\nUnauthorized copying, reproduction, reverse engineering, redistribution, commercial exploitation, modification, or misuse of Platform materials is strictly prohibited."],
  ["JURISDICTION & SERVICE AVAILABILITY",
    "Availability of healthcare services may vary depending upon jurisdiction, regulatory limitations, healthcare licensing requirements, technological availability, and operational restrictions. Users are solely responsible for ensuring that use of telemedicine services is lawful within their applicable jurisdiction."],
  ["LIMITATION OF LIABILITY",
    "To the fullest extent permitted by law, iCare shall not be liable for indirect damages, medical complications, treatment failures, service interruptions, technical failures, cyberattacks, unauthorized access, data breaches, internet outages, third-party misconduct, prescription misuse, financial losses, loss of data, reputational harm, operational delays, healthcare outcomes, or consequences arising from use of the Platform or reliance upon information obtained through the Platform.\n\nTotal liability of iCare, if any, shall not exceed the amount paid by the user for the relevant service giving rise to the claim."],
  ["FORCE MAJEURE",
    "iCare shall not be responsible for delays, interruptions, failures, or inability to perform obligations caused by events beyond reasonable control including natural disasters, pandemics, cyberattacks, internet failures, governmental actions, regulatory changes, war, labor disputes, electricity failures, software failures, cloud infrastructure outages, telecommunications disruptions, or force majeure events."],
  ["TERMINATION",
    "iCare reserves the right to suspend, restrict, terminate, investigate, or permanently remove access to the Platform at any time without prior notice for legal, operational, security, regulatory, ethical, or policy-related reasons."],
  ["DISPUTE RESOLUTION & GOVERNING LAW",
    "Any dispute, controversy, or claim arising from or relating to these Terms, the Platform, or use of services shall first be resolved through arbitration conducted in Karachi, Pakistan. If arbitration fails or is unenforceable, disputes shall fall under the exclusive jurisdiction of competent courts of Karachi, Pakistan.\n\nThese Terms shall be governed in accordance with the laws of Pakistan together with applicable international telehealth compliance principles where relevant."],
  ["MODIFICATIONS",
    "iCare reserves the right to update, revise, modify, or replace these Terms & Conditions at any time without prior notice. Updated versions become effective immediately upon publication on the Platform. Continued use of the Platform after modifications constitutes acceptance of revised Terms."],
  ["USER ACKNOWLEDGMENT",
    "By using the Platform, users acknowledge that they have carefully read, understood, and voluntarily agreed to these Terms & Conditions, understand the limitations of telemedicine services, consent to electronic healthcare delivery systems, and accept all associated operational, technical, legal, and medical risks.\n\nOfficial registered office address, legal contact details, support information, and communication channels are available on the official website."],
];

class _WebTermsAndConditions extends StatelessWidget {
  const _WebTermsAndConditions();

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
          text: "Terms & Conditions".tr(),
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
                    "Terms & Conditions",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                      fontFamily: "Gilroy-Bold",
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "iCare – RM Health Solutions (Private) Limited\n\nBy accessing or using the Platform, you acknowledge that you have read, understood, and agreed to be legally bound by these Terms.",
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF64748B),
                      fontFamily: "Gilroy-Medium",
                      height: 1.6,
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
