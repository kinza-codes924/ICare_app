import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/services/auth_service.dart';
import 'package:icare/models/user.dart' as app_user;
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/auth_left_panel.dart';

class SignupScreen extends ConsumerStatefulWidget {
  final String role;
  const SignupScreen({super.key, this.role = 'Patient'});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _agreedToTerms = false;
  String? _selectedGender;
  DateTime? _dob;

  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _licenseNumber = TextEditingController();
  final _credentials = TextEditingController();
  final _orgName = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _licenseNumber.dispose();
    _credentials.dispose();
    _orgName.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  // ── Password strength ────────────────────────────────────────────────────
  bool get _hasMinLength => _password.text.length >= 8;
  bool get _hasUppercase => _password.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase => _password.text.contains(RegExp(r'[a-z]'));
  bool get _hasDigit => _password.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecial => _password.text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-]'));

  String? _computedAge() => _computeAgeFrom(_dob);

  String? _computeAgeFrom(DateTime? dob) {
    if (dob == null) return null;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) age--;
    return age.toString();
  }

  bool get _isPatient => widget.role == 'Patient';
  bool get _isDoctor => widget.role == 'Doctor';
  bool get _isPharmacy => widget.role == 'Pharmacy';
  bool get _isLab => widget.role == 'Laboratory';
  bool get _isInstructor => widget.role == 'Instructor';
  // Pharmacy, Lab, Instructor go to admin review instead of direct signup
  bool get _needsReview => _isPharmacy || _isLab || _isInstructor;

  String get _roleDescription {
    switch (widget.role) {
      case 'Doctor':     return 'Doctor – Manage Patients & Prescriptions';
      case 'Pharmacy':   return 'Pharmacy – Prescription Fulfillment';
      case 'Laboratory': return 'Laboratory – Diagnostics & Reports';
      case 'Instructor': return 'Instructor – Teach Health Programs';
      default:           return 'Patient';
    }
  }

  Color get _roleColor {
    switch (widget.role) {
      case 'Doctor':     return const Color(0xFF0036BC);
      case 'Pharmacy':   return const Color(0xFF10B981);
      case 'Laboratory': return const Color(0xFF8B5CF6);
      case 'Instructor': return const Color(0xFFF59E0B);
      default:           return AppColors.primaryColor;
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      _showError('Please agree to the Terms & Conditions to continue.'.tr());
      return;
    }
    setState(() => _isLoading = true);

    try {
      // Pharmacy / Lab / Instructor → admin review, no API call
      if (_needsReview) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showReviewDialog();
        return;
      }

      // Patient & Doctor → direct account creation
      // Capture form values NOW before any async/navigation that disposes controllers
      final capturedName = _fullName.text.trim();
      final capturedEmail = _email.text.trim();
      final capturedPhone = _phone.text.trim();
      final capturedGender = _selectedGender;
      final capturedDob = _dob;

      ref.read(authProvider.notifier).setUserRole(widget.role);

      final capturedPassword = _password.text.trim();

      final result = await _authService.register(
        name: capturedName,
        email: capturedEmail,
        password: capturedPassword,
        role: widget.role,
        phoneNumber: capturedPhone,
        gender: _isPatient ? capturedGender : null,
        dateOfBirth: (_isPatient && capturedDob != null) ? capturedDob.toIso8601String() : null,
      );

      if (result['success']) {
        final rawData = result['data'] as Map<String, dynamic>? ?? {};
        final token = rawData['token']?.toString()
            ?? rawData['data']?['token']?.toString() ?? '';

        if (token.isNotEmpty) {
          await ref.read(authProvider.notifier).setUserToken(token);
        }

        // Get user id from registration response if available
        final userData = rawData['user'] as Map<String, dynamic>?
            ?? rawData['data']?['user'] as Map<String, dynamic>?;
        final userId = userData?['_id']?.toString()
            ?? userData?['id']?.toString()
            ?? rawData['_id']?.toString()
            ?? rawData['id']?.toString()
            ?? '';

        // Always build user from captured form data — never trust backend name
        // (backend may store username/default instead of the entered name)
        final newUser = app_user.User(
          id: userId,
          name: capturedName,
          email: capturedEmail,
          phoneNumber: capturedPhone,
          role: widget.role,
          gender: _isPatient ? capturedGender : null,
          age: _isPatient ? _computeAgeFrom(capturedDob) : null,
        );
        await ref.read(authProvider.notifier).setUser(newUser);

        if (!mounted) return;
        context.go('/dashboard');
      } else {
        _showError(result['message'] ?? 'Registration failed. Please try again.');
      }
    } catch (e) {
      debugPrint('Signup error: $e');
      _showError('An error occurred. Please check your connection and try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showReviewDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 52),
        title: Text(
          'Application Submitted'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Gilroy-Bold'),
        ),
        content: Text(
          'Your ${widget.role} application has been submitted for admin review. You will be notified once approved.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Gilroy-Medium', color: Color(0xFF64748B)),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              elevation: 0,
            ),
            child: Text('OK'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showError(dynamic msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg.toString()),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  // ── Reusable field ───────────────────────────────────────────────────────
  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    bool obscure = false,
    VoidCallback? onToggle,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
    List<String>? autofillHints,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        obscureText: obscure,
        keyboardType: keyboard,
        autofillHints: readOnly ? null : autofillHints,
        validator: validator ??
            (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        style: const TextStyle(
          fontSize: 15,
          fontFamily: 'Gilroy-Medium',
          color: Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            fontFamily: 'Gilroy-Medium',
            fontSize: 14,
            color: Color(0xFF64748B),
          ),
          prefixIcon: Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
          suffixIcon: onToggle != null
              ? IconButton(
                  icon: Icon(
                    obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 20, color: const Color(0xFF94A3B8),
                  ),
                  onPressed: onToggle,
                )
              : null,
          filled: true,
          fillColor: readOnly ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.primaryColor, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
        ),
      ),
    );
  }

  // ── Password strength widget ─────────────────────────────────────────────
  Widget _buildPasswordStrength() {
    if (_password.text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _strengthRow('At least 8 characters'.tr(), _hasMinLength),
          _strengthRow('One uppercase letter (A–Z)'.tr(), _hasUppercase),
          _strengthRow('One lowercase letter (a–z)'.tr(), _hasLowercase),
          _strengthRow('One number (0–9)'.tr(), _hasDigit),
          _strengthRow('One special character (!@#\$...)'.tr(), _hasSpecial),
        ],
      ),
    );
  }

  Widget _strengthRow(String label, bool passed) {
    final color = passed ? const Color(0xFF10B981) : const Color(0xFF94A3B8);
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontFamily: 'Gilroy-Medium')),
        ],
      ),
    );
  }

  // ── Gender selector ──────────────────────────────────────────────────────
  Widget _buildGenderSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              'Gender'.tr(),
              style: const TextStyle(fontSize: 13, fontFamily: 'Gilroy-Medium', color: Color(0xFF64748B)),
            ),
          ),
          Row(
            children: ['Male', 'Female', 'Other'].map((g) {
              final selected = _selectedGender == g;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedGender = g),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primaryColor : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? AppColors.primaryColor : const Color(0xFFE2E8F0),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      g,
                      style: TextStyle(
                        color: selected ? Colors.white : const Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Gilroy-Medium',
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── DOB picker ───────────────────────────────────────────────────────────
  Widget _buildDobPicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: _dob ?? DateTime(now.year - 25),
            firstDate: DateTime(1900),
            lastDate: DateTime(now.year - 1),
            builder: (ctx, child) => Theme(
              data: Theme.of(ctx).copyWith(
                colorScheme: ColorScheme.light(primary: AppColors.primaryColor),
              ),
              child: child!,
            ),
          );
          if (picked != null) setState(() => _dob = picked);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
          ),
          child: Row(
            children: [
              const Icon(Icons.cake_outlined, size: 20, color: Color(0xFF94A3B8)),
              const SizedBox(width: 12),
              Text(
                _dob != null
                    ? '${_dob!.day}/${_dob!.month}/${_dob!.year}'
                    : 'Date of Birth'.tr(),
                style: TextStyle(
                  fontSize: 15,
                  fontFamily: 'Gilroy-Medium',
                  color: _dob != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                ),
              ),
              const Spacer(),
              const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF94A3B8), size: 22),
            ],
          ),
        ),
      ),
    );
  }

  // ── Form fields list ─────────────────────────────────────────────────────
  List<Widget> _buildFields() {
    return [
      _field(
        controller: _fullName,
        label: 'Full Name'.tr(),
        icon: Icons.person_outline_rounded,
        autofillHints: const [AutofillHints.name],
      ),
      if (!_isPatient)
        _field(
          controller: TextEditingController(text: _roleDescription),
          label: 'Role',
          icon: Icons.work_outline_rounded,
          readOnly: true,
          validator: (_) => null,
        ),
      _field(
        controller: _email,
        label: 'Email Address'.tr(),
        icon: Icons.email_outlined,
        keyboard: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Required';
          if (!v.contains('@')) return 'Enter a valid email';
          return null;
        },
      ),
      _field(
        controller: _phone,
        label: 'Phone Number'.tr(),
        icon: Icons.phone_outlined,
        keyboard: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumber],
      ),
      // Patient-only: gender + DOB
      if (_isPatient) ...[
        _buildGenderSelector(),
        _buildDobPicker(),
      ],
      // Doctor-only extra fields
      if (_isDoctor) ...[
        _field(controller: _licenseNumber, label: 'Medical License Number', icon: Icons.badge_outlined),
        _field(controller: _credentials, label: 'Credentials (e.g. MBBS, FCPS)', icon: Icons.school_outlined),
      ],
      _field(
        controller: _password,
        label: 'Password'.tr(),
        icon: Icons.lock_outline_rounded,
        obscure: _obscurePass,
        autofillHints: const [AutofillHints.newPassword],
        onToggle: () => setState(() => _obscurePass = !_obscurePass),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Required';
          if (v.length < 8) return 'Minimum 8 characters';
          return null;
        },
      ),
      _buildPasswordStrength(),
      _field(
        controller: _confirmPassword,
        label: 'Confirm Password'.tr(),
        icon: Icons.lock_outline_rounded,
        obscure: _obscureConfirm,
        autofillHints: const [AutofillHints.newPassword],
        onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Required';
          if (v != _password.text) return 'Passwords do not match';
          return null;
        },
      ),
      // Terms & Conditions
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22, height: 22,
              child: Checkbox(
                value: _agreedToTerms,
                onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                activeColor: AppColors.primaryColor,
                checkColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  text: 'I agree to the '.tr(),
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontFamily: 'Gilroy-Medium'),
                  children: [
                    TextSpan(
                      text: 'Terms & Conditions'.tr(),
                      style: TextStyle(color: AppColors.primaryColor, fontWeight: FontWeight.w700, fontFamily: 'Gilroy-Bold'),
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(color: AppColors.primaryColor, fontWeight: FontWeight.w700, fontFamily: 'Gilroy-Bold'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  // ── Submit button ────────────────────────────────────────────────────────
  Widget _submitBtn({double height = 52}) => SizedBox(
        width: double.infinity,
        height: height,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            disabledBackgroundColor: const Color(0xFFCBD5E1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              : Text(
                  'Create Account'.tr(),
                  style: const TextStyle(
                    color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.w700, fontFamily: 'Gilroy-Bold',
                  ),
                ),
        ),
      );

  Widget _signInLink() => Center(
        child: GestureDetector(
          onTap: () => context.go('/login'),
          child: RichText(
            text: TextSpan(
              text: 'Already have an account? '.tr(),
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, fontFamily: 'Gilroy-Medium'),
              children: [
                TextSpan(
                  text: 'Sign In'.tr(),
                  style: TextStyle(color: AppColors.primaryColor, fontWeight: FontWeight.w700, fontFamily: 'Gilroy-Bold'),
                ),
              ],
            ),
          ),
        ),
      );

  // ── Left hero panel ──────────────────────────────────────────────────────
  Widget _buildLeftPanel(double height) => Container(
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF001E6C), Color(0xFF0036BC), Color(0xFF035BE5)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: -80, left: -80, child: _circle(300, 0.04)),
            Positioned(bottom: -100, right: -50, child: _circle(350, 0.03)),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 50),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo with white background box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/Asset 1.png',
                        height: 80,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    const SizedBox(height: 28),
                    // "by" text
                    Text('by',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.75)),
                    ),
                    const SizedBox(height: 8),
                    // RM Health Solution logo
                    Image.asset(
                      'assets/images/rm_health_solution_logo.png',
                      height: 48,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Text(
                        'RM Health Solution',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.95)),
                      ),
                    ),
                    const SizedBox(height: 32),
                    IntrinsicWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _trust(Icons.shield_rounded, 'Data Protected & Secure', const Color(0xFF10B981)),
                          const SizedBox(height: 14),
                          _trust(Icons.verified_user_rounded, 'Verified Doctors Only', const Color(0xFF14B1FF)),
                          const SizedBox(height: 14),
                          _trust(Icons.medical_services_rounded, 'Complete Virtual Hospital', const Color(0xFFF59E0B)),
                          const SizedBox(height: 14),
                          _trust(Icons.people_rounded, 'Trusted by Patients Nationwide', const Color(0xFFFF4D00)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _circle(double size, double opacity) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      );

  Widget _trust(IconData icon, String text, Color iconColor) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      );

  // ── Right form panel ─────────────────────────────────────────────────────
  Widget _buildRightPanel() => Container(
        color: const Color(0xFFF8FAFD),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Container(
              width: 480,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 44),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF0036BC).withValues(alpha: 0.06), blurRadius: 40, offset: const Offset(0, 16)),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isPatient ? 'Create Your Account' : 'Join as ${widget.role}',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF0B2D6E), fontFamily: 'Gilroy-Bold', letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isPatient ? 'Sign up for a better healthcare experience' : _roleDescription,
                      style: TextStyle(fontSize: 14, color: Colors.grey[500], fontFamily: 'Gilroy-Medium'),
                    ),
                    const SizedBox(height: 28),
                    ..._buildFields(),
                    const SizedBox(height: 8),
                    _submitBtn(),
                    const SizedBox(height: 20),
                    _signInLink(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            const Expanded(flex: 5, child: AuthLeftPanel()),
            Expanded(flex: 5, child: _buildRightPanel()),
          ],
        ),
      );
    }


    // Mobile — same layout as login mobile
    return Scaffold(
      body: Container(
        width: Utils.windowWidth(context),
        height: Utils.windowHeight(context),
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage(ImagePaths.backgroundImage),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.25),
              BlendMode.darken,
            ),
          ),
        ),
        child: Stack(
          children: [
            // Top text area with dark overlay for better readability
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 60,
                left: 20,
                right: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isPatient ? 'Create Your Account' : 'Join as ${widget.role}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0036BC),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sign up to enjoy the best healthcare experience',
                    style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            // Bottom form container
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                height: Utils.windowHeight(context) * 0.72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.97),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ..._buildFields(),
                        const SizedBox(height: 8),
                        _submitBtn(height: 50),
                        const SizedBox(height: 20),
                        _signInLink(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Back button
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_rounded, color: Color(0xFF0036BC), size: 15),
                      SizedBox(width: 5),
                      Text('Back', style: TextStyle(color: Color(0xFF0036BC), fontSize: 12, fontWeight: FontWeight.w700)),
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
