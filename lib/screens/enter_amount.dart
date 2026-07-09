import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/widgets/custom_dialog.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:simple_numpad/simple_numpad.dart';

class EnterAmountScreen extends StatefulWidget {
  const EnterAmountScreen({super.key});

  @override
  State<EnterAmountScreen> createState() => _EnterAmountScreenState();
}

class _EnterAmountScreenState extends State<EnterAmountScreen> {
  var amount = "";

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Utils.windowWidth(context) > 900;

    if (isDesktop) {
      return _buildWebLayout(context);
    }

    return Scaffold(
      appBar: AppBar(
        leading: CustomBackButton(),
        automaticallyImplyLeading: false,
        title: CustomText(
          text: "Enter Amount",
          fontFamily: "Gilroy-Bold",
          fontSize: 20,
        ),
      ),
      body: Center(
        child: Column(
          children: [
            SizedBox(height: ScallingConfig.verticalScale(10)),
            CustomText(
              text: "Enter the amount",
              width: Utils.windowWidth(context) * 0.85,
              fontFamily: "GIlroy-Bold",
              fontSize: 14,
            ),
            Container(
              margin: EdgeInsets.only(top: ScallingConfig.verticalScale(8)),
              padding: EdgeInsets.symmetric(
                vertical: ScallingConfig.verticalScale(5),
                horizontal: ScallingConfig.scale(5),
              ),
              width: Utils.windowWidth(context) * 0.85,
              height: Utils.windowHeight(context) * 0.06,
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(color: AppColors.primaryColor),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Center(
                child: CustomText(
                  width: double.infinity,
                  text: amount.isEmpty ? "Enter Amount" : amount,
                  fontSize: amount.isEmpty ? 18 : 24,
                  fontFamily: "Gilroy-Bold",
                  color: amount.isEmpty
                      ? AppColors.tertiaryColor
                      : AppColors.primary500,
                ),
              ),
            ),
            SizedBox(height: ScallingConfig.scale(20)),
            SimpleNumpad(
              buttonWidth: 70,
              buttonHeight: 70,
              gridSpacing: 40,
              foregroundColor: AppColors.white,
              backgroundColor: AppColors.veryLightGrey,
              buttonBorderRadius: 35,
              removeBlankButton: true,
              textStyle: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: ScallingConfig.moderateScale(28),
                color: AppColors.darkGray500,
              ),
              useBackspace: true,
              onPressed: (str) {
                setState(() {
                  if (str == "BACKSPACE") {
                    if (amount.isNotEmpty) {
                      amount = amount.substring(0, amount.length - 1);
                    }
                  } else {
                    amount += str;
                  }
                });
              },
            ),
            SizedBox(height: ScallingConfig.scale(20)),
            CustomButton(
              label: "Done",
              borderRadius: 30,
              width: Utils.windowWidth(context) * 0.85,
              onPressed: () {
                CustomDialog.show(
                  context: context,
                  title: 'Successful',
                  okText: "Enjoy",
                  onOk: () {
                    Navigator.of(context).pop();
                  },
                  descriptionMaxLines: 2,
                  status: DialogStatus.success,
                  descriptionSize: 14,
                  description:
                      "You have Successfully bought full course, Enjoy!",
                );
              },
            ),
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
          text: "Complete Payment",
          fontWeight: FontWeight.bold,
          fontSize: 20,
          fontFamily: "Gilroy-Bold",
          color: AppColors.primaryColor,
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(48),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                size: 64,
                color: AppColors.primaryColor,
              ),
              const SizedBox(height: 24),
              const Text(
                "Enter Payment Amount",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Verify the amount to be deducted from your chosen method.",
                style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Animated style for amount display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primaryColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Center(
                  child: Text(
                    amount.isEmpty ? "PKR 0.00" : "PKR $amount",
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: amount.isEmpty
                          ? const Color(0xFF94A3B8)
                          : AppColors.primaryColor,
                      fontFamily: "Gilroy-Bold",
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // Custom styled numpad for web
              Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: [
                  ...List.generate(
                    9,
                    (index) => _buildWebNumButton("${index + 1}"),
                  ),
                  _buildWebNumButton("0"),
                  _buildWebNumButton(".", isDot: true),
                  _buildWebNumButton("⌫", isBack: true),
                ],
              ),

              const SizedBox(height: 60),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    CustomDialog.show(
                      context: context,
                      title: 'Payment Successful',
                      okText: "Go to Dashboard",
                      onOk: () {
                        // In a real app we'd navigate to course list/dashboard
                        Navigator.of(context).pop();
                      },
                      descriptionMaxLines: 2,
                      status: DialogStatus.success,
                      descriptionSize: 14,
                      description:
                          "Congratulations! You have unlocked the full course content. Start learning now!",
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 10,
                    shadowColor: AppColors.primaryColor.withValues(alpha: 0.4),
                  ),
                  child: const Text(
                    "Pay Now",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
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

  Widget _buildWebNumButton(
    String text, {
    bool isBack = false,
    bool isDot = false,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          if (isBack) {
            if (amount.isNotEmpty) {
              amount = amount.substring(0, amount.length - 1);
            }
          } else {
            if (amount.length < 10) amount += text;
          }
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 80,
        height: 60,
        decoration: BoxDecoration(
          color: isBack ? Colors.redAccent.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isBack ? Colors.redAccent : const Color(0xFF1E293B),
            ),
          ),
        ),
      ),
    );
  }
}
