import 'dart:developer';
import 'package:go_router/go_router.dart';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/screens/tabs.dart';
import 'package:icare/services/course_service.dart';
import 'package:icare/services/payment_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/custom_button.dart';

/// Checkout screen for courses, appointments and lab bookings.
///
/// Payment methods:
///  • Pay Online (Safepay hosted checkout — card / wallet / Google Pay)
///  • Cash — lab bookings only ("cash at collection": patient pays the
///    collector/lab BEFORE the sample is taken; the lab marks it collected)
class SelectPaymentMethod extends StatefulWidget {
  final String? courseId;
  final String? labBookingId;
  final String? appointmentId;
  final double? amount;
  final void Function(BuildContext context, {String? voucherCode})? onPaymentSuccess;
  // Set when this is paying a specific installment on an already-existing
  // enrollment (installment 2+), not a fresh course purchase.
  final int? installmentIndex;

  const SelectPaymentMethod({
    super.key,
    this.courseId,
    this.labBookingId,
    this.appointmentId,
    this.amount,
    this.onPaymentSuccess,
    this.installmentIndex,
  });

  @override
  State<SelectPaymentMethod> createState() => _SelectPaymentMethodState();
}

class _SelectPaymentMethodState extends State<SelectPaymentMethod> {
  final _courseService = CourseService();
  final _paymentService = PaymentService();
  bool _isLoading = false;
  bool _awaitingGateway = false; // Safepay checkout tab open, polling for result
  bool _pollCancelled = false;
  String _selectedMethod = 'online'; // 'online' | 'cash'

  // Voucher state — only relevant when widget.courseId is set
  final _voucherController = TextEditingController();
  bool _applyingVoucher = false;
  String? _voucherError;
  String? _appliedVoucherCode;
  double? _discountedAmount; // null = no voucher applied, use widget.amount

  double get _finalAmount {
    if (_discountedAmount != null) return _discountedAmount!;
    if (_onlineDiscountApplies && _selectedMethod == 'online') return _onlineDiscountedAmount;
    return widget.amount ?? 0;
  }

  String get _paymentType => widget.installmentIndex != null
      ? 'course_installment'
      : widget.courseId != null
          ? 'course'
          : widget.appointmentId != null
              ? 'appointment'
              : 'lab';

  String get _refId =>
      widget.courseId ?? widget.appointmentId ?? widget.labBookingId ?? '';

  // Cash is offered for lab bookings (pay the collector / pay at the lab)
  // and appointments (pay at the clinic — doctor confirms collection).
  bool get _cashAvailable => widget.labBookingId != null || widget.appointmentId != null;

  // 5% online-payment incentive — appointments only, matches the backend's
  // calculateAmount() discount for method:'safepay' on type:'appointment'.
  bool get _onlineDiscountApplies => widget.appointmentId != null;
  double get _onlineDiscountedAmount =>
      _onlineDiscountApplies ? (widget.amount ?? 0) * 0.95 : (widget.amount ?? 0);

  Future<void> _applyVoucher() async {
    final code = _voucherController.text.trim();
    if (code.isEmpty) return;
    setState(() { _applyingVoucher = true; _voucherError = null; });
    try {
      final res = await _courseService.validateVoucher(code, widget.courseId);
      final discount = (res['discount'] as num?)?.toDouble() ?? 0;
      final discountType = res['discountType']?.toString() ?? 'percent';
      final base = widget.amount ?? 0;
      final discounted = discountType == 'flat'
          ? (base - discount).clamp(0, double.infinity)
          : (base - (base * discount / 100)).clamp(0, double.infinity);
      setState(() {
        _discountedAmount = discounted.toDouble();
        _appliedVoucherCode = code;
        _applyingVoucher = false;
      });
    } catch (e) {
      setState(() {
        _voucherError = e.toString().replaceFirst('Exception: ', '');
        _applyingVoucher = false;
      });
    }
  }

