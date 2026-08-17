import 'package:flutter/material.dart';
import 'package:icare/data/icare_clinics_data.dart';
import 'package:icare/models/clinic.dart';
import 'package:icare/screens/clinic_detail_screen.dart';

/// Landing screen shown after tapping into the "iCare Clinics" home-page
/// section — grid of the 6 branded specialty clinics.
class ICareClinicsListScreen extends StatelessWidget {
  const ICareClinicsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text(
          'iCare Clinics',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontFamily: 'Gilroy-Bold',
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Premium Multi-Speciality',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                fontFamily: 'Gilroy-Bold',
                color: Color(0xFF0036BC),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  'Presently Available Only Karachi',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 24),
            GridView.count(
              crossAxisCount: isMobile ? 2 : 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: isMobile ? 0.85 : 1.05,
              children: kICareClinics.map((c) => _ClinicCard(clinic: c)).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClinicCard extends StatefulWidget {
  final Clinic clinic;
  const _ClinicCard({required this.clinic});

  @override
  State<_ClinicCard> createState() => _ClinicCardState();
}

class _ClinicCardState extends State<_ClinicCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.clinic;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ClinicDetailScreen(clinic: c)),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()..translate(0.0, _hovered ? -3.0 : 0.0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered ? c.accentColor : const Color(0xFFE2E8F0),
              width: _hovered ? 1.5 : 1,
            ),
            boxShadow: [
              if (_hovered)
                BoxShadow(
                  color: c.accentColor.withValues(alpha: 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: c.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(c.icon, color: c.accentColor, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                c.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Gilroy-Bold',
                  color: Color(0xFF0F172A),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                c.tagline,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Row(
                children: [
                  Text(
                    'Learn More',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.accentColor),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: c.accentColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
