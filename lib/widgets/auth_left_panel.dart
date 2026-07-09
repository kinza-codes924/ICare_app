import 'package:flutter/material.dart';

/// Shared branded left panel used on all auth screens.
/// Matches the login screen exactly: iCare logo, RM Health Solution branding,
/// and 4 improved trust badges with subtitles.
class AuthLeftPanel extends StatelessWidget {
  const AuthLeftPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Container(
      height: h,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF001E6C), Color(0xFF0036BC), Color(0xFF035BE5)],
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -80, left: -80,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            bottom: -100, right: -50,
            child: Container(
              width: 350, height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.03),
              ),
            ),
          ),

          // Content
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // iCare Logo — white box container (same as login page)
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Image.asset(
                      'assets/Asset 1.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // "by" text
                  Text(
                    'by',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // RM Health Solution logo image
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Image.asset(
                      'assets/images/health.jpeg',
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Text(
                        'RM Health Solution',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0036BC)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Tagline
                  Text(
                    'Your Trusted Healthcare Platform',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Secure consultations, prescriptions\n& health records',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Divider
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  const SizedBox(height: 28),

                  // 4 Trust badges — 2 left, 2 right (same as login screen)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _trust(Icons.shield_rounded, 'Data Protected & Secure', 'End-to-end encrypted health records', const Color(0xFFEF4444)),
                            const SizedBox(height: 18),
                            _trust(Icons.verified_user_rounded, 'HIPAA Compliant', 'Meeting US healthcare data security standards', const Color(0xFF10B981)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _trust(Icons.local_hospital_rounded, 'Complete Digital Health Care Platform', 'Consult, prescribe & manage all-in-one', const Color(0xFF8B5CF6)),
                            const SizedBox(height: 18),
                            _trust(Icons.people_rounded, 'Open for Everyone', 'For patients, doctors & healthcare providers', const Color(0xFFF59E0B)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trust(IconData icon, String title, String subtitle, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40, height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: iconColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
