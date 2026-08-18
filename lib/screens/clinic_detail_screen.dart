import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:icare/models/clinic.dart';
import 'package:icare/models/doctor.dart';
import 'package:icare/screens/doctor_detail.dart';
import 'package:icare/screens/doctors_list.dart';
import 'package:icare/screens/clinic_detail_sections.dart';
import 'package:icare/services/doctor_service.dart';
import 'package:icare/widgets/whatsapp_button.dart';

/// Generic detail page for one iCare specialty clinic. One screen for all
/// clinics (data-driven from Clinic) rather than 6 hardcoded files, so a
/// future clinic is just a new entry in icare_clinics_data.dart.
class ClinicDetailScreen extends StatelessWidget {
  final Clinic clinic;
  const ClinicDetailScreen({super.key, required this.clinic});

  Future<void> _bookAppointment(BuildContext context) async {
    // When the clinic has a designated department account, book straight
    // into that doctor's profile — the patient sees the clinic's branded
    // name (e.g. "iCare Derma & Skin Care"), not an individual doctor,
    // since that account's User.name IS the clinic name. Falls back to a
    // specialty search if doctorId isn't set yet or the fetch fails, so
    // this never dead-ends.
    if (clinic.doctorId != null) {
      final result = await DoctorService().getDoctorById(clinic.doctorId!);
      if (result['success'] == true && result['doctor'] != null) {
        final doctor = Doctor.fromJson(result['doctor']);
        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => DoctorDetailScreen(doctor: doctor)),
          );
        }
        return;
      }
    }
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DoctorsList(initialSpecialty: clinic.specialtyFilter),
        ),
      );
    }
  }

  Future<void> _enquireOnWhatsApp(BuildContext context) async {
    final message = 'Hello! I would like to inquire about ${clinic.name}.';
    final uri = Uri.parse(
      'https://wa.me/${WhatsAppFloatingButton.phoneNumber}?text=${Uri.encodeComponent(message)}',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_blank',
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 700;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _Header(clinic: clinic, isMobile: isMobile),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 40, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clinic.description,
                        style: const TextStyle(fontSize: 15, color: Color(0xFF475569), height: 1.6),
                      ),
                      const SizedBox(height: 36),
                      _SectionTitle(title: 'Your Care Journey', accent: clinic.accentColor),
                      const SizedBox(height: 20),
                      JourneyTimeline(steps: clinic.journey, accent: clinic.accentColor, isMobile: isMobile),
                      const SizedBox(height: 36),
                      _SectionTitle(title: 'Our Services', accent: clinic.accentColor),
                      const SizedBox(height: 20),
                      // Wrap, not GridView.count — a fixed childAspectRatio
                      // stretched every card to a set height regardless of
                      // its actual (usually 2-line) description, leaving
                      // large empty space under short entries.
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = isMobile ? 1 : 2;
                          const spacing = 16.0;
                          final cardWidth =
                              (constraints.maxWidth - spacing * (columns - 1)) / columns;
                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: clinic.services
                                .map((s) => SizedBox(
                                      width: cardWidth,
                                      child: _ServiceCard(service: s, accent: clinic.accentColor),
                                    ))
                                .toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 36),
                      _TrustStrip(accent: clinic.accentColor),
                      const SizedBox(height: 36),
                      _SectionTitle(title: 'Patient Testimonials', accent: clinic.accentColor),
                      const SizedBox(height: 20),
                      TestimonialsSection(testimonials: clinic.testimonials),
                      const SizedBox(height: 36),
                      _SectionTitle(title: 'Visit Our Clinic', accent: clinic.accentColor),
                      const SizedBox(height: 20),
                      VisitClinicSection(clinic: clinic),
                      const SizedBox(height: 36),
                      _SectionTitle(title: 'Frequently Asked Questions', accent: clinic.accentColor),
                      const SizedBox(height: 20),
                      FaqAccordion(faqs: clinic.faqs, accent: clinic.accentColor),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _enquireOnWhatsApp(context),
                              icon: const Icon(Icons.chat_rounded, size: 18, color: Color(0xFF25D366)),
                              label: const Text('Enquire on WhatsApp'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF128C7E),
                                side: const BorderSide(color: Color(0xFF25D366), width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Extra bottom padding so content doesn't sit flush
                      // under the sticky Book Appointment bar.
                      const SizedBox(height: 90),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -4)),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: () => _bookAppointment(context),
            icon: const Icon(Icons.calendar_month_rounded, size: 18),
            label: const Text('Book Appointment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: clinic.accentColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color accent;
  const _SectionTitle({required this.title, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontFamily: 'Gilroy-Bold',
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Container(width: 48, height: 3, color: accent),
      ],
    );
  }
}

/// Teal banner header — icon, clinic name, tagline, location. Matches the
/// client's reference clinic-site screenshots (icare-derma.com style hero).
class _Header extends StatelessWidget {
  final Clinic clinic;
  final bool isMobile;
  const _Header({required this.clinic, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [clinic.accentColor, clinic.accentColor.withValues(alpha: 0.82)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(isMobile ? 16 : 40, 12, isMobile ? 16 : 40, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                    ),
                    child: Icon(clinic.icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          clinic.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Gilroy-Bold',
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          clinic.tagline,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.location_on_rounded, size: 16, color: Colors.white.withValues(alpha: 0.85)),
                  const SizedBox(width: 4),
                  Text(
                    'Presently Available Only ${clinic.location}',
                    style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single service — round tinted icon, name, expanded procedure detail.
class _ServiceCard extends StatelessWidget {
  final ClinicService service;
  final Color accent;
  const _ServiceCard({required this.service, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_rounded, color: accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 3),
                Text(
                  service.longDescription,
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small trust-badges strip shown under the services grid. Purely to give
/// the page a finished feel below an odd-numbered services grid — not tied
/// to any one clinic's content.
class _TrustStrip extends StatelessWidget {
  final Color accent;
  const _TrustStrip({required this.accent});

  static const _items = [
    (Icons.verified_user_rounded, 'Verified Doctors'),
    (Icons.calendar_month_rounded, 'Easy Online Booking'),
    (Icons.chat_rounded, 'WhatsApp Support'),
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = isMobile ? 1 : 3;
        const spacing = 14.0;
        final cardWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: _items
              .map((item) => SizedBox(
                    width: cardWidth,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(item.$1, color: accent, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item.$2,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}
