import 'dart:async';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/services/auth_service.dart';
import 'package:icare/utils/theme.dart';

/// Six-digit code sent to the address entered at signup, proving the person
/// actually controls it.
///
/// Not to be confused with the older `email_verification_screen.dart`, which
/// takes a click-through *token* and has no route pointing at it.
class EmailOtpScreen extends ConsumerStatefulWidget {
  final String email;

  /// Runs once the code is accepted, with the fresh token the backend issues.
  final Future<void> Function(String token) onVerified;

  const EmailOtpScreen({
    super.key,
    required this.email,
    required this.onVerified,
  });

  @override
  ConsumerState<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends ConsumerState<EmailOtpScreen> {
  final _code = TextEditingController();
  final _authService = AuthService();

  bool _verifying = false;
  bool _resending = false;
  String? _error;
  String? _info;

  // Mirrors the backend's own 60s resend cooldown, so the button is disabled
  // for exactly as long as a retry would be rejected anyway.
  int _cooldown = 60;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
    _code.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _code.removeListener(_onCodeChanged);
    _code.dispose();
    super.dispose();
  }

  /// The code that was last rejected, so auto-submit does not retry it.
  String? _rejectedCode;

  void _onCodeChanged() {
    if (_error != null) setState(() => _error = null);
    final code = _code.text.trim();
    // Auto-submit on the sixth digit -- the code is never longer. But not the
    // same six digits the server has already refused: that re-fired on every
    // keystroke, disabled the field while it ran, and left the user unable to
    // correct a typo. Editing a rejected code clears the block.
    if (code.length == 6 && !_verifying && code != _rejectedCode) {
      _verify();
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
      _info = null;
    });
    try {
      final result = await _authService.verifyEmailOtp(email: widget.email, otp: code);
      if (!mounted) return;
      if (result['success'] == true) {
        final token = (result['data']?['token'] ?? '').toString();
        await widget.onVerified(token);
      } else {
        setState(() {
          _error = result['message']?.toString() ?? 'Invalid code';
          // Remember it so the next keystroke can edit rather than re-submit,
          // and select the digits so typing simply replaces them.
          _rejectedCode = code;
        });
        _code.selection =
            TextSelection(baseOffset: 0, extentOffset: _code.text.length);
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_cooldown > 0 || _resending) return;
    setState(() {
      _resending = true;
      _error = null;
      _info = null;
    });
    try {
      final result = await _authService.resendEmailOtp(widget.email);
      if (!mounted) return;
      if (result['success'] == true) {
        _code.clear();
        _rejectedCode = null;
        setState(() => _info = 'A new code is on its way.');
        _startCooldown();
      } else {
        setState(() => _error = result['message']?.toString() ?? 'Could not resend the code');
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  /// Sign out and return to login.
  ///
  /// Clearing the auth state is what actually releases the screen: the
  /// router's redirect keys off the signed-in user, so without this it would
  /// send them straight back here.
  Future<void> _signOut() async {
    await ref.read(authProvider.notifier).setUserLogout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(Icons.mark_email_unread_outlined,
                            size: 32, color: AppColors.primaryColor),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Verify your email'.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Gilroy-Bold',
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text.rich(
                      TextSpan(
                        text: 'We sent a 6-digit code to\n',
                        children: [
                          TextSpan(
                            text: widget.email,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        fontFamily: 'Gilroy-Medium',
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 26),
                    TextField(
                      controller: _code,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      // Left enabled even while verifying. Disabling it
                      // dropped focus and the keyboard mid-check, so a wrong
                      // code could not be edited until the request finished.
                      // Typing during a check is harmless: the guard above
                      // stops a second submit.
                      readOnly: false,
                      textDirection: ui.TextDirection.ltr,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 12,
                        color: Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '------',
                        hintStyle: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          letterSpacing: 12,
                          fontSize: 30,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(vertical: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: _error != null ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.primaryColor, width: 1.8),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 13,
                                fontFamily: 'Gilroy-Medium',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_info != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF10B981)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _info!,
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 13,
                                fontFamily: 'Gilroy-Medium',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _verifying ? null : _verify,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          disabledBackgroundColor: const Color(0xFFCBD5E1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _verifying
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : Text(
                                'Verify'.tr(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Gilroy-Bold',
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: _cooldown > 0
                          ? Text(
                              'Resend code in ${_cooldown}s',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13,
                                fontFamily: 'Gilroy-Medium',
                              ),
                            )
                          : TextButton(
                              onPressed: _resending ? null : _resend,
                              child: _resending
                                  ? const SizedBox(
                                      width: 16, height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(
                                      "Didn't get it? Resend code",
                                      style: TextStyle(
                                        color: AppColors.primaryColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'Gilroy-Bold',
                                      ),
                                    ),
                            ),
                    ),
                    const SizedBox(height: 6),
                    const Center(
                      child: Text(
                        "Check your spam folder if it hasn't arrived.",
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          fontFamily: 'Gilroy-Medium',
                        ),
                      ),
                    ),
                    // A way out.
                    //
                    // The router sends an unverified user straight back here
                    // from anywhere, and the screen carried no back control, no
                    // sign-out and no app bar -- so a mistyped address, or a
                    // code that never arrives, left the account with nowhere to
                    // go but uninstalling. Verification still cannot be skipped;
                    // this signs out so a different address can be used.
                    const SizedBox(height: 20),
                    Center(
                      child: TextButton(
                        onPressed: _signOut,
                        child: const Text(
                          'Use a different email',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                            fontFamily: 'Gilroy-Medium',
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
