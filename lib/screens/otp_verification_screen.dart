import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/services/auth_verification_service.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

enum _Step { phone, email }

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState
    extends ConsumerState<OtpVerificationScreen> {
  final _svc = AuthVerificationService();

  _Step _step = _Step.phone;
  bool _loading = false;
  bool _sending = false;
  String _errorMsg = '';
  String _infoMsg = '';
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  // Phone step
  final _phoneController = TextEditingController();
  final _phonePinController = TextEditingController();
  String _phoneOtpCode = '';
  bool _otpSent = false;

  // Email step
  final _emailPinController = TextEditingController();
  String _emailOtpCode = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _phoneController.dispose();
    _phonePinController.dispose();
    _emailPinController.dispose();
    super.dispose();
  }

  // ── Bootstrap ──────────────────────────────────────────────────────────────

  Future<void> _bootstrap() async {
    final user = ref.read(authProvider).user;
    if (user == null) { context.go('/login'); return; }
    if (user.isPhoneVerified && user.isEmailVerified) {
      context.go('/dashboard');
      return;
    }

    if (!user.isPhoneVerified && !kIsWeb) {
      _phoneController.text = user.phoneNumber;
      setState(() => _step = _Step.phone);
    } else {
      setState(() => _step = _Step.email);
      await _sendEmailOtp();
    }
  }

  // ── Phone OTP ──────────────────────────────────────────────────────────────

  Future<void> _sendPhoneOtp() async {
    if (_sending) return;
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorMsg = 'Please enter your phone number');
      return;
    }
    setState(() { _sending = true; _errorMsg = ''; _infoMsg = ''; });
    try {
      await _svc.sendPhoneOtp(phone);
      setState(() { _otpSent = true; _infoMsg = 'Code sent to $phone'; });
      _startCooldown();
    } catch (e) {
      setState(() => _errorMsg = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _confirmPhoneOtp() async {
    if (_loading) return;
    if (_phoneOtpCode.length != 6) {
      setState(() => _errorMsg = 'Enter the 6-digit code from your SMS');
      return;
    }
    setState(() { _loading = true; _errorMsg = ''; });
    try {
      await _svc.confirmPhoneOtp(_phoneOtpCode);
      final notifier = ref.read(authProvider.notifier);
      final user = ref.read(authProvider).user!;
      await notifier.setUser(user.copyWith(isPhoneVerified: true));

      final updated = ref.read(authProvider).user!;
      if (!updated.isEmailVerified) {
        setState(() { _step = _Step.email; _infoMsg = ''; _errorMsg = ''; });
        await _sendEmailOtp();
      } else {
        if (mounted) context.go('/dashboard');
      }
    } catch (e) {
      setState(() => _errorMsg = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── Email OTP ──────────────────────────────────────────────────────────────

  Future<void> _sendEmailOtp() async {
    if (_sending) return;
    setState(() { _sending = true; _errorMsg = ''; _infoMsg = ''; });
    try {
      await _svc.sendEmailOtp();
      final email = ref.read(authProvider).user?.email ?? '';
      setState(() => _infoMsg = 'Code sent to $email');
      _startCooldown();
    } catch (e) {
      setState(() => _errorMsg = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _confirmEmailOtp() async {
    if (_loading) return;
    if (_emailOtpCode.length != 6) {
      setState(() => _errorMsg = 'Enter the 6-digit code from your email');
      return;
    }
    setState(() { _loading = true; _errorMsg = ''; });
    try {
      await _svc.confirmEmailOtp(_emailOtpCode);
      final notifier = ref.read(authProvider.notifier);
      final user = ref.read(authProvider).user!;
      await notifier.setUser(user.copyWith(isEmailVerified: true));
      if (mounted) context.go('/dashboard');
    } catch (e) {
      setState(() => _errorMsg = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _startCooldown([int seconds = 60]) {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _resendCooldown--);
      if (_resendCooldown <= 0) t.cancel();
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/Asset 1.png', height: 58,
                      errorBuilder: (_, _, _) => const SizedBox(height: 58)),
                  const SizedBox(height: 28),

                  if (!kIsWeb) ...[
                    _StepBar(onPhone: _step == _Step.phone),
                    const SizedBox(height: 28),
                  ],

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0036BC).withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _step == _Step.phone
                        ? _buildPhoneStep()
                        : _buildEmailStep(),
                  ),

                  if (_errorMsg.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _Banner(message: _errorMsg, isError: true),
                  ],
                  if (_infoMsg.isNotEmpty && _errorMsg.isEmpty) ...[
                    const SizedBox(height: 16),
                    _Banner(message: _infoMsg, isError: false),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Phone step UI ──────────────────────────────────────────────────────────

  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Verify Phone Number',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                color: Color(0xFF0036BC))),
        const SizedBox(height: 6),
        const Text('We\'ll send a 6-digit code via SMS to your phone.',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
        const SizedBox(height: 24),

        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          enabled: !_otpSent,
          decoration: InputDecoration(
            labelText: 'Phone Number',
            hintText: '03XXXXXXXXX',
            prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF0036BC)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0036BC), width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
        const SizedBox(height: 14),

        if (!_otpSent)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: (_sending || _resendCooldown > 0) ? null : _sendPhoneOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0036BC),
                disabledBackgroundColor: const Color(0xFF94A3B8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _sending
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Text('Send OTP',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                          color: Colors.white)),
            ),
          ),

        if (_otpSent) ...[
          const SizedBox(height: 28),
          const Text('Enter the 6-digit SMS code',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: Color(0xFF334155))),
          const SizedBox(height: 12),

          PinCodeTextField(
            appContext: context,
            length: 6,
            controller: _phonePinController,
            keyboardType: TextInputType.number,
            animationType: AnimationType.scale,
            pinTheme: _pinTheme(),
            enableActiveFill: true,
            onChanged: (v) => _phoneOtpCode = v,
            onCompleted: (v) { _phoneOtpCode = v; _confirmPhoneOtp(); },
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _confirmPhoneOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0036BC),
                disabledBackgroundColor: const Color(0xFF94A3B8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Text('Verify Code',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                          color: Colors.white)),
            ),
          ),
          const SizedBox(height: 10),

          Center(
            child: _resendCooldown > 0
                ? Text('Resend in ${_resendCooldown}s',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF94A3B8)))
                : TextButton(
                    onPressed: _sending ? null : () {
                      setState(() {
                        _otpSent = false;
                        _phonePinController.clear();
                        _phoneOtpCode = '';
                      });
                      _sendPhoneOtp();
                    },
                    child: const Text('Resend OTP',
                        style: TextStyle(color: Color(0xFF0036BC),
                            fontWeight: FontWeight.w600)),
                  ),
          ),
        ],
      ],
    );
  }

  // ── Email step UI ──────────────────────────────────────────────────────────

  Widget _buildEmailStep() {
    final email = ref.watch(authProvider).user?.email ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Verify Email Address',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                color: Color(0xFF0036BC))),
        const SizedBox(height: 6),
        Text('We sent a 6-digit code to\n$email',
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
        const SizedBox(height: 28),

        PinCodeTextField(
          appContext: context,
          length: 6,
          controller: _emailPinController,
          keyboardType: TextInputType.number,
          animationType: AnimationType.scale,
          pinTheme: _pinTheme(),
          enableActiveFill: true,
          onChanged: (v) => _emailOtpCode = v,
          onCompleted: (v) { _emailOtpCode = v; _confirmEmailOtp(); },
        ),
        const SizedBox(height: 14),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _loading ? null : _confirmEmailOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0036BC),
              disabledBackgroundColor: const Color(0xFF94A3B8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Text('Verify Email',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                        color: Colors.white)),
          ),
        ),
        const SizedBox(height: 10),

        Center(
          child: _sending
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF0036BC)))
              : _resendCooldown > 0
                  ? Text('Resend in ${_resendCooldown}s',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF94A3B8)))
                  : TextButton(
                      onPressed: _sendEmailOtp,
                      child: const Text('Resend code',
                          style: TextStyle(color: Color(0xFF0036BC),
                              fontWeight: FontWeight.w600)),
                    ),
        ),
      ],
    );
  }

  PinTheme _pinTheme() => PinTheme(
    shape: PinCodeFieldShape.box,
    borderRadius: BorderRadius.circular(10),
    fieldHeight: 52,
    fieldWidth: 44,
    activeFillColor: const Color(0xFFF0F7FF),
    inactiveFillColor: Colors.white,
    selectedFillColor: const Color(0xFFF0F7FF),
    activeColor: const Color(0xFF0036BC),
    inactiveColor: const Color(0xFFCBD5E1),
    selectedColor: const Color(0xFF0036BC),
  );
}

