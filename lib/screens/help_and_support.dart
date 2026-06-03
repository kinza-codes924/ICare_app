import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpAndSupport extends ConsumerWidget {
  const HelpAndSupport({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.read(authProvider).userRole ?? '';
    final isStudent = role == 'Student';
    final isPharmacy = role == 'Pharmacy';
    final isLaboratory = role == 'Laboratory';
    final isDoctor = role == 'Doctor';
    if (MediaQuery.of(context).size.width > 600) {
      return _WebHelpAndSupport(isStudent: isStudent, isPharmacy: isPharmacy, isLaboratory: isLaboratory, isDoctor: isDoctor);
    }

    // REFINED MOBILE LAYOUT
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        leading: const CustomBackButton(),
        backgroundColor: Colors.white,
        elevation: 0,
        title: CustomText(
          text: "Help & Support".tr(),
          fontWeight: FontWeight.bold,
          color: AppColors.primaryColor,
        ),
      ),
      floatingActionButton: _WhatsAppFab(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isStudent ? "Academic Support".tr() : "Support Center".tr(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isStudent
                        ? "Welcome to the iCare Student Support Center. Our faculty and technical teams are here to ensure your learning journey is seamless.".tr()
                        : isPharmacy
                            ? "Welcome to the iCare Pharmacy Support Center. Our team is here to assist with orders, inventory, and platform questions.".tr()
                            : isLaboratory
                                ? "Welcome to the iCare Lab Support Center. Our team is available to assist with test requests, result entry, and platform queries.".tr()
                                : "Welcome to the iCare Support Center. Our team is available 24/7 to help you with any issues or queries.".tr(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildContactTile(
                    Icons.email_outlined,
                    isStudent ? "Academic Support" : "Email Support",
                    isStudent ? "academic@icare.com" : "support@icare.com",
                  ),
                  const SizedBox(height: 12),
                  _buildContactTile(
                    Icons.help_center_outlined,
                    "Technical Desk",
                    "tech-support@icare.com",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              "Frequently Asked Questions".tr(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            // Role-specific FAQs for mobile
            if (isStudent) ..._studentFaqs(),
            if (isPharmacy) ..._pharmacyFaqs(),
            if (isLaboratory) ..._labFaqs(),
            if (isDoctor) ..._doctorFaqs(),
            if (!isStudent && !isPharmacy && !isLaboratory && !isDoctor) ..._defaultFaqs(),
          ],
        ),
      ),
    );
  }

  List<Widget> _studentFaqs() => [
    _WebFaqCard(
      question: "How do I download my certificate?",
      answer: "Certificates are automatically generated upon 100% completion of a program. You can find them in the 'Certificates' tab of your My Learning section.",
    ),
    _WebFaqCard(
      question: "Can I access courses offline?",
      answer: "Currently, our lessons require an active internet connection to stream video and interactive content reliably.",
    ),
    _WebFaqCard(
      question: "How do I take a module quiz?",
      answer: "Once you complete all lessons in a module, the 'Module Quiz' button becomes active at the bottom of the curriculum list.",
    ),
    _WebFaqCard(
      question: "How do I track my course progress?",
      answer: "Your progress is automatically tracked as you complete lessons. Check the 'My Learning' tab or your Student Dashboard to see your progress percentage.",
    ),
  ];

  List<Widget> _pharmacyFaqs() => [
    _WebFaqCard(
      question: "How do I fulfill an incoming prescription?",
      answer: "Go to 'Awaiting Fulfillment' in your sidebar. Open the prescription, verify the medicines, and click 'Mark as Fulfilled' once the order is ready for pickup or dispatch.",
    ),
    _WebFaqCard(
      question: "How do I update my medicine inventory?",
      answer: "Navigate to 'Inventory' in the sidebar. You can add new medicines, update stock quantities, and set minimum stock thresholds to trigger low-stock alerts.",
    ),
    _WebFaqCard(
      question: "Where can I view my revenue and sales data?",
      answer: "Go to 'Revenue & Analytics' in your sidebar to view total revenue, order trends, top-selling medicines, and order breakdown by status.",
    ),
    _WebFaqCard(
      question: "How do I update my pharmacy profile?",
      answer: "Go to Settings and select 'Edit Profile'. You can update your pharmacy name, address, Drug Sale License, and contact details from there.",
    ),
  ];

  List<Widget> _labFaqs() => [
    _WebFaqCard(
      question: "How do I view and accept test requests?",
      answer: "Open 'Test Requests' from your sidebar. You will see all incoming diagnostic requests. Click on a request to review patient details and accept or reject it.",
    ),
    _WebFaqCard(
      question: "How do I enter test results?",
      answer: "Navigate to 'Result Entry' in the sidebar. Find the test request, fill in the result values, and click 'Submit Results'. The patient and requesting doctor are notified automatically.",
    ),
    _WebFaqCard(
      question: "How do I manage my test catalog?",
      answer: "Go to 'Test Catalog' in your sidebar to view, add, or update the diagnostic tests your lab offers, including pricing and turnaround time.",
    ),
    _WebFaqCard(
      question: "Where can I see my lab's revenue and analytics?",
      answer: "Navigate to 'Revenue & Analytics' in your sidebar to track total revenue, completed tests, pending tests, and revenue by test category.",
    ),
  ];

  List<Widget> _doctorFaqs() => [
    _WebFaqCard(
      question: "How do I manage my appointment schedule?",
      answer: "Go to 'My Schedule' in your sidebar to view, accept, or reschedule patient appointments. You can also set your availability and block specific time slots.",
    ),
    _WebFaqCard(
      question: "How do I write and send prescriptions?",
      answer: "During or after a consultation, click 'Write Prescription' in the appointment details. Add medicines, dosage, and instructions, then send it directly to the patient.",
    ),
    _WebFaqCard(
      question: "How do I update my consultation fees?",
      answer: "Navigate to Settings > Professional Settings > Consultation Fees. You can set different fees for in-person, video, and follow-up consultations.",
    ),
    _WebFaqCard(
      question: "Where can I view my earnings and patient analytics?",
      answer: "Go to 'Revenue & Analytics' in your sidebar for consultation revenue summaries, appointment metrics, patient reviews, and activity trends.",
    ),
    _WebFaqCard(
      question: "How do I access patient medical history?",
      answer: "Click on any appointment to view the patient's profile, which includes past consultations, prescriptions, lab reports, and medical conditions.",
    ),
  ];

  List<Widget> _defaultFaqs() => [
    _WebFaqCard(
      question: "How do I book a new appointment?",
      answer: "You can book an appointment by navigating to the 'Appointments' tab and clicking 'New Booking'. Select your preferred doctor and available time slot.",
    ),
    _WebFaqCard(
      question: "How can I access my lab reports?",
      answer: "All your lab results are synced automatically. Navigate to the 'Lab Results' section under Quick Links in your sidebar to view and download past reports.",
    ),
    _WebFaqCard(
      question: "What should I do if my payment fails?",
      answer: "If your invoice payment fails, please ensure your card details are correct or try a different payment method. Visit 'Wallet' to manage billing.",
    ),
  ];

  Widget _buildContactTile(IconData icon, String title, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primaryColor, size: 20),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WEB VIEW
// ═══════════════════════════════════════════════════════════════════════════

class _WebHelpAndSupport extends StatelessWidget {
  final bool isStudent;
  final bool isPharmacy;
  final bool isLaboratory;
  final bool isDoctor;
  const _WebHelpAndSupport({this.isStudent = false, this.isPharmacy = false, this.isLaboratory = false, this.isDoctor = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      floatingActionButton: _WhatsAppFab(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: CustomBackButton(),
        automaticallyImplyLeading: false,
        title: CustomText(
          text: "Help Center",
          fontWeight: FontWeight.bold,
          letterSpacing: -0.31,
          lineHeight: 1.0,
          fontSize: 20,
          fontFamily: "Gilroy-Bold",
          color: AppColors.primaryColor,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          offset: Offset(0, 4),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.support_agent_rounded,
                            size: 32,
                            color: AppColors.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Still need help?",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                            fontFamily: "Gilroy-Bold",
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isStudent
                              ? "Our academic support team is available to help you with courses, certificates, and platform questions."
                              : isPharmacy
                                  ? "Our pharmacy support team is here to assist with orders, inventory, and platform questions."
                                  : isLaboratory
                                      ? "Our lab support team is available to assist with test requests, result entry, and platform queries."
                                      : "Our support team is available 24/7 to help you with any issues or queries.",
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF64748B),
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 32),
                        _WebContactItem(
                          icon: Icons.email_outlined,
                          title: "Email Us",
                          subtitle: isStudent
                              ? "academic@icare.com"
                              : "support@icare.com",
                        ),
                        const SizedBox(height: 20),
                        _WebContactItem(
                          icon: Icons.phone_outlined,
                          title: "Call Us",
                          subtitle: "+923068961564",
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => _InquiryFormDialog.show(context),
                            child: const Text(
                              "Message Support",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 40),
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Frequently Asked Questions",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                          fontFamily: "Gilroy-Bold",
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (isStudent) ...[
                        _WebFaqCard(
                          question: "How do I download my certificate?",
                          answer:
                              "Certificates are automatically generated upon 100% completion of a program. Go to the 'Certificates' tab in your courses section to view and download them.",
                          isExpanded: true,
                        ),
                        _WebFaqCard(
                          question: "Can I access courses offline?",
                          answer:
                              "Currently, lessons require an active internet connection to stream video and interactive content reliably. Offline support is coming soon.",
                        ),
                        _WebFaqCard(
                          question: "How do I take a module quiz?",
                          answer:
                              "Once you complete all lessons in a module, a 'Take Quiz' button will appear at the bottom of the curriculum. You must be enrolled to access quizzes.",
                        ),
                        _WebFaqCard(
                          question: "How do I track my course progress?",
                          answer:
                              "Your progress is automatically tracked as you complete lessons. Check the 'My Learning' tab or your Student Dashboard to see your progress percentage.",
                        ),
                      ] else if (isPharmacy) ...[
                        _WebFaqCard(
                          question: "How do I fulfill an incoming prescription?",
                          answer:
                              "Go to 'Awaiting Fulfillment' in your sidebar. Open the prescription, verify the medicines, and click 'Mark as Fulfilled' once the order is ready for pickup or dispatch.",
                          isExpanded: true,
                        ),
                        _WebFaqCard(
                          question: "How do I update my medicine inventory?",
                          answer:
                              "Navigate to 'Inventory' in the sidebar. You can add new medicines, update stock quantities, and set minimum stock thresholds to trigger low-stock alerts.",
                        ),
                        _WebFaqCard(
                          question: "Where can I view my revenue and sales data?",
                          answer:
                              "Go to 'Revenue & Analytics' in your sidebar to view total revenue, order trends, top-selling medicines, and order breakdown by status.",
                        ),
                        _WebFaqCard(
                          question: "How do I update my pharmacy profile?",
                          answer:
                              "Go to Settings and select 'Edit Profile'. You can update your pharmacy name, address, Drug Sale License, and contact details from there.",
                        ),
                      ] else if (isLaboratory) ...[
                        _WebFaqCard(
                          question: "How do I view and accept test requests?",
                          answer:
                              "Open 'Test Requests' from your sidebar. You will see all incoming diagnostic requests. Click on a request to review patient details and accept or reject it.",
                          isExpanded: true,
                        ),
                        _WebFaqCard(
                          question: "How do I enter test results?",
                          answer:
                              "Navigate to 'Result Entry' in the sidebar. Find the test request, fill in the result values, and click 'Submit Results'. The patient and requesting doctor are notified automatically.",
                        ),
                        _WebFaqCard(
                          question: "How do I manage my test catalog?",
                          answer:
                              "Go to 'Test Catalog' in your sidebar to view, add, or update the diagnostic tests your lab offers, including pricing and turnaround time.",
                        ),
                        _WebFaqCard(
                          question: "Where can I see my lab's revenue and analytics?",
                          answer:
                              "Navigate to 'Revenue & Analytics' in your sidebar to track total revenue, completed tests, pending tests, and revenue by test category.",
                        ),
                      ] else if (isDoctor) ...[
                        _WebFaqCard(
                          question: "How do I manage my appointment schedule?",
                          answer:
                              "Go to 'My Schedule' in your sidebar to view, accept, or reschedule patient appointments. You can also set your availability and block specific time slots.",
                          isExpanded: true,
                        ),
                        _WebFaqCard(
                          question: "How do I write and send prescriptions?",
                          answer:
                              "During or after a consultation, click 'Write Prescription' in the appointment details. Add medicines, dosage, and instructions, then send it directly to the patient.",
                        ),
                        _WebFaqCard(
                          question: "How do I update my consultation fees?",
                          answer:
                              "Navigate to Settings > Professional Settings > Consultation Fees. You can set different fees for in-person, video, and follow-up consultations.",
                        ),
                        _WebFaqCard(
                          question: "Where can I view my earnings and patient analytics?",
                          answer:
                              "Go to 'Revenue & Analytics' in your sidebar for consultation revenue summaries, appointment metrics, patient reviews, and activity trends.",
                        ),
                        _WebFaqCard(
                          question: "How do I access patient medical history?",
                          answer:
                              "Click on any appointment to view the patient's profile, which includes past consultations, prescriptions, lab reports, and medical conditions.",
                        ),
                      ] else ...[
                        _WebFaqCard(
                          question: "How do I book a new appointment?",
                          answer:
                              "You can book an appointment by navigating to the 'Appointments' tab and clicking 'New Booking'. Select your preferred doctor and available time slot.",
                          isExpanded: true,
                        ),
                        _WebFaqCard(
                          question: "How can I access my lab reports?",
                          answer:
                              "All your lab results are synced automatically. Navigate to the 'Lab Results' section under Quick Links in your sidebar to view and download past reports.",
                        ),
                        _WebFaqCard(
                          question: "What should I do if my payment fails?",
                          answer:
                              "If your invoice payment fails, please ensure your card details are correct or try a different payment method. Visit 'Wallet' to manage billing.",
                        ),
                        _WebFaqCard(
                          question: "Can I cancel or reschedule my task?",
                          answer:
                              "Yes, tasks can be managed directly from the 'My Tasks' dashboard. Click the three dots icon next to a task to edit or cancel it.",
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WebContactItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _WebContactItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Icon(icon, color: const Color(0xFF475569), size: 20),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WebFaqCard extends StatefulWidget {
  final String question;
  final String answer;
  final bool isExpanded;

  const _WebFaqCard({
    required this.question,
    required this.answer,
    this.isExpanded = false,
  });

  @override
  State<_WebFaqCard> createState() => _WebFaqCardState();
}

class _WebFaqCardState extends State<_WebFaqCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.isExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _expanded
              ? AppColors.primaryColor.withValues(alpha: 0.3)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _expanded,
          onExpansionChanged: (val) => setState(() => _expanded = val),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          title: Text(
            widget.question,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _expanded
                  ? AppColors.primaryColor
                  : const Color(0xFF1E293B),
              fontFamily: "Gilroy-SemiBold",
            ),
          ),
          iconColor: AppColors.primaryColor,
          collapsedIconColor: const Color(0xFF64748B),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              child: Text(
                widget.answer,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF64748B),
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhatsAppFab extends StatelessWidget {
  const _WhatsAppFab();

  Future<void> _open(BuildContext context) async {
    final uri = Uri.parse(
      'https://wa.me/923068961564?text=${Uri.encodeComponent("Hello! I need help with iCare.")}',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF25D366), Color(0xFF128C7E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF25D366).withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 6),
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: SvgPicture.string(
            '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="white">
              <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/>
            </svg>''',
            width: 32,
            height: 32,
          ),
        ),
      ),
    );
  }
}

class _WhatsAppSupportButton extends StatelessWidget {
  const _WhatsAppSupportButton();

  Future<void> _openWhatsApp(BuildContext context) async {
    final uri = Uri.parse(
      'https://wa.me/923068961564?text=${Uri.encodeComponent("Hello! I need help with iCare.")}',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to open WhatsApp.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF25D366),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        onPressed: () => _openWhatsApp(context),
        icon: const Icon(Icons.chat_rounded, size: 20),
        label: const Text(
          'WhatsApp Support',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// INQUIRY FORM — submits a support message
// ═══════════════════════════════════════════════════════════════════════════

class _InquiryFormDialog extends ConsumerStatefulWidget {
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => const _InquiryFormDialog(),
    );
  }

  const _InquiryFormDialog();

  @override
  ConsumerState<_InquiryFormDialog> createState() => _InquiryFormDialogState();
}

class _InquiryFormDialogState extends ConsumerState<_InquiryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _category = 'General';
  bool _submitting = false;

  static const _categories = ['General', 'Technical Issue', 'Billing', 'Account', 'Feedback'];

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user != null) {
      _nameCtrl.text = user.name ?? '';
      _emailCtrl.text = user.email ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final user = ref.read(authProvider).user;
    final role = ref.read(authProvider).userRole ?? 'User';
    final userId = user?.id ?? '';
    final userName = _nameCtrl.text.trim();
    final userEmail = _emailCtrl.text.trim();
    final subject = _subjectCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    final category = _category;

    final body = '''
Category: $category
Subject: $subject

Account Details:
  Name: $userName
  Email: $userEmail
  Account Type: $role
  User ID: ${userId.isNotEmpty ? userId : 'N/A'}

Message:
$message
''';

    final mailUri = Uri(
      scheme: 'mailto',
      path: 'icareofficialapp@gmail.com',
      queryParameters: {
        'subject': '[$category] $subject',
        'body': body,
      },
    );

    try {
      if (await canLaunchUrl(mailUri)) {
        await launchUrl(mailUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Your email client has been opened. Please send the message to complete your inquiry."),
      backgroundColor: Color(0xFF10B981),
      duration: Duration(seconds: 5),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.support_agent_rounded, color: AppColors.primaryColor),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Contact Support', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                      SizedBox(height: 2),
                      Text("We'll respond within 24 hours.", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ]),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ]),
                const SizedBox(height: 18),
                _label('Your Name'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: _deco('Enter your full name', Icons.person_outline_rounded),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 14),
                _label('Email Address'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _deco('you@example.com', Icons.email_outlined),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    if (!RegExp(r'^[\w.\-]+@[\w.\-]+\.\w+$').hasMatch(v.trim())) return 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _label('Category'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: _deco(null, Icons.category_outlined),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _category = v ?? 'General'),
                ),
                const SizedBox(height: 14),
                _label('Subject'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _subjectCtrl,
                  decoration: _deco('Brief summary of your inquiry', Icons.subject_rounded),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Subject is required' : null,
                ),
                const SizedBox(height: 14),
                _label('Message'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _messageCtrl,
                  maxLines: 5,
                  decoration: _deco('Describe your issue or question in detail...', null).copyWith(
                    alignLabelWithHint: true,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Message is required';
                    if (v.trim().length < 10) return 'Message should be at least 10 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 22),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(_submitting ? 'Submitting...' : 'Submit Inquiry', style: const TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155), letterSpacing: 0.3));

  InputDecoration _deco(String? hint, IconData? icon) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
        prefixIcon: icon != null ? Icon(icon, size: 18, color: const Color(0xFF94A3B8)) : null,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.primaryColor, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFEF4444))),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
      );
}