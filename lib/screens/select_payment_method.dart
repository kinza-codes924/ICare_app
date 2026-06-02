import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/screens/add_card.dart';
import 'package:icare/screens/tabs.dart';
import 'package:icare/services/course_service.dart';
import 'package:icare/services/laboratory_service.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/payment_method_card.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/svg_wrapper.dart';
import 'package:icare/widgets/custom_button.dart';

class SelectPaymentMethod extends StatefulWidget {
  final String? courseId;
  final String? labBookingId;
  final String? appointmentId;
  final double? amount;
  final VoidCallback? onPaymentSuccess;

  const SelectPaymentMethod({
    super.key,
    this.courseId,
    this.labBookingId,
    this.appointmentId,
    this.amount,
    this.onPaymentSuccess,
  });

  @override
  State<SelectPaymentMethod> createState() => _SelectPaymentMethodState();
}

class _SelectPaymentMethodState extends State<SelectPaymentMethod> {
  final _courseService = CourseService();
  final _labService = LaboratoryService();
  bool _isLoading = false;
  String? _selectedMethod = "VISA";

  final List<Map<String, String>> paymentMethods = [
    {
      'type': 'VISA',
      'logo': ImagePaths.apple,
      'number': '**** **** **** 1313',
      'expiry': '08/26',
    },
    {
      'type': 'MasterCard',
      'logo': ImagePaths.mc,
      'number': '**** **** **** 1313',
      'expiry': '08/26',
    },
    {
      'type': 'Amex',
      'logo': ImagePaths.gpay,
      'number': '**** **** **** 1313',
      'expiry': '08/26',
    },
    {
      'type': 'VISA',
      'logo': ImagePaths.visa,
      'number': '**** **** **** 1313',
      'expiry': '08/26',
    },
  ];

  Future<void> _processPayment() async {
    // Validate inputs
    if (widget.courseId == null && widget.labBookingId == null && widget.appointmentId == null) {
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
      // Simulate real-world payment processing delay
      await Future.delayed(const Duration(seconds: 2));

      if (widget.appointmentId != null) {
        // Appointment payment — simulate success
        if (mounted) {
          _showSuccessDialog(
            "Appointment Confirmed!",
            "Your appointment has been booked and payment received. You will receive a confirmation shortly.",
          );
        }
      } else if (widget.courseId != null) {
        log("Attempting to buy course with ID: ${widget.courseId}");

        // Validate courseId is not empty
        if (widget.courseId!.isEmpty) {
          throw Exception("Invalid course ID");
        }

        await _courseService.buyCourse(widget.courseId!);
        if (mounted) {
          _showSuccessDialog(
            "Course Purchased!",
            "You have successfully enrolled in the course. You can now start learning.",
          );
        }
      } else if (widget.labBookingId != null) {
        // Update booking status to 'confirmed' or similar if needed
        await _labService.updateBooking(widget.labBookingId!, {
          'status': 'confirmed',
        });
        if (mounted) {
          _showSuccessDialog(
            "Booking Confirmed!",
            "Your laboratory appointment has been confirmed and paid. Please arrive on time.",
          );
        }
      } else {
        if (mounted) {
          _showSuccessDialog(
            "Payment Successful",
            "Your transaction was completed successfully.",
          );
        }
      }
    } on DioException catch (e) {
      log("Payment DioException: ${e.response?.data}");
      if (mounted) {
        String errorMessage = "Payment failed. Please try again.";
        if (e.response?.data != null) {
          if (e.response!.data is Map && e.response!.data['message'] != null) {
            errorMessage = e.response!.data['message'];
          }
        }

        // Special handling for common errors
        if (errorMessage.contains("Already purchased")) {
          errorMessage =
              "You have already enrolled in this course. Check 'My Courses' to access it.";
        } else if (errorMessage.contains("Not authorized")) {
          errorMessage = "Please log in to purchase this course.";
        } else if (errorMessage.contains("Course not found")) {
          errorMessage = "This course is no longer available.";
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      log("Payment error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Payment failed: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
              // Success Icon with animation effect
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 50,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  fontFamily: "Gilroy-Bold",
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Message
              Text(
                message,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx); // Close dialog
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TabsScreen(),
                      ),
                      (route) => false, // Remove all previous routes
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Go to Home",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: "Gilroy-Bold",
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Utils.windowWidth(context) > 900;

    if (isDesktop) {
      return _buildWebLayout(context);
    }

    return Scaffold(
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ScallingConfig.scale(15),
                vertical: ScallingConfig.verticalScale(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    text: "Choose Platform ",
                    fontFamily: "Gilroy-Bold",
                    fontSize: 14,
                    color: AppColors.primary500,
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: paymentMethods.length,
                      itemBuilder: (ctx, i) {
                        final item = paymentMethods[i];
                        return (PaymentMethodCard(
                          onTap: () {
                            // Select the card and then allow payment
                            setState(() => _selectedMethod = item['type']);
                          },
                          expiry: item['expiry'],
                          number: item['number'],
                          type: item['type'],
                          logo: item['logo'],
                        ));
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  CustomButton(
                    label: "Confirm & Pay PKR ${widget.amount ?? 0}",
                    borderRadius: 35,
                    onPressed: _processPayment,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1100),
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 30,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Payment Content
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Select Payment Method",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Choose how you'd like to pay for your requested services.",
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Payment Method List
                          ...paymentMethods.asMap().entries.map((entry) {
                            return _buildWebPaymentCard(context, entry.value);
                          }),

                          const SizedBox(height: 24),

                          // Add new payment method
                          InkWell(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) => const AddCard(),
                              ),
                            ),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.primaryColor.withValues(
                                    alpha: 0.3,
                                  ),
                                  style: BorderStyle.solid,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                color: AppColors.primaryColor.withValues(alpha: 0.04),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_circle_outline_rounded,
                                    color: AppColors.primaryColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "Add New Payment Method",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 48),

                    // Sidebar Summary
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
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildSummaryItem(
                              "Service Price",
                              "PKR ${widget.amount ?? 0}",
                            ),
                            _buildSummaryItem("Processing Fee", "PKR 0.00"),
                            const Divider(height: 32, color: Color(0xFFF1F5F9)),
                            _buildSummaryItem(
                              "Total",
                              "PKR ${widget.amount ?? 0}",
                              isTotal: true,
                            ),
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _processPayment,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 8,
                                  shadowColor: AppColors.primaryColor
                                      .withValues(alpha: 0.4),
                                ),
                                child: const Text(
                                  "Confirm & Pay",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    size: 14,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    "Secure 256-bit SSL encrypted",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF94A3B8),
                                    ),
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
    );
  }

  Widget _buildWebPaymentCard(BuildContext context, Map<String, String> item) {
    bool isSelected = _selectedMethod == item['type'];
    return InkWell(
      onTap: () => setState(() => _selectedMethod = item['type']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryColor
                : const Color(0xFFF1F5F9),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SvgWrapper(assetPath: item['logo'] ?? ImagePaths.visa),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['type'] ?? "Card",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['number'] ?? "",
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Text(
                  "Exp ${item['expiry']}",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(width: 24),
                Radio(
                  value: item['type'],
                  groupValue: _selectedMethod,
                  onChanged: (val) {
                    setState(() => _selectedMethod = val);
                  },
                  activeColor: AppColors.primaryColor,
                ),
              ],
            ),
          ],
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
              color: isTotal
                  ? const Color(0xFF0F172A)
                  : const Color(0xFF64748B),
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
