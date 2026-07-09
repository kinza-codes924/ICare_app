import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/screens/cancellation_reason.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/widgets/custom_text.dart';

class ManageOrders extends StatelessWidget {
  const ManageOrders({super.key});

  @override
  Widget build(BuildContext context) {
    final steps = [
      {'title': 'Confirmed Order', 'subtitle': '22/9/2025', 'active': true},
      {'title': 'Pharmacy is preparing your order', 'subtitle': '', 'active': true},
      {'title': 'In Transit', 'subtitle': '', 'active': false},
      {'title': 'Out for Delivery', 'subtitle': '', 'active': false},
      {'title': 'Delivered', 'subtitle': '', 'active': false},
    ];

    return Scaffold(
      appBar: AppBar(
        leading: const CustomBackButton(),
        automaticallyImplyLeading: false,
        title: CustomText(
          text: 'Manage Orders'.tr(),
          fontFamily: "Gilroy-Bold",
          fontSize: 16.78,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.31,
          lineHeight: 1.0,
          color: AppColors.primary500,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: ScallingConfig.scale(20)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: ScallingConfig.scale(15)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomText(text: "Estimated Time", fontFamily: "Gilroy-Regular", fontSize: 14.79, color: AppColors.primary500),
                      CustomText(text: "1 hour", fontFamily: "Gilroy-Bold", fontSize: 14.79, color: AppColors.primary500, fontWeight: FontWeight.bold),
                    ],
                  ),
                  Column(
                    children: [
                      CustomText(text: "Tracking ID", fontFamily: "Gilroy-Regular", fontSize: 14.79, color: AppColors.primary500),
                      CustomText(text: "28194", fontFamily: "Gilroy-Bold", fontSize: 14.79, color: AppColors.primary500, fontWeight: FontWeight.bold),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: ScallingConfig.scale(30)),
            // Steps list
            ...steps.map((step) => Padding(
              padding: EdgeInsets.symmetric(horizontal: ScallingConfig.scale(15), vertical: 6),
              child: Row(
                children: [
                  Icon(
                    step['active'] == true ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: step['active'] == true ? AppColors.themeGreen : AppColors.grayColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomText(text: step['title'] as String, fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary500),
                      if ((step['subtitle'] as String).isNotEmpty)
                        CustomText(text: step['subtitle'] as String, fontSize: 12, color: AppColors.grayColor),
                    ],
                  ),
                ],
              ),
            )),
            SizedBox(height: ScallingConfig.scale(50)),
            CustomButton(label: "Update Status", borderRadius: 40),
            CustomText(
              text: "Cancel order",
              margin: EdgeInsets.only(top: ScallingConfig.scale(10)),
              color: AppColors.themeRed,
              fontSize: 14,
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const CancellationReason()));
              },
              fontFamily: "Gilroy-Bold",
              fontWeight: FontWeight.bold,
            ),
          ],
        ),
      ),
    );
  }
}

