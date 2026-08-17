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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: clinic.accentColor,
            iconTheme: const IconThemeData(color: Colors.white),
            expandedHeight: 160,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16, right: 16),
              title: Text(
                clinic.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Gilroy-Bold',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [clinic.accentColor, clinic.accentColor.withValues(alpha: 0.75)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(clinic.icon, size: 56, color: Colors.white.withValues(alpha: 0.35)),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  clinic.tagline,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Gilroy-Bold',
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      'Presently Available Only ${clinic.location}',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  clinic.description,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.5),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Our Services',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Gilroy-Bold',
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                ...clinic.services.map((s) => _ServiceTile(service: s, accent: clinic.accentColor)),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _bookAppointment(context),
                    icon: const Icon(Icons.calendar_month_rounded, size: 18),
                    label: const Text('Book Appointment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: clinic.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _enquireOnWhatsApp(context),
                    icon: const Icon(Icons.chat_rounded, size: 18, color: Color(0xFF25D366)),
                    label: const Text('Enquire on WhatsApp'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF128C7E),
                      side: const BorderSide(color: Color(0xFF25D366)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final ClinicService service;
  final Color accent;
  const _ServiceTile({required this.service, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text(
                  service.description,
                  style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
