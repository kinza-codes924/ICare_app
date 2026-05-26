import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/screens/enter_amount.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/widgets/custom_text.dart';

class ConfirmDetails extends StatelessWidget {
  const ConfirmDetails({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Utils.windowWidth(context) > 900;

    if (isDesktop) {
      return _buildWebLayout(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: CustomText(text: "Confirm Details"),
        leading: CustomBackButton(),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: ScallingConfig.scale(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CustomText(
              text: "Confirmation",
              width: Utils.windowWidth(context),
              fontFamily: "Gilroy-Bold",
              fontSize: 14,
              color: AppColors.primary500,
            ),
            SizedBox(height: Utils.windowHeight(context) * 0.015),
            _buildMobileSummaryItem("Coure Amount", "2000"),
            SizedBox(height: Utils.windowHeight(context) * 0.01),
            _buildMobileSummaryItem("Discounted Offer", "5%"),
            SizedBox(height: Utils.windowHeight(context) * 0.01),
            _buildMobileSummaryItem("Total Amount", "2100"),
            SizedBox(height: Utils.windowHeight(context) * 0.45),
            CustomButton(
              label: "Confirm",
              borderRadius: 40,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const EnterAmountScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileSummaryItem(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CustomText(
          text: label,
          fontFamily: "Gilroy-Regular",
          fontSize: 12,
          color: AppColors.darkGreyColor,
        ),
        CustomText(
          text: value,
          fontFamily: "Gilroy-Bold",
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.darkGreyColor,
        ),
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
          text: "Confirm Order",
          fontWeight: FontWeight.bold,
          fontSize: 20,
          fontFamily: "Gilroy-Bold",
          color: AppColors.primaryColor,
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(40),
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
                    const Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            color: Color(0xFF10B981),
                            size: 60,
                          ),
                          SizedBox(height: 16),
                          Text(
                            "Order Review",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Please review your order details before confirming.",
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF64748B),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    _buildWebSummaryItem("Course Amount", "PKR 2,000"),
                    _buildWebSummaryItem(
                      "Discount Offer",
                      "5% Off",
                      color: const Color(0xFF10B981),
                    ),
                    const Divider(height: 48, color: Color(0xFFF1F5F9)),
                    _buildWebSummaryItem(
                      "Total Amount",
                      "PKR 2,100",
                      isTotal: true,
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => const EnterAmountScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 10,
                          shadowColor: AppColors.primaryColor.withValues(alpha: 0.4),
                        ),
                        child: const Text(
                          "Confirm & Proceed",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 16,
                          color: Color(0xFF94A3B8),
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Secured by iCare payment engine",
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebSummaryItem(
    String label,
    String value, {
    bool isTotal = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 15,
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w500,
              color: isTotal
                  ? const Color(0xFF0F172A)
                  : const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 24 : 15,
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
              color:
                  color ??
                  (isTotal ? AppColors.primaryColor : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}
