import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/widgets/custom_dialog.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:simple_numpad/simple_numpad.dart';

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  var amount = "";

  Widget _buildWebLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: CustomBackButton(),
        automaticallyImplyLeading: false,
        title: CustomText(
          text: "Top Up Wallet",
          fontWeight: FontWeight.bold,
          letterSpacing: -0.31,
          lineHeight: 1.0,
          fontSize: 20,
          fontFamily: "Gilroy-Bold",
          color: AppColors.primaryColor,
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF1F4F9), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  offset: Offset(0, 4),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 40,
                    color: AppColors.primaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Enter Top Up Amount",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                    fontFamily: "Gilroy-Bold",
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "How much would you like to add to your wallet?",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
                ),

                const SizedBox(height: 32),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left side: Amount & Quick Select
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Amount Display / Input Area
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 24,
                              horizontal: 24,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: amount.isNotEmpty
                                    ? AppColors.primaryColor
                                    : const Color(0xFFE2E8F0),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Amount (USD)",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Text(
                                      "\$ ",
                                      style: TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        amount.isEmpty ? "0.00" : amount,
                                        style: TextStyle(
                                          fontSize: 40,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: "Gilroy-Bold",
                                          color: amount.isEmpty
                                              ? const Color(0xFFCBD5E1)
                                              : const Color(0xFF1E293B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Quick Select Buttons
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            alignment: WrapAlignment.start,
                            children: [
                              _buildQuickAmountBtn("50"),
                              _buildQuickAmountBtn("100"),
                              _buildQuickAmountBtn("250"),
                              _buildQuickAmountBtn("500"),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 48),

                    // Right side: Numpad
                    Expanded(
                      flex: 1,
                      child: Center(
                        child: SizedBox(
                          width: 280,
                          child: SimpleNumpad(
                            buttonWidth: 60,
                            buttonHeight: 60,
                            gridSpacing: 16,
                            foregroundColor: Colors.white,
                            backgroundColor: const Color(
                              0xFFF1F5F9,
                            ), // Light grey for buttons
                            buttonBorderRadius: 16,
                            textStyle: const TextStyle(
                              fontSize: 24,
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w600,
                            ),
                            removeBlankButton: true,
                            useBackspace: true,
                            onPressed: (str) {
                              setState(() {
                                if (str == "BACKSPACE") {
                                  if (amount.isNotEmpty) {
                                    amount = amount.substring(
                                      0,
                                      amount.length - 1,
                                    );
                                  }
                                } else {
                                  amount += str;
                                }
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      if (amount.isEmpty) return;
                      CustomDialog.show(
                        context: context,
                        title: 'Success',
                        okText: "Return to Wallet",
                        onOk: () {
                          Navigator.of(context).pop();
                          Navigator.of(
                            context,
                          ).pop(); // pop twice to go back to wallet
                        },
                        descriptionMaxLines: 2,
                        status: DialogStatus.success,
                        descriptionSize: 14,
                        description:
                            "You have successfully transferred \$$amount into your wallet account.",
                      );
                    },
                    child: const Text(
                      "Confirm Transfer",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: "Gilroy-SemiBold",
                      ),
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

  Widget _buildQuickAmountBtn(String val) {
    return InkWell(
      onTap: () => setState(() => amount = val),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          "+\$$val",
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width > 600) {
      return _buildWebLayout(context);
    }

    return Scaffold(
      appBar: AppBar(
        leading: CustomBackButton(),
        automaticallyImplyLeading: false,
        title: CustomText(
          text: "Top Up",
          fontWeight: FontWeight.bold,
          letterSpacing: -0.31,
          lineHeight: 1.0,
          fontSize: 16.78,
          fontFamily: "Gilroy-Bold",
          color: AppColors.primary500,
        ),
      ),

      body: Center(
        child: Column(
          // crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: ScallingConfig.verticalScale(10)),
            CustomText(
              text: "Total Balance",
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
              height: Utils.windowHeight(context) * 0.085,
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(color: AppColors.primary500),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: CustomText(
                  width: double.infinity,
                  text: amount.isEmpty ? "Total Balance" : amount,
                  fontSize: amount.isEmpty ? 18 : 39,
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
              backgroundColor: AppColors.secondaryColor,
              buttonBorderRadius: 35,
              // buttonBorderSide: const BorderSide(
              //     color: Colors.black,
              //     width: 1,
              // ),
              removeBlankButton: true,
              textStyle: TextStyle(
                fontSize: ScallingConfig.moderateScale(28),
                color: AppColors.darkGray500,
              ),
              useBackspace: true,
              // optionText: 'clear',
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
                debugPrint(str);
              },
            ),
            SizedBox(height: ScallingConfig.scale(20)),
            CustomButton(
              label: "Transfer",
              borderRadius: 30,
              width: Utils.windowWidth(context) * 0.85,
              onPressed: () {
                CustomDialog.show(
                  context: context,
                  title: 'Success',
                  okText: "Go Back",
                  onOk: () {
                    Navigator.of(context).pop();
                  },
                  descriptionMaxLines: 2,
                  status: DialogStatus.success,
                  descriptionSize: 14,
                  description:
                      "You have successfully tranfer you $amount in your account.",
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
