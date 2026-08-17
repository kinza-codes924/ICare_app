import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:icare/models/clinic.dart';
import 'package:icare/screens/doctors_list.dart';
import 'package:icare/widgets/whatsapp_button.dart';

/// Generic detail page for one iCare specialty clinic. One screen for all
/// clinics (data-driven from Clinic) rather than 6 hardcoded files, so a
/// future clinic is just a new entry in icare_clinics_data.dart.
class ClinicDetailScreen extends StatelessWidget {
  final Clinic clinic;
  const ClinicDetailScreen({super.key, required this.clinic});

  Future<void> _bookAppointment(BuildContext context) {
    // Routes into the existing, already-working doctor -> appointment ->
    // payment flow (DoctorsList -> doctor_detail.dart -> book_appointment.dart
    // -> select_payment_method.dart) rather than a new clinic-specific
    // booking path. DoctorsList already shows "No doctors found" if the
    // filter comes back empty, so this degrades gracefully for specialties
    // that don't have a registered doctor yet.
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DoctorsList(initialSpecialty: clinic.specialtyFilter),
      ),
    );
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
                      const Text(
                        'Our Services',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Gilroy-Bold',
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(width: 48, height: 3, color: clinic.accentColor),
                      const SizedBox(height: 20),
                      GridView.count(
                        crossAxisCount: isMobile ? 1 : 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: isMobile ? 3.4 : 2.6,
                        children: clinic.services
                            .map((s) => _ServiceCard(service: s, accent: clinic.accentColor))
                            .toList(),
                      ),
                      const SizedBox(height: 36),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _bookAppointment(context),
                              icon: const Icon(Icons.calendar_month_rounded, size: 18),
                              label: const Text('Book Appointment'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: clinic.accentColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
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
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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

/// A single service — round tinted icon, name, description. Matches the
/// client's reference screenshots (icare-derma.com service cards).
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
                  service.description,
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
