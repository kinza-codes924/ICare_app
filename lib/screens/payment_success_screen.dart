import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icare/utils/theme.dart';

/// Landing page for Safepay's redirect after checkout. Pure information —
/// fulfillment happens via the original tab's polling, the webhook, and the
/// reconcile pass — so this page just tells the user clearly what happened
/// instead of Safepay's one-second flash before a dashboard redirect.
class PaymentSuccessScreen extends StatelessWidget {
  final bool cancelled;
  const PaymentSuccessScreen({super.key, this.cancelled = false});

  @override
  Widget build(BuildContext context) {
    final color = cancelled ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  cancelled ? Icons.cancel_rounded : Icons.check_circle_rounded,
                  color: color,
                  size: 54,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                cancelled ? 'Payment Cancelled' : 'Payment Successful!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  fontFamily: 'Gilroy-Bold',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                cancelled
                    ? 'You cancelled the payment — no money was charged. You can try again anytime.'
                    : 'Your payment has been received. If you still have the iCare tab open, it will '
                      'update automatically — otherwise everything you paid for is being activated '
                      'on your account right now.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Color(0xFF64748B), height: 1.55),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/dashboard'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Go to Dashboard',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'You can safely close this tab.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
