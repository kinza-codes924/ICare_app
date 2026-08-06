import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icare/models/user.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/screens/classroom_course_view.dart';
import 'package:icare/screens/select_payment_method.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/utils/shared_pref.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/recaptcha.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/recaptcha_checkbox.dart';

/// LMS Purchase Flow - Simple signup → Payment → Limited Access
/// Step 1: Check if user is logged in
/// Step 2: If not, show simple signup form
/// Step 3: Process payment
/// Step 4: Grant limited access (only this course)
/// Step 5: Request document upload for verification
class LmsPurchaseFlow extends ConsumerStatefulWidget {
  final Map<String, dynamic> course;

  const LmsPurchaseFlow({super.key, required this.course});

  @override
  ConsumerState<LmsPurchaseFlow> createState() => _LmsPurchaseFlowState();
}

class _LmsPurchaseFlowState extends ConsumerState<LmsPurchaseFlow> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _checkingLogin = true; // true while token check is in progress
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoggedIn = false;
  // Hard guard against double-tap before setState rebuild
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    final token = await SharedPref().getToken();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = token != null && token.isNotEmpty;
      _checkingLogin = false;
    });

    if (_isLoggedIn && token != null) {
      _api.forceSetToken(token);
      _proceedToPayment();
    }
  }

  Future<void> _handleSignupAndPurchase() async {
    // Hard guard: prevent any concurrent submissions
    if (_submitting || _isLoading) return;
    // Safe null check — form may have been disposed if login check raced ahead
    if (_formKey.currentState?.validate() != true) return;

    String? recaptchaToken;
    try {
      recaptchaToken = await getRecaptchaResponse();
    } catch (_) {
      recaptchaToken = null;
    }

    _submitting = true;
    setState(() => _isLoading = true);

    try {
      final signupResponse = await _api.post('/auth/register', {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'password': _passwordController.text,
        'role': 'Student',
        if (recaptchaToken != null) 'recaptchaToken': recaptchaToken,
      });

      if (signupResponse.data['success'] == true) {
        final token = signupResponse.data['token']?.toString()
            ?? signupResponse.data['data']?['token']?.toString()
            ?? signupResponse.data['accessToken']?.toString();

        if (token == null || token.isEmpty) {
          throw Exception('Account created but no token received. Please log in.');
        }

        await SharedPref().setToken(token);
        await SharedPref().setUserRole('Student');
        _api.forceSetToken(token);

        // Build user object from response (or form data as fallback) and store
        // in authProvider so the dashboard shows the real name instead of "User"
        final rawUser = signupResponse.data['user']
            ?? signupResponse.data['data']?['user']
            ?? signupResponse.data['data'];
        final user = rawUser is Map<String, dynamic>
            ? User.fromJson(rawUser)
            : User(
                id: signupResponse.data['_id']?.toString() ?? '',
                name: _nameController.text.trim(),
                email: _emailController.text.trim(),
                phoneNumber: _phoneController.text.trim(),
                role: 'Student',
              );
        await ref.read(authProvider.notifier).setUser(user);

        if (mounted) _proceedToPayment();
      } else {
        throw Exception(signupResponse.data['message'] ?? 'Signup failed');
      }
    } catch (e) {
      _submitting = false;
      if (!mounted) return;
      setState(() => _isLoading = false);

      // Extract a human-readable message from DioException or plain Exception
      String msg = 'Signup failed. Please try again.';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map) {
          msg = data['message']?.toString() ?? data['error']?.toString() ?? msg;
        }
      } else {
        msg = e.toString().replaceAll('Exception: ', '');
      }

      // Detect "already exists" → suggest login
      final lower = msg.toLowerCase();
      final alreadyExists = lower.contains('already') || lower.contains('exists') || lower.contains('duplicate') || e is DioException && e.response?.statusCode == 409;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(alreadyExists
              ? 'This email is already registered. Please log in instead.'
              : msg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: alreadyExists
              ? SnackBarAction(
                  label: 'Login',
                  textColor: Colors.white,
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                )
              : null,
        ),
      );
    }
  }

  // Amount shown on the payment screen. This is display-only — the server
  // re-computes the real charge in payments.js — so it just needs to match
  // what will actually be charged.
  double _displayAmount() {
    double toNum(dynamic v) =>
        (v is num) ? v.toDouble() : (double.tryParse('${v ?? ''}') ?? 0.0);

    final base = toNum(widget.course['price'] ?? widget.course['cost']);
    // discountedPrice only counts when it's a real positive value — a stored
    // 0 must NOT wipe out the price (that was the "PKR 0 on payment screen"
    // bug: `0 ?? price` returns 0 because 0 isn't null).
    final rawDiscounted = widget.course['discountedPrice'];
    final discounted = (rawDiscounted is num && rawDiscounted > 0)
        ? rawDiscounted.toDouble()
        : null;

    // Server sends the after-early-bird price as effectivePrice when present.
    final rawEffective = widget.course['effectivePrice'];
    double effective = (rawEffective is num && rawEffective > 0)
        ? rawEffective.toDouble()
        : (discounted ?? base);

    // Installment-enabled → the purchase pays only the FIRST installment.
    if (widget.course['installmentPlanEnabled'] == true) {
      final plan = widget.course['installmentPlan'];
      if (plan is List && plan.isNotEmpty) {
        return toNum((plan.first as Map?)?['amount']);
      }
    }
    return effective;
  }

  void _proceedToPayment() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SelectPaymentMethod(
          amount: _displayAmount(),
          onPaymentSuccess: _handlePaymentSuccess,
          courseId: widget.course['_id'],
        ),
      ),
    );
  }

  // Called from SelectPaymentMethod, which is the screen actually visible
  // (and mounted) at this point — LmsPurchaseFlow was already replaced by
  // it via pushReplacement, so navigation must happen using the caller's
  // context, not this widget's own (already-disposed) context.
  Future<void> _handlePaymentSuccess(BuildContext callerContext, {String? voucherCode}) async {
    try {
      // Enroll user in course
      final res = await _api.post('/courses/enrollments', {
        'courseId': widget.course['_id'],
        if (voucherCode != null && voucherCode.isNotEmpty) 'voucherCode': voucherCode,
      });

      // Go straight to the course classroom — a normal course purchase should
      // never require a separate identity/document verification gate before
      // granting access to content the student already paid for. That gate
      // (LmsDocumentUpload → LmsLimitedDashboard) is a purpose-built LMS
      // credential-verification feature meant for courses that explicitly
      // require it, not a blanket step for every enrollment.
      if (callerContext.mounted) {
        final enrollment = res.data is Map ? res.data['enrollment'] : null;
        final enrollmentId = enrollment is Map ? enrollment['_id']?.toString() : null;
        Navigator.pushReplacement(
          callerContext,
          MaterialPageRoute(
            builder: (_) => ClassroomCourseView(
              course: widget.course,
              enrollmentId: enrollmentId,
              isInstructor: false,
            ),
          ),
        );
      }
    } catch (e) {
      if (callerContext.mounted) {
        ScaffoldMessenger.of(callerContext).showSnackBar(
          SnackBar(
            content: Text('Enrollment failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const CustomBackButton(),
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Complete Your Purchase',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Course Summary Card
            _buildCourseSummary(),
            const SizedBox(height: 32),
            
            // Signup Form
            _buildSignupForm(),
            const SizedBox(height: 24),
            
            // Purchase Button
            _buildPurchaseButton(),
            const SizedBox(height: 16),
            
            // Login Link
            _buildLoginLink(),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryColor,
                    AppColors.primaryColor.withValues(alpha: 0.7),
                  ],
                ),
              ),
              child: const Icon(Icons.school, size: 40, color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          
          // Course Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.course['title'] ?? 'Course',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.course['category'] ?? 'General',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignupForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create Your Account',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sign up to access this course and start learning',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),
            
            // Name Field
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Email Field
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Address',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Phone Field
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Password Field
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              enableInteractiveSelection: true,
              contextMenuBuilder: (context, editableTextState) =>
                  AdaptiveTextSelectionToolbar.editableText(
                    editableTextState: editableTextState,
                  ),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Confirm Password Field
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              enableInteractiveSelection: true,
              contextMenuBuilder: (context, editableTextState) =>
                  AdaptiveTextSelectionToolbar.editableText(
                    editableTextState: editableTextState,
                  ),
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseButton() {
    final busy = _isLoading || _checkingLogin;
    return Column(
      children: [
        const Center(child: RecaptchaCheckbox()),
        const SizedBox(height: 16),
        _buildPurchaseButtonInner(busy),
      ],
    );
  }

  Widget _buildPurchaseButtonInner(bool busy) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: busy ? null : _handleSignupAndPurchase,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: busy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Sign Up & Continue to Payment',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Already have an account? ',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pushNamed(context, '/login');
          },
          child: const Text(
            'Login',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF6366F1),
            ),
          ),
        ),
      ],
    );
  }
}
