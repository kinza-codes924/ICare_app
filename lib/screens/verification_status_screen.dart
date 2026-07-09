import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/screens/account_activated_screen.dart';

class VerificationStatusScreen extends StatefulWidget {
  final String role;
  final String applicantName;

  const VerificationStatusScreen({
    super.key,
    required this.role,
    required this.applicantName,
  });

  @override
  State<VerificationStatusScreen> createState() => _VerificationStatusScreenState();
}

class _VerificationStatusScreenState extends State<VerificationStatusScreen> {
  bool _isRefreshing = false;

  // Mock status - in real implementation, this will come from API
  int _currentStep = 1; // 0: Submitted, 1: In Progress, 2: Activated

  Future<void> _refreshStatus() async {
    setState(() => _isRefreshing = true);

    try {
      // Check approval status from backend
      final api = ApiService();
      final response = await api.get('/auth/profile');
      if (response.statusCode == 200) {
        final user = response.data;
        final isApproved = user['isApproved'] == true || user['is_approved'] == true;
        if (isApproved && mounted) {
          setState(() => _currentStep = 2);
        }
      }
    } catch (_) {
      // Silently ignore — just show snackbar below
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }

    if (!mounted) return;

    if (_currentStep >= 2) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AccountActivatedScreen(
            role: widget.role,
            userName: widget.applicantName,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Still in progress. Check back soon.'),
          duration: Duration(seconds: 2),
        ),
      );
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
                    padding: const EdgeInsets.all(32),
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
                        // Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.hourglass_empty_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Verification in Progress',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
                                        fontFamily: 'Gilroy-Bold',
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'We\'re reviewing your application',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Applicant Info
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                                child: Text(
                                  widget.applicantName.isNotEmpty
                                      ? widget.applicantName[0].toUpperCase()
                                      : 'U',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.applicantName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Applying as ${widget.role}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Timeline
                        _buildTimeline(),

                        const SizedBox(height: 32),

                        // Estimated Time
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primaryColor.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                color: AppColors.primaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Estimated verification time: 24-48 hours',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Refresh Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _isRefreshing ? null : _refreshStatus,
                            icon: _isRefreshing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded, size: 20),
                            label: Text(
                              _isRefreshing ? 'Refreshing...' : 'Refresh Status',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Gilroy-Bold',
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryColor,
                              side: BorderSide(
                                color: AppColors.primaryColor,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Back to Home
                        TextButton(
                          onPressed: () => context.go('/home'),
                          child: const Text(
                            'Back to Home',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Help Text
                  Text(
                    'You\'ll receive an email notification once your account is verified',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    return Column(
      children: [
        _buildTimelineStep(
          icon: Icons.check_circle_rounded,
          title: 'Application Submitted',
          subtitle: 'Your information has been received',
          isCompleted: true,
          isActive: false,
        ),
        _buildTimelineConnector(isCompleted: _currentStep >= 1),
        _buildTimelineStep(
          icon: Icons.pending_actions_rounded,
          title: 'Verification in Progress',
          subtitle: 'Our team is reviewing your documents',
          isCompleted: false,
          isActive: _currentStep == 1,
        ),
        _buildTimelineConnector(isCompleted: _currentStep >= 2),
        _buildTimelineStep(
          icon: Icons.verified_rounded,
          title: 'Account Activated',
          subtitle: 'You can start using your account',
          isCompleted: _currentStep >= 2,
          isActive: false,
        ),
      ],
    );
  }

  Widget _buildTimelineStep({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isActive,
  }) {
    final color = isCompleted
        ? const Color(0xFF10B981)
        : isActive
            ? const Color(0xFFF59E0B)
            : const Color(0xFF94A3B8);

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: color,
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isCompleted || isActive
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF94A3B8),
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
    );
  }

  Widget _buildTimelineConnector({required bool isCompleted}) {
    return Container(
      margin: const EdgeInsets.only(left: 23, top: 4, bottom: 4),
      width: 2,
      height: 32,
      color: isCompleted
          ? const Color(0xFF10B981)
          : const Color(0xFFE2E8F0),
    );
  }
}
