import 'package:flutter/material.dart';
import 'package:icare/widgets/back_button.dart';

const Color _primary = Color(0xFF0B2D6E);
const Color _secondary = Color(0xFF1565C0);
const Color _accent = Color(0xFF0EA5E9);

class AboutUs extends StatelessWidget {
  const AboutUs({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 700;
    return isDesktop ? const _WebAboutUs() : const _MobileAboutUs();
  }
}

// ── Mobile ───────────────────────────────────────────────────────────────────

class _MobileAboutUs extends StatelessWidget {
  const _MobileAboutUs();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: const CustomBackButton(),
        title: const Text(
          'About Us',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: _primary,
            fontFamily: 'Gilroy-Bold',
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero banner
            Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 200,
                  child: Image.asset(
                    'assets/images/doctor_banner.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: _primary),
                  ),
                ),
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primary.withValues(alpha: 0.85), _secondary.withValues(alpha: 0.5)],
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                    ),
                  ),
                ),
                const Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reshaping Healthcare.',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'Gilroy-Bold'),
                      ),
                      Text(
                        'Connecting Lives.',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF7DD3FC), fontFamily: 'Gilroy-Bold'),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Intro
                  const Text(
                    'Welcome to iCare',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _primary, fontFamily: 'Gilroy-Bold'),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Welcome to iCare, a premier digital health ecosystem engineered to redefine the relationship between patients, healthcare professionals, and medical wellness. We believe that the future of medicine shouldn\'t be fragmented, complex, or inaccessible. It should be seamless, inclusive, and built entirely around you.',
                    style: TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.7),
                  ),
                  const SizedBox(height: 24),

                  // Vision image + section
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/lab1.png',
                      width: double.infinity,
                      height: 160,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 160,
                        color: _primary.withValues(alpha: 0.08),
                        child: const Center(child: Icon(Icons.biotech_rounded, size: 48, color: _primary)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _mobileSection(
                    Icons.visibility_rounded,
                    'Our Vision',
                    'At iCare, our mission is simple yet revolutionary: to bridge the critical gaps in modern healthcare by leveraging advanced digital solutions. We are forging an ecosystem where geography is no longer a barrier to exceptional care. By bringing patients and verified medical professionals together under one secure digital roof, we empower individuals to take control of their well-being with unprecedented ease.',
                  ),
                  const SizedBox(height: 8),

                  // Why iCare
                  _mobileSection(
                    Icons.star_rounded,
                    'Why iCare?',
                    null,
                    bullets: const [
                      ('Inclusive Healthcare', 'We design our services to ensure that quality medical expertise is accessible to everyone, everywhere.', Icons.public_rounded),
                      ('Unified Connectivity', 'We replace traditional, chaotic healthcare hurdles with a streamlined, intelligent experience that prioritises your time and health.', Icons.hub_rounded),
                      ('Excellence & Trust', 'Backed by leading healthcare frameworks and a commitment to global standards, we ensure a safe, secure, and world-class digital environment.', Icons.verified_rounded),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Empowering image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/doctor_banner2.png',
                      width: double.infinity,
                      height: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 150,
                        color: _accent.withValues(alpha: 0.08),
                        child: const Center(child: Icon(Icons.people_rounded, size: 48, color: _accent)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _mobileSection(
                    Icons.rocket_launch_rounded,
                    'Empowering the Future',
                    'Beyond connecting patients with care, iCare is dedicated to elevating the entire medical industry. We support the next generation of healthcare professionals by introducing advanced clinical insights, fostering leadership, and helping clinicians adapt to a rapidly evolving digital world.\n\nWe aren\'t just adapting to the future of healthcare — we are actively creating it.',
                  ),
                  const SizedBox(height: 24),

                  // CTA
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_primary, _secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.favorite_rounded, color: Colors.white, size: 32),
                        SizedBox(height: 12),
                        Text(
                          'Join the Revolution.',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'Gilroy-Bold'),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'Experience Unified Care.',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF7DD3FC), fontFamily: 'Gilroy-Bold'),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'RM Health Solutions (Private) Limited',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileSection(IconData icon, String title, String? body, {List<(String, String, IconData)>? bullets}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: _primary, size: 18),
          ),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontFamily: 'Gilroy-Bold')),
        ]),
        const SizedBox(height: 10),
        if (body != null)
          Text(body, style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.7)),
        if (bullets != null)
          ...bullets.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: _accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(b.$3, size: 14, color: _accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.$1, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Text(b.$2, style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.6)),
                ]),
              ),
            ]),
          )),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Desktop / Web ─────────────────────────────────────────────────────────────

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
        leading: const CustomBackButton(),
        title: const Text(
          'About Us',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _primary, fontFamily: 'Gilroy-Bold'),
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Hero card ──────────────────────────────────────
                  _heroCard(),
                  const SizedBox(height: 32),

                  // ── Intro ──────────────────────────────────────────
                  _webSection(
                    icon: Icons.info_outline_rounded,
                    title: 'Welcome to iCare',
                    body: 'Welcome to iCare, a premier digital health ecosystem engineered to redefine the relationship between patients, healthcare professionals, and medical wellness. We believe that the future of medicine shouldn\'t be fragmented, complex, or inaccessible. It should be seamless, inclusive, and built entirely around you.',
                    imagePath: 'assets/images/icare-banner.png',
                    imageRight: false,
                  ),
                  const SizedBox(height: 24),

                  // ── Vision ─────────────────────────────────────────
                  _webSection(
                    icon: Icons.visibility_rounded,
                    title: 'Our Vision',
                    body: 'At iCare, our mission is simple yet revolutionary: to bridge the critical gaps in modern healthcare by leveraging advanced digital solutions. We are forging an ecosystem where geography is no longer a barrier to exceptional care. By bringing patients and verified medical professionals together under one secure digital roof, we empower individuals to take control of their well-being with unprecedented ease.',
                    imagePath: 'assets/images/lab1.png',
                    imageRight: true,
                  ),
                  const SizedBox(height: 24),

                  // ── Why iCare ─────────────────────────────────────
                  _whyIcareCard(),
                  const SizedBox(height: 24),

                  // ── Empowering ────────────────────────────────────
                  _webSection(
                    icon: Icons.rocket_launch_rounded,
                    title: 'Empowering the Future',
                    body: 'Beyond connecting patients with care, iCare is dedicated to elevating the entire medical industry. We support the next generation of healthcare professionals by introducing advanced clinical insights, fostering leadership, and helping clinicians adapt to a rapidly evolving digital world.\n\nWe aren\'t just adapting to the future of healthcare — we are actively creating it.',
                    imagePath: 'assets/images/doctor_banner2.png',
                    imageRight: false,
                  ),
                  const SizedBox(height: 32),

                  // ── CTA ───────────────────────────────────────────
                  _ctaBanner(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            height: 320,
            child: Image.asset(
              'assets/images/doctor_banner.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 320,
                color: _primary,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            height: 320,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primary.withValues(alpha: 0.88), _secondary.withValues(alpha: 0.4)],
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
              ),
            ),
          ),
          const Positioned(
            bottom: 40,
            left: 48,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About Us',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF7DD3FC), letterSpacing: 2),
                ),
                SizedBox(height: 8),
                Text(
                  'Reshaping Healthcare.',
                  style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'Gilroy-Bold', height: 1.1),
                ),
                Text(
                  'Connecting Lives.',
                  style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Color(0xFF7DD3FC), fontFamily: 'Gilroy-Bold', height: 1.1),
                ),
                SizedBox(height: 16),
                Text(
                  'A premier digital health ecosystem — built entirely around you.',
                  style: TextStyle(fontSize: 16, color: Colors.white70, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _webSection({
    required IconData icon,
    required String title,
    required String body,
    required String imagePath,
    required bool imageRight,
  }) {
    final textBlock = Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: _primary, size: 22),
            ),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontFamily: 'Gilroy-Bold')),
          ]),
          const SizedBox(height: 16),
          Text(body, style: const TextStyle(fontSize: 15, color: Color(0xFF475569), height: 1.8)),
        ],
      ),
    );

    final imageBlock = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(child: Icon(Icons.image_rounded, size: 48, color: _primary)),
        ),
      ),
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: imageRight
            ? [
                Expanded(flex: 3, child: textBlock),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: imageBlock),
              ]
            : [
                Expanded(flex: 2, child: imageBlock),
                const SizedBox(width: 20),
                Expanded(flex: 3, child: textBlock),
              ],
      ),
    );
  }

  Widget _whyIcareCard() {
    const bullets = [
      (
        'Inclusive Healthcare',
        'We design our services to ensure that quality medical expertise is accessible to everyone, everywhere.',
        Icons.public_rounded,
        Color(0xFF0EA5E9),
        'assets/images/patient.png',
      ),
      (
        'Unified Connectivity',
        'We replace traditional, chaotic healthcare hurdles with a streamlined, intelligent experience that prioritises your time and health.',
        Icons.hub_rounded,
        Color(0xFF8B5CF6),
        'assets/images/lab2.png',
      ),
      (
        'Excellence & Trust',
        'Backed by leading healthcare frameworks and a commitment to global standards, we ensure a safe, secure, and world-class digital environment.',
        Icons.verified_rounded,
        Color(0xFF10B981),
        'assets/images/lab3.png',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.star_rounded, color: _primary, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Why iCare?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontFamily: 'Gilroy-Bold')),
          ]),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: bullets.map((b) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        b.$5,
                        width: double.infinity,
                        height: 130,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 130,
                          decoration: BoxDecoration(
                            color: (b.$4).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(child: Icon(b.$3, size: 36, color: b.$4)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: (b.$4).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Icon(b.$3, size: 15, color: b.$4),
                      ),
                      const SizedBox(width: 8),
                      Flexible(child: Text(b.$1, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)))),
                    ]),
                    const SizedBox(height: 8),
                    Text(b.$2, style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.7)),
                  ],
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _ctaBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            height: 200,
            child: Image.asset(
              'assets/images/lab-tech.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(height: 200, color: _primary),
            ),
          ),
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primary.withValues(alpha: 0.92), _secondary.withValues(alpha: 0.75)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          const Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_rounded, color: Colors.white, size: 36),
                SizedBox(height: 12),
                Text(
                  'Join the Revolution. Experience Unified Care.',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'Gilroy-Bold'),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'RM Health Solutions (Private) Limited',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
