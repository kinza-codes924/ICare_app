import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';

class ProfessionalSignup extends StatefulWidget {
  final String role;
  final String roleDescription;

  const ProfessionalSignup({
    super.key,
    required this.role,
    required this.roleDescription,
  });

  @override
  State<ProfessionalSignup> createState() => _ProfessionalSignupState();
}

class _ProfessionalSignupState extends State<ProfessionalSignup> {
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _licenseNumber = TextEditingController();
  final _credentials = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _licenseNumber.dispose();
    _credentials.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  bool get _isDoctor => widget.role == 'Doctor';

  Color get _roleColor {
    switch (widget.role) {
      case 'Doctor':
        return const Color(0xFF0036BC);
      case 'Pharmacy':
        return const Color(0xFF10B981);
      case 'Laboratory':
        return const Color(0xFF8B5CF6);
      case 'Instructor':
        return const Color(0xFFF59E0B);
      default:
        return AppColors.primaryColor;
    }
  }

  IconData get _roleIcon {
    switch (widget.role) {
      case 'Doctor':
        return Icons.medical_services_rounded;
      case 'Pharmacy':
        return Icons.local_pharmacy_rounded;
      case 'Laboratory':
        return Icons.biotech_rounded;
      case 'Instructor':
        return Icons.school_rounded;
      default:
        return Icons.work_rounded;
    }
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool readOnly = false,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        obscureText: obscure,
        keyboardType: keyboardType,
        validator: validator ??
            (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        style: const TextStyle(fontSize: 15, fontFamily: 'Gilroy-Medium'),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: _roleColor, size: 20),
          suffixIcon: onToggleObscure != null
              ? IconButton(
                  icon: Icon(
                    obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: onToggleObscure,
                )
              : null,
          filled: true,
          fillColor: readOnly ? const Color(0xFFF1F5F9) : Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _roleColor, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          labelStyle: const TextStyle(fontFamily: 'Gilroy-Medium', fontSize: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0036BC)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            SvgPicture.asset(ImagePaths.logo, width: 30, height: 30, colorFilter: null),
            const SizedBox(width: 8),
            Text(
              '${widget.role} Sign Up',
              style: const TextStyle(
                color: Color(0xFF0036BC),
                fontWeight: FontWeight.w800,
                fontSize: 17,
                fontFamily: 'Gilroy-Bold',
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Role badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _roleColor.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _roleColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(_roleIcon, color: _roleColor, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.role,
                                style: TextStyle(
                                  color: _roleColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  fontFamily: 'Gilroy-Bold',
                                ),
                              ),
                              Text(
                                widget.roleDescription,
                                style: TextStyle(
                                  color: _roleColor.withValues(alpha: 0.7),
                                  fontSize: 12,
                                  fontFamily: 'Gilroy-Medium',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  Text(
                    'Create your account',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                      fontFamily: 'Gilroy-Bold',
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Fill in the details below to get started',
                    style: TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Gilroy-Medium'),
                  ),
                  const SizedBox(height: 24),

                  // Full Name
                  _buildField(
                    controller: _fullName,
                    label: 'Full Name',
                    icon: Icons.person_rounded,
                    hint: 'Enter your full name',
                  ),

                  // Role (read-only)
                  _buildField(
                    controller: TextEditingController(text: widget.roleDescription),
                    label: 'Role',
                    icon: _roleIcon,
                    readOnly: true,
                    validator: (_) => null,
                  ),

                  // Email
                  _buildField(
                    controller: _email,
                    label: 'Email Address',
                    icon: Icons.email_rounded,
                    hint: 'Enter your email',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),

                  // Phone
                  _buildField(
                    controller: _phone,
                    label: 'Phone Number',
                    icon: Icons.phone_rounded,
                    hint: '+92 3XX XXXXXXX',
                    keyboardType: TextInputType.phone,
                  ),

                  // Doctor-specific fields
                  if (_isDoctor) ...[
                    _buildField(
                      controller: _licenseNumber,
                      label: 'Medical License Number',
                      icon: Icons.badge_rounded,
                      hint: 'e.g. PMDC-12345',
                    ),
                    _buildField(
                      controller: _credentials,
                      label: 'Credentials',
                      icon: Icons.school_rounded,
                      hint: 'e.g. MBBS, FCPS, MD',
                    ),
                  ],

                  // Password
                  _buildField(
                    controller: _password,
                    label: 'Password',
                    icon: Icons.lock_rounded,
                    obscure: _obscurePassword,
                    onToggleObscure: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.length < 6) return 'Minimum 6 characters';
                      return null;
                    },
                  ),

                  // Confirm Password
                  _buildField(
                    controller: _confirmPassword,
                    label: 'Confirm Password',
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscureConfirm,
                    onToggleObscure: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v != _password.text) return 'Passwords do not match';
                      return null;
                    },
                  ),

                  const SizedBox(height: 8),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${widget.role} account submitted for review.'),
                              backgroundColor: _roleColor,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _roleColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Submit Application',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Gilroy-Bold',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
