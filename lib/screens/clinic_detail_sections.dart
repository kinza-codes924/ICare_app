import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:icare/models/clinic.dart';
import 'package:icare/widgets/review_card.dart';

/// Numbered step timeline (Consultation -> Diagnosis -> Treatment ->
/// Follow-up), horizontal on desktop and stacked on mobile.
class JourneyTimeline extends StatelessWidget {
  final List<JourneyStep> steps;
  final Color accent;
  final bool isMobile;

  const JourneyTimeline({
    super.key,
    required this.steps,
    required this.accent,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Column(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            _StepTile(step: steps[i], index: i + 1, accent: accent),
            if (i != steps.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 19),
                child: Container(width: 2, height: 20, color: accent.withValues(alpha: 0.25)),
              ),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          Expanded(child: _StepTile(step: steps[i], index: i + 1, accent: accent, horizontal: true)),
          if (i != steps.length - 1)
            Padding(
              padding: const EdgeInsets.only(top: 19),
              child: Container(width: 32, height: 2, color: accent.withValues(alpha: 0.25)),
            ),
        ],
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  final JourneyStep step;
  final int index;
  final Color accent;
  final bool horizontal;

  const _StepTile({required this.step, required this.index, required this.accent, this.horizontal = false});

  @override
  Widget build(BuildContext context) {
    final numberCircle = Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
      child: Icon(step.icon, color: Colors.white, size: 20),
    );

    if (horizontal) {
      return Column(
        children: [
          numberCircle,
          const SizedBox(height: 10),
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          Text(
            step.description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        numberCircle,
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 3),
                Text(
                  step.description,
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Static patient testimonials for a clinic. Placeholder-but-realistic
/// content — text only, no photos, per the client's explicit instruction.
class TestimonialsSection extends StatelessWidget {
  final List<ClinicTestimonial> testimonials;

  const TestimonialsSection({super.key, required this.testimonials});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: testimonials
          .map((t) => ReviewCard(
                name: t.patientName,
                rating: t.rating,
                comment: t.comment,
                dateLabel: t.dateLabel,
              ))
          .toList(),
    );
  }
}

/// Expand/collapse FAQ list.
class FaqAccordion extends StatefulWidget {
  final List<ClinicFaq> faqs;
  final Color accent;

  const FaqAccordion({super.key, required this.faqs, required this.accent});

  @override
  State<FaqAccordion> createState() => _FaqAccordionState();
}

class _FaqAccordionState extends State<FaqAccordion> {
  int? _openIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < widget.faqs.length; i++)
          _FaqTile(
            faq: widget.faqs[i],
            accent: widget.accent,
            expanded: _openIndex == i,
            onTap: () => setState(() => _openIndex = _openIndex == i ? null : i),
          ),
      ],
    );
  }
}

class _FaqTile extends StatelessWidget {
  final ClinicFaq faq;
  final Color accent;
  final bool expanded;
  final VoidCallback onTap;

  const _FaqTile({required this.faq, required this.accent, required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      faq.question,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: accent),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  faq.answer,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
                ),
              ),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Address + hours + "Get Directions" link. Uses a Google Maps search URL
/// rather than an embedded map.
class VisitClinicSection extends StatelessWidget {
  final Clinic clinic;

  const VisitClinicSection({super.key, required this.clinic});

  Future<void> _openDirections() async {
    final query = Uri.encodeComponent(clinic.mapQuery);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(icon: Icons.location_on_rounded, accent: clinic.accentColor, text: clinic.address),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.access_time_rounded, accent: clinic.accentColor, text: clinic.hoursLabel),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openDirections,
              icon: Icon(Icons.directions_rounded, size: 18, color: clinic.accentColor),
              label: const Text('Get Directions'),
              style: OutlinedButton.styleFrom(
                foregroundColor: clinic.accentColor,
                side: BorderSide(color: clinic.accentColor, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String text;

  const _InfoRow({required this.icon, required this.accent, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155), height: 1.4),
          ),
        ),
      ],
    );
  }
}
