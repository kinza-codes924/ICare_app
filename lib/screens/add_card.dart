import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/screens/confirm_details.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/custom_text_input.dart';

class AddCard extends StatefulWidget {
  const AddCard({super.key});

  @override
  State<AddCard> createState() => _AddCardState();
}

class _AddCardState extends State<AddCard> {
  var _cardType = "";
  var _nameOnCard = "";
  var _cardNumber = "";
  var _expiry = "";
  var _cvv = "";

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
        title: CustomText(text: "Add Card".tr()),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              SizedBox(height: ScallingConfig.scale(8)),
              CustomText(
                text: "Add CreditCard ",
                width: Utils.windowWidth(context) * 0.9,
                color: AppColors.primary500,
                fontFamily: "Gilroy-Bold",
                fontWeight: FontWeight.bold,
              ),
              SizedBox(height: ScallingConfig.scale(8)),
              CustomInputField(
                title: "Card Type",
                hintText: "Card Type",
                titleColor: AppColors.tertiaryColor,
                titleFontSize: ScallingConfig.moderateScale(14.78),
                hintStyle: TextStyle(
                  color: AppColors.grayColor,
                  fontFamily: "Gilroy-SemiBold",
                  fontSize: 14,
                ),
                onChanged: (value) {
                  setState(() {
                    _cardType = value;
                  });
                },
                borderRadius: 30,
                borderColor: AppColors.grayColor.withAlpha(70),
                width: Utils.windowWidth(context) * 0.9,
              ),
              CustomInputField(
                title: "Name on Card",
                hintText: "Name on Card",
                titleColor: AppColors.tertiaryColor,
                titleFontSize: ScallingConfig.moderateScale(14.78),
                hintStyle: TextStyle(
                  color: AppColors.grayColor,
                  fontFamily: "Gilroy-SemiBold",
                  fontSize: 14,
                ),
                onChanged: (value) {
                  setState(() {
                    _nameOnCard = value;
                  });
                },
                borderRadius: 30,
                borderColor: AppColors.grayColor.withAlpha(70),
                width: Utils.windowWidth(context) * 0.9,
              ),
              CustomInputField(
                title: "Card Number",
                hintText: "9900 **07 *7550",
                titleColor: AppColors.tertiaryColor,
                titleFontSize: ScallingConfig.moderateScale(14.78),
                hintStyle: TextStyle(
                  color: AppColors.darkGreyColor,
                  fontFamily: "Gilroy-SemiBold",
                  fontSize: 14,
                ),
                onChanged: (value) {
                  setState(() {
                    _cardNumber = value;
                  });
                },
                borderRadius: 30,
                borderColor: AppColors.grayColor.withAlpha(70),
                width: Utils.windowWidth(context) * 0.9,
              ),
              SizedBox(height: ScallingConfig.scale(7)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomInputField(
                    title: "Expriy",
                    hintText: "MM/YY",
                    hintStyle: TextStyle(
                      color: AppColors.grayColor,
                      fontFamily: "Gilroy-SemiBold",
                      fontSize: 14,
                    ),
                    titleColor: AppColors.tertiaryColor,
                    titleFontSize: ScallingConfig.moderateScale(14.78),
                    onChanged: (value) {
                      setState(() {
                        _expiry = value;
                      });
                    },
                    borderRadius: 30,
                    borderColor: AppColors.grayColor.withAlpha(70),
                    width: Utils.windowWidth(context) * 0.44,
                  ),
                  SizedBox(width: ScallingConfig.scale(8)),
                  CustomInputField(
                    title: "CVV",
                    titleColor: AppColors.tertiaryColor,
                    titleFontSize: ScallingConfig.moderateScale(14.78),
                    hintText: "CVV",
                    hintStyle: TextStyle(
                      color: AppColors.grayColor,
                      fontFamily: "Gilroy-SemiBold",
                      fontSize: 14,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _cvv = value;
                      });
                    },
                    borderRadius: 30,
                    borderColor: AppColors.grayColor.withAlpha(70),
                    width: Utils.windowWidth(context) * 0.44,
                  ),
                ],
              ),
              SizedBox(height: ScallingConfig.scale(30)),
              CustomButton(
                label: "Add Card",
                onPressed: () {
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (ctx) => ConfirmDetails()));
                },
                borderRadius: 30,
                width: Utils.windowWidth(context) * 0.9,
              ),
            ],
          ),
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
          text: "Add New Card",
          fontWeight: FontWeight.bold,
          fontSize: 20,
          fontFamily: "Gilroy-Bold",
          color: AppColors.primaryColor,
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Card Details",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Enter your credit or debit card information securely.",
                  style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 32),

                _buildWebField(
                  "Card Type",
                  "e.g. Visa, Mastercard",
                  (v) => _cardType = v,
                ),
                const SizedBox(height: 20),
                _buildWebField(
                  "Name on Card",
                  "Full Name",
                  (v) => _nameOnCard = v,
                ),
                const SizedBox(height: 20),
                _buildWebField(
                  "Card Number",
                  "0000 0000 0000 0000",
                  (v) => _cardNumber = v,
                  isNumber: true,
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: _buildWebField(
                        "Expiry Date",
                        "MM/YY",
                        (v) => _expiry = v,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildWebField(
                        "CVV",
                        "123",
                        (v) => _cvv = v,
                        isPassword: true,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 48),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (ctx) => ConfirmDetails()),
                      );
                    },
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
                    child: const Text(
                      "Save Card Details",
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
                      Icons.verified_user_outlined,
                      size: 16,
                      color: Color(0xFF10B981),
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Your data is protected with bank-grade security.",
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebField(
    String label,
    String hint,
    Function(String) onChanged, {
    bool isNumber = false,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            obscureText: isPassword,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