// ── Step indicator bar (mobile only) ──────────────────────────────────────────

class _StepBar extends StatelessWidget {
  final bool onPhone;
  const _StepBar({required this.onPhone});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Dot(label: 'Phone', active: onPhone, done: !onPhone),
        Expanded(
          child: Container(height: 2,
              color: !onPhone
                  ? const Color(0xFF0036BC)
                  : const Color(0xFFCBD5E1)),
        ),
        _Dot(label: 'Email', active: !onPhone, done: false),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final String label;
  final bool active;
  final bool done;
  const _Dot({required this.label, required this.active, required this.done});

  @override
  Widget build(BuildContext context) {
    final color =
        (active || done) ? const Color(0xFF0036BC) : const Color(0xFFCBD5E1);
    return Column(
      children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? const Color(0xFF0036BC) : Colors.white,
            border: Border.all(color: color, width: 2),
          ),
          child: done
              ? const Icon(Icons.check, color: Colors.white, size: 17)
              : active
                  ? Container(
                      margin: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF0036BC)))
                  : null,
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: (active || done)
                    ? FontWeight.w700
                    : FontWeight.w400)),
      ],
    );
  }
}

// ── Info / error banner ────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  final String message;
  final bool isError;
  const _Banner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isError
                ? const Color(0xFFFCA5A5)
                : const Color(0xFF86EFAC)),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError
                ? const Color(0xFFDC2626)
                : const Color(0xFF16A34A),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    fontSize: 13,
                    color: isError
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF15803D))),
          ),
        ],
      ),
    );
  }
}