  void _removeVoucher() {
    setState(() {
      _discountedAmount = null;
      _appliedVoucherCode = null;
      _voucherController.clear();
      _voucherError = null;
    });
  }

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
  }

  (String, String) get _successCopy => switch (_paymentType) {
        'course' => (
            'Course Purchased!',
            'You have successfully enrolled in the course. You can now start learning.'
          ),
        'course_installment' => (
            'Installment Paid!',
            'Your payment was received and your course access has been restored (if it was locked).'
          ),
        'appointment' => (
            'Appointment Confirmed!',
            'Your appointment has been booked and payment received. You will receive a confirmation shortly.'
          ),
        _ => (
            'Booking Confirmed!',
            'Your laboratory appointment has been confirmed and paid. Please arrive on time.'
          ),
      };

  Future<void> _processPayment() async {
    if (_refId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid payment request. Please try again."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_selectedMethod == 'cash' && _cashAvailable) {
        await _startCashFlow();
      } else {
        await _startSafepayFlow();
      }
    } on DioException catch (e) {
      log("Payment DioException: ${e.response?.data}");
      if (mounted) {
        String errorMessage = "Payment failed. Please try again.";
        if (e.response?.data is Map && e.response!.data['message'] != null) {
          errorMessage = e.response!.data['message'];
        }
        if (errorMessage.contains("Already purchased") || errorMessage.contains("Already enrolled")) {
          errorMessage = "You have already enrolled in this course. Check 'My Courses' to access it.";
        } else if (errorMessage.contains("Not authorized")) {
          errorMessage = "Please log in to continue.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red, duration: const Duration(seconds: 4)),
        );
      }
    } catch (e) {
      log("Payment error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Payment failed: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Cash flow (lab bookings and appointments): backend records a pending
  /// cash payment and flags the booking — the lab/doctor marks "cash
  /// collected" before sample collection / at the clinic visit.
  Future<void> _startCashFlow() async {
    final res = await _paymentService.createPayment(
      type: _paymentType,
      refId: _refId,
      method: 'cash',
    );
    if (res['success'] == true && mounted) {
      final (title, message) = widget.appointmentId != null
          ? (
              "Appointment Booked — Pay at Clinic",
              "Your appointment is booked. Please pay PKR ${_finalAmount.toStringAsFixed(0)} in cash "
              "at the clinic. The doctor will confirm your payment.",
            )
          : (
              "Booking Placed — Pay Cash",
              "Your lab booking is placed. Please pay PKR ${_finalAmount.toStringAsFixed(0)} in cash "
              "when your sample is collected (or at the lab). The lab will confirm your payment "
              "before collecting the sample.",
            );
      _showSuccessDialog(title, message);
    }
  }

  /// Safepay flow (all types): backend creates the session (amount calculated
  /// server-side) → open hosted checkout → poll until confirmed.
  Future<void> _startSafepayFlow() async {
    final create = await _paymentService.createPayment(
      type: _paymentType,
      refId: _refId,
      voucherCode: _appliedVoucherCode,
      installmentIndex: widget.installmentIndex,
      // Land the checkout tab on our own confirmation page so the user
      // clearly sees the payment succeeded (Safepay's own success flash
      // lasts barely a second before redirecting).
      redirectUrl: kIsWeb ? '${Uri.base.origin}/payment-success' : null,
      cancelUrl: kIsWeb ? '${Uri.base.origin}/payment-cancelled' : null,
    );

    // 100%-voucher / free — no gateway involved.
    if (create['free'] == true) {
      await _finishSuccess();
      return;
    }

    final checkoutUrl = create['checkoutUrl']?.toString();
    final paymentId = create['paymentId']?.toString();
    if (checkoutUrl == null || paymentId == null) {
      throw Exception('Payment gateway did not return a checkout link');
    }

    // Open Safepay hosted checkout (new tab on web, browser on mobile).
    await launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _awaitingGateway = true;
      _pollCancelled = false;
    });

    final paid = await _paymentService.pollUntilPaid(
      paymentId,
      isCancelled: () => _pollCancelled || !mounted,
    );

    if (!mounted) return;
    setState(() => _awaitingGateway = false);

    if (paid) {
      await _finishSuccess();
    } else if (!_pollCancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Payment was not completed. You have not been charged — please try again."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  /// After a confirmed payment (or free enrollment).
  Future<void> _finishSuccess() async {
    if (_paymentType == 'course_installment') {
      // The enrollment already exists — nothing more to create. Just pop
      // back so the caller (installment schedule screen) can refresh.
      if (mounted) Navigator.pop(context, true);
      return;
    }
    if (_paymentType == 'course') {
      if (widget.onPaymentSuccess != null) {
        // The backend has already created the enrollment on payment
        // fulfillment; the flow's own enrollment call is idempotent.
        if (mounted) widget.onPaymentSuccess!(context, voucherCode: _appliedVoucherCode);
        return;
      }
      await _courseService.buyCourse(widget.courseId!, voucherCode: _appliedVoucherCode);
    } else if (widget.onPaymentSuccess != null) {
      if (mounted) widget.onPaymentSuccess!(context, voucherCode: _appliedVoucherCode);
      return;
    }
    if (mounted) {
      final (title, message) = _successCopy;
      _showSuccessDialog(title, message);
    }
  }

  Widget _buildAwaitingGateway() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 28),
            const Text(
              "Complete your payment",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              "A secure Safepay checkout page has opened. Finish your payment there — this screen will update automatically.",
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            TextButton(
              onPressed: () => setState(() {
                _pollCancelled = true;
                _awaitingGateway = false;
              }),
              child: const Text("Cancel payment"),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(32),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 50),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A), fontFamily: "Gilroy-Bold",
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(fontSize: 15, color: Color(0xFF64748B), height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    // For an appointment booking, land on My Appointments —
                    // that's where the patient sees the booking status and
                    // can join once the doctor connects — instead of the
                    // generic dashboard.
                    context.go(widget.appointmentId != null ? '/patient/bookings-history' : '/dashboard');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    widget.appointmentId != null ? "View My Appointments" : "Go to Home",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: "Gilroy-Bold"),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Payment method tiles ────────────────────────────────────────────────────

  Widget _methodTile({
    required String id,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    final selected = _selectedMethod == id;
    return InkWell(
      onTap: () => setState(() => _selectedMethod = id),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primaryColor : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.35)),
                ],
              ),
            ),
            Radio<String>(
              value: id,
              groupValue: _selectedMethod,
              onChanged: (v) => setState(() => _selectedMethod = v ?? 'online'),
              activeColor: AppColors.primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMethodTiles() {
    return [
      _methodTile(
        id: 'online',
        icon: Icons.credit_card_rounded,
        color: const Color(0xFF0036BC),
        title: _onlineDiscountApplies ? 'Pay Now to avail 5% Discount' : 'Pay Online',
        subtitle: 'Credit / Debit Card  •  Wallet  •  Google Pay — secure Safepay checkout',
      ),
      if (_cashAvailable)
        _methodTile(
          id: 'cash',
          icon: Icons.payments_rounded,
          color: const Color(0xFF059669),
          title: widget.appointmentId != null ? 'Pay at the Clinic' : 'Pay Cash at Collection',
          subtitle: widget.appointmentId != null
              ? 'Pay in cash when you arrive at the clinic — full price, no discount'
              : 'Pay in cash when your sample is collected — at home or at the lab',
        ),
    ];
  }

  // ── Layouts ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Utils.windowWidth(context) > 900;
    if (isDesktop) return _buildWebLayout(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        leading: const CustomBackButton(),
        automaticallyImplyLeading: false,
        title: CustomText(
          text: "Select Payment Method",
          fontWeight: FontWeight.bold,
          fontSize: 16.78,
          fontFamily: "Gilroy-Bold",
          letterSpacing: -0.31,
          lineHeight: 1.0,
          color: AppColors.primary500,
        ),
      ),
      body: _awaitingGateway
          ? _buildAwaitingGateway()
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: ScallingConfig.scale(15),
                    vertical: ScallingConfig.verticalScale(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomText(
                        text: "How would you like to pay?",
                        fontFamily: "Gilroy-Bold",
                        fontSize: 14,
                        color: AppColors.primary500,
                      ),
                      const SizedBox(height: 14),
                      ..._buildMethodTiles(),
                      if (widget.courseId != null) ...[
                        const SizedBox(height: 12),
                        _buildVoucherField(),
                      ],
                      const SizedBox(height: 24),
                      CustomButton(
                        label: _selectedMethod == 'cash'
                            ? "Confirm Booking — Cash PKR ${_finalAmount.toStringAsFixed(0)}"
                            : "Confirm & Pay PKR ${_finalAmount.toStringAsFixed(0)}",
                        borderRadius: 35,
                        onPressed: _processPayment,
                      ),
                      const SizedBox(height: 14),
                      const Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
                            SizedBox(width: 6),
                            Text("Secured by Safepay",
                                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  Widget _buildVoucherField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomText(
          text: "Have a voucher code?",
          fontFamily: "Gilroy-Bold",
          fontSize: 14,
          color: AppColors.primary500,
        ),
        const SizedBox(height: 8),
        if (_appliedVoucherCode != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Voucher "$_appliedVoucherCode" applied',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                  ),
                ),
                TextButton(onPressed: _removeVoucher, child: const Text("Remove")),
              ],
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _voucherController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: "Enter voucher code",
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _applyingVoucher ? null : _applyVoucher,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _applyingVoucher
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Apply"),
              ),
            ],
          ),
        if (_voucherError != null) ...[
          const SizedBox(height: 6),
          Text(_voucherError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _buildWebLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: CustomText(
          text: "Checkout & Payment",
          fontWeight: FontWeight.bold,
          fontSize: 20,
          fontFamily: "Gilroy-Bold",
          color: AppColors.primaryColor,
        ),
      ),
      body: _awaitingGateway
          ? _buildAwaitingGateway()
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: SingleChildScrollView(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Payment methods
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Select Payment Method",
                                  style: TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A), letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "Choose how you'd like to pay for your requested services.",
                                  style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 32),
                                ..._buildMethodTiles(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 48),
                          // Order summary
                          Expanded(
                            flex: 1,
                            child: Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 24,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Order Summary",
                                    style: TextStyle(
                                        fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 24),
                                  _buildSummaryItem(
                                    "Service Price",
                                    "PKR ${(widget.amount ?? 0).toStringAsFixed(0)}",
                                  ),
                                  if (_appliedVoucherCode != null)
                                    _buildSummaryItem(
                                      "Voucher ($_appliedVoucherCode)",
                                      "- PKR ${((widget.amount ?? 0) - _finalAmount).toStringAsFixed(0)}",
                                    ),
                                  if (_appliedVoucherCode == null && _onlineDiscountApplies && _selectedMethod == 'online')
                                    _buildSummaryItem(
                                      "5% Online Payment Discount",
                                      "- PKR ${((widget.amount ?? 0) - _onlineDiscountedAmount).toStringAsFixed(0)}",
                                    ),
                                  _buildSummaryItem("Processing Fee", "PKR 0.00"),
                                  const Divider(height: 32, color: Color(0xFFF1F5F9)),
                                  _buildSummaryItem(
                                    "Total",
                                    "PKR ${_finalAmount.toStringAsFixed(0)}",
                                    isTotal: true,
                                  ),
                                  if (widget.courseId != null) ...[
                                    const SizedBox(height: 24),
                                    _buildVoucherField(),
                                  ],
                                  const SizedBox(height: 32),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _processPayment,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 18),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        elevation: 8,
                                        shadowColor: AppColors.primaryColor.withValues(alpha: 0.4),
                                      ),
                                      child: Text(
                                        _selectedMethod == 'cash' ? "Confirm Booking (Cash)" : "Confirm & Pay",
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
                                        SizedBox(width: 6),
                                        Text(
                                          "Secure 256-bit SSL encrypted",
                                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildSummaryItem(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w500,
              color: isTotal ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 22 : 14,
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
              color: isTotal ? AppColors.primaryColor : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
