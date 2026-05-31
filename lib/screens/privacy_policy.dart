import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';

class PrivacyPolicy extends StatelessWidget {
  const PrivacyPolicy({super.key});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width > 600) {
      return const _WebPrivacyPolicy();
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: CustomBackButton(),
        title: CustomText(
          text: "Privacy Policy".tr(),
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
              text: "iCare – RM Health Solutions (Private) Limited\nEffective Date: 11/05/2026",
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
  ["ABOUT THIS POLICY",
    "RM Health Solutions (Private) Limited, operating under the brand name \"iCare,\" respects and values the privacy and confidentiality of every user who accesses or uses our website, mobile applications, telemedicine systems, healthcare services, pharmacy integrations, laboratory services, AI-enabled tools, communication systems, and related digital healthcare solutions.\n\nThis Privacy Policy explains how we collect, process, use, store, disclose, and protect your personal, medical, technical, and financial information while you use our Platform.\n\nBy accessing, registering with, or using iCare services, you acknowledge that you have read, understood, and agreed to the practices described in this Privacy Policy and consent to the collection and processing of your information in accordance with applicable laws and healthcare standards.\n\nEffective Date: 11/05/2026"],
  ["INFORMATION WE COLLECT",
    "iCare may collect various categories of information including:\n\nPersonal Identification: full name, CNIC or passport details, date of birth, gender, contact information, address, and profile details.\n\nMedical & Healthcare: consultation records, medical history, prescriptions, laboratory reports, uploaded medical documents, mental health information, treatment details, audio or video consultation recordings, diagnostic information, and communication between patients and healthcare professionals.\n\nTechnical: IP addresses, browser type, device identifiers, operating system details, login history, app usage activity, crash reports, communication metadata, and related technical data.\n\nPayment: transaction details, payment confirmations, billing records, and financial references. Sensitive payment credentials are generally processed through secure third-party payment processors and are not intentionally stored directly by iCare unless required for legal, operational, or regulatory purposes."],
  ["HOW WE COLLECT INFORMATION",
    "Information may be collected directly from users during registration, appointment booking, consultations, customer support interactions, uploads of medical records, pharmacy orders, laboratory requests, account verification processes, and communications with doctors or support teams.\n\nCertain information may also be collected automatically through cookies, analytics technologies, device identifiers, and other technical tracking mechanisms used to improve the security, functionality, and performance of the Platform."],
  ["PURPOSE OF DATA COLLECTION",
    "The information collected by iCare is used to:\n• Provide and improve healthcare services;\n• Facilitate telemedicine consultations;\n• Manage appointments and generate electronic prescriptions;\n• Verify user identities and maintain medical records;\n• Process payments and coordinate pharmacy and laboratory services;\n• Provide customer support and ensure regulatory compliance;\n• Detect fraud and maintain system security;\n• Improve platform functionality and user experience;\n• Conduct research and analytics;\n• Support AI-enabled operational systems.\n\nAggregated or anonymized information may also be used for analytics, healthcare innovation, AI training, research, operational improvements, and business intelligence purposes."],
  ["TELEMEDICINE & RECORDING CONSENT",
    "By using the Platform, users expressly consent to telemedicine services and electronic healthcare delivery methods. Users acknowledge that consultations may occur through video calls, audio calls, messaging systems, asynchronous communication methods, or other electronic communication channels.\n\nUsers further understand and agree that telemedicine has certain limitations compared to physical consultations and may involve risks related to technology failures, connectivity disruptions, communication limitations, and delays in diagnosis or treatment.\n\nUsers consent to the recording, storage, and review of consultations for purposes including medical documentation, quality assurance, legal compliance, operational monitoring, training, dispute resolution, and security."],
  ["AI & AUTOMATED SYSTEMS",
    "The Platform may utilize AI-enabled technologies and automated systems for functions such as appointment routing, chat assistance, symptom triage support, operational automation, and administrative services.\n\nThese AI-enabled systems are intended solely to support operational efficiency and do not replace licensed medical professionals, clinical judgment, or medical decision-making. Users acknowledge that they must not rely solely on AI-generated information or automated responses for medical decisions or healthcare treatment."],
  ["DATA SHARING & DISCLOSURE",
    "iCare may share information with licensed healthcare professionals, pharmacies, laboratories, payment processors, technology service providers, regulatory authorities, legal advisors, business partners, and governmental authorities where required by law, regulation, court order, or lawful investigation.\n\nThird-party pharmacies and laboratories remain independently responsible for medicine quality, laboratory accuracy, delivery operations, and regulatory compliance related to their own services. iCare acts primarily as a technology-enabled healthcare facilitation platform and shall not be held liable for independent actions, omissions, negligence, delays, or failures of third-party providers.\n\nWe do not sell personal medical information to unauthorized third parties."],
  ["INTERNATIONAL COMPLIANCE",
    "iCare aims to comply with applicable legal and regulatory standards including principles under the Prevention of Electronic Crimes Act (PECA) of Pakistan, applicable data protection standards, HIPAA compliance principles, GDPR-style privacy principles, UK GDPR concepts, consumer protection obligations, telemedicine compliance requirements, electronic consent standards, and internationally recognized healthcare confidentiality principles where applicable.\n\nUsers acknowledge that laws and regulations may vary across jurisdictions and that complete global compliance cannot always be guaranteed in every region."],
  ["DATA RETENTION",
    "Medical records, consultation recordings, operational data, and related healthcare information may be retained permanently unless deletion is requested by the user and such deletion is legally permissible.\n\nCertain records may continue to be retained for legal compliance, audit requirements, fraud prevention, regulatory obligations, dispute resolution, continuity of care, cybersecurity investigations, or operational purposes even after account closure or deletion requests."],
  ["DATA SECURITY",
    "iCare implements reasonable technical, organizational, and administrative safeguards intended to protect personal and medical information from unauthorized access, disclosure, misuse, loss, or alteration. These safeguards may include encryption systems, secure servers, restricted access controls, authentication mechanisms, monitoring systems, cybersecurity protocols, and operational security procedures.\n\nDespite these efforts, users acknowledge that no internet-based platform, software system, cloud infrastructure, or electronic communication method can guarantee absolute security, uninterrupted operation, or complete protection against cyberattacks, hacking, unauthorized access, technical failures, or data breaches."],
  ["USER RIGHTS",
    "Users may request correction of inaccurate information, deletion of accounts, withdrawal of certain consents, or restriction of specific processing activities subject to applicable legal and regulatory limitations.\n\nCertain requests may be denied or restricted where retention of information is required for medical, legal, regulatory, contractual, fraud prevention, operational, or security reasons."],
  ["COOKIES & TRACKING TECHNOLOGIES",
    "The Platform may use cookies, session tracking technologies, analytics tools, and similar technical systems to improve user experience, enhance functionality, monitor performance, maintain security, and optimize healthcare services.\n\nUsers may control certain tracking preferences through browser or device settings, although disabling certain technologies may affect functionality of the Platform."],
  ["THIRD-PARTY SERVICES",
    "The Platform may integrate with third-party systems, cloud providers, communication services, payment gateways, laboratories, pharmacies, authentication systems, and other external technologies. iCare does not control and is not responsible for the independent privacy, operational, or security practices of third-party providers."],
  ["CHILDREN'S PRIVACY",
    "The Platform is intended only for individuals aged 18 years or older. iCare does not knowingly collect personal information from minors without lawful authorization or parental consent where legally required."],
  ["COMMUNITY FEATURES",
    "Users who post reviews, ratings, comments, feedback, or community content acknowledge that such content may become publicly visible to other users. iCare reserves the right to monitor, moderate, remove, restrict, or investigate any content that violates laws, regulations, ethical standards, Platform policies, or community guidelines."],
  ["INTELLECTUAL PROPERTY & DATA USE",
    "Users retain ownership of their personal medical information. By using the Platform, users grant iCare a limited, non-exclusive, worldwide, royalty-free license to process, store, analyze, and use anonymized or aggregated data for operational purposes, analytics, healthcare research, AI training, service improvement, and business intelligence activities in accordance with applicable laws."],
  ["DATA BREACH RESPONSE",
    "In the event of cybersecurity incidents, unauthorized access, data breaches, or security compromises, iCare may investigate the incident, implement mitigation measures, engage technical experts, cooperate with authorities, and notify affected users where legally required or operationally appropriate."],
  ["LIMITATION OF LIABILITY",
    "To the maximum extent permitted by law, iCare shall not be liable for cyberattacks, unauthorized access, technical failures, service interruptions, third-party breaches, internet outages, data interception, user negligence, loss of information, indirect damages, or consequences arising from the use of electronic healthcare systems or third-party technologies."],
  ["POLICY CHANGES",
    "iCare reserves the right to update, modify, revise, or replace this Privacy Policy at any time without prior notice. Updated versions become effective immediately upon publication on the Platform. Continued access to or use of the Platform after updates constitutes acceptance of the revised Privacy Policy."],
  ["USER ACKNOWLEDGMENT",
    "By using iCare services, users acknowledge that they have read and understood this Privacy Policy and voluntarily consent to the collection, storage, processing, sharing, and use of their information as described herein.\n\nOfficial contact details, registered office address, support information, and legal communication channels are available on the official website."],
];

class _WebPrivacyPolicy extends StatelessWidget {
  const _WebPrivacyPolicy();

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
          text: "Privacy Policy".tr(),
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
                    "Privacy Policy",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                      fontFamily: "Gilroy-Bold",
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "iCare – RM Health Solutions (Private) Limited\nEffective Date: 11/05/2026",
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
