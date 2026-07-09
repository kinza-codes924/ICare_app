import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icare/services/auth_service.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/screens/tabs.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  final String email;

  const EmailVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  final _tokenController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _verifyEmail() async {
    if (_tokenController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the verification token';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final result = await AuthService().verifyEmail(_tokenController.text.trim());

      if (result['success'] == true) {
        setState(() {
          _successMessage = result['message'] ?? 'Email verified successfully!';
        });

        // Navigate to login after 2 seconds
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Verification failed';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Unable to verify email. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendVerification() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final result = await AuthService().resendVerificationEmail(widget.email);

      if (result['success'] == true) {
        setState(() {
          _successMessage = result['message'] ?? 'Verification email sent!';
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to resend email';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Unable to resend email. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const CustomText(
          text: 'Verify Email',
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // Email icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.email_outlined,
                  size: 50,
                  color: AppColors.primaryColor,
                ),
              ),

              const SizedBox(height: 30),

              // Title
              const CustomText(
                text: 'Verify Your Email',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // Description
              CustomText(
                text: 'We sent a verification link to\n${widget.email}',
                fontSize: 14,
                color: Colors.grey[600],
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              CustomText(
                text: 'Please check your inbox and enter the verification token below.',
                fontSize: 14,
                color: Colors.grey[600],
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Token input
              TextField(
                controller: _tokenController,
                decoration: InputDecoration(
                  labelText: 'Verification Token',
                  hintText: 'Enter token from email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.vpn_key),
                ),
                keyboardType: TextInputType.text,
              ),

              const SizedBox(height: 20),

              // Error message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CustomText(
                          text: _errorMessage!,
                          fontSize: 13,
                          color: Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                ),

              // Success message
              if (_successMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.green[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CustomText(
                          text: _successMessage!,
                          fontSize: 13,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // Verify button
              CustomButton(
                label: _isLoading ? 'Verifying...' : 'Verify Email',
                onPressed: _isLoading ? null : _verifyEmail,
                bgColor: AppColors.primaryColor,
              ),

              const SizedBox(height: 20),

              // Resend link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomText(
                    text: "Didn't receive the email? ",
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  TextButton(
                    onPressed: _isResending ? null : _resendVerification,
                    child: CustomText(
                      text: _isResending ? 'Sending...' : 'Resend',
                      fontSize: 14,
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Skip button - temporary until backend implements email verification
              CustomButton(
                label: 'Skip for Now',
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (ctx) => const TabsScreen()),
                  );
                },
                bgColor: Colors.grey[600],
              ),

              const SizedBox(height: 12),

              // Back to login
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                child: const CustomText(
                  text: 'Back to Login',
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
