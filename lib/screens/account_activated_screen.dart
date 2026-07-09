import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icare/utils/theme.dart';

class AccountActivatedScreen extends StatefulWidget {
  final String role;
  final String userName;

  const AccountActivatedScreen({
    super.key,
    required this.role,
    required this.userName,
  });

  @override
  State<AccountActivatedScreen> createState() => _AccountActivatedScreenState();
}

class _AccountActivatedScreenState extends State<AccountActivatedScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _goOnline() {
    // Navigate to appropriate dashboard based on role
    if (widget.role == 'Doctor') {
      context.go('/tabs');
    } else if (widget.role == 'Pharmacy') {
      context.go('/tabs');
    } else if (widget.role == 'Laboratory') {
      context.go('/tabs');
    } else {
      context.go('/tabs');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isDesktop ? 40 : 20),
            child: Container(
              constraints: BoxConstraints(maxWidth: isDesktop ? 600 : double.infinity),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Image.asset(
                    'assets/Asset 1.png',
                    height: 80,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(height: 40),
                  // Main Card
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Success Icon with animation
                        ScaleTransition(
                          scale: _scaleAnimation,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified_rounded,
                              color: Color(0xFF10B981),
                              size: 56,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          '🎉 Account Activated!',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            fontFamily: 'Gilroy-Bold',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Congratulations ${widget.userName}! Your account has been verified and activated.',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        _buildInfoCard(
                          icon: Icons.shield_rounded,
                          title: 'Verified Provider',
                          subtitle: 'You\'re now a verified ${widget.role} on iCare',
                          color: const Color(0xFF10B981),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoCard(
                          icon: Icons.people_rounded,
                          title: 'Start Serving Patients',
                          subtitle: 'You can now accept orders and bookings',
                          color: AppColors.primaryColor,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoCard(
                          icon: Icons.support_agent_rounded,
                          title: '24/7 Support',
                          subtitle: 'Our team is here to help you succeed',
                          color: const Color(0xFF8B5CF6),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _goOnline,
                            icon: const Icon(Icons.rocket_launch_rounded, size: 22),
                            label: const Text(
                              'Go Online Now',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Gilroy-Bold',
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => context.go('/home'),
                          child: const Text(
                            'I\'ll set up my profile later',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Pro Tip
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primaryColor.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb_rounded, color: AppColors.primaryColor, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Pro Tip: Complete your profile to get more visibility and trust from patients',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.primaryColor,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
