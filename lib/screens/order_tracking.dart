import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:flutter_steps/flutter_steps.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/svg_wrapper.dart';

class OrderTrackingScreen extends StatelessWidget {
  const OrderTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    List<Steps> basicSteps = [
      Steps(
        leading: SvgWrapper(assetPath: ImagePaths.success),
        title: 'Order APlaced',
        subtitle: '22/9/2025',
        isActive: true,
      ),
      Steps(
        leading: SvgWrapper(assetPath: ImagePaths.success),
        title: 'Order Confirmed',
        subtitle: '',
        isActive: true,
      ),
      Steps(
        leading: SvgWrapper(assetPath: ImagePaths.success),
        title: 'Order Packed',
        subtitle: '',
        isActive: false,
      ),
      Steps(
        leading: SvgWrapper(assetPath: ImagePaths.success),
        title: 'Delivered',
        subtitle: '',
        isActive: false,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: CustomBackButton(),
        automaticallyImplyLeading: false,
        title: CustomText(
          text: 'Order Tracking'.tr(),
          fontFamily: "Gilroy-Bold",
          fontSize: 16.78,
          fontWeight: FontWeight.bold,
          color: AppColors.primary500,
          letterSpacing: -0.31,
          lineHeight: 1.0,
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ScallingConfig.scale(26),
          // vertical: ScallingConfig.scale(16),
        ),
        child: Column(
          spacing: ScallingConfig.scale(6),
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: ScallingConfig.scale(20)),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ScallingConfig.scale(15),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomText(
                        text: "Estimated Time".tr(),
                        fontFamily: "Gilroy-Regular",
                        fontSize: 14.79,
                        color: AppColors.primary500,
                        fontWeight: FontWeight.w400,
                      ),
                      CustomText(
                        text: "1 hour",
                        fontFamily: "Gilroy-Bold",
                        fontSize: 14.79,
                        color: AppColors.primary500,
                        fontWeight: FontWeight.bold,
                      ),
                    ],
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomText(
                        text: "Tracking ID".tr(),
                        fontFamily: "Gilroy-Regular",
                        fontSize: 14.79,
                        color: AppColors.primary500,
                        fontWeight: FontWeight.w400,
                      ),
                      CustomText(
                        text: "28194",
                        fontFamily: "Gilroy-Bold",
                        fontSize: 14.79,
                        color: AppColors.primary500,
                        fontWeight: FontWeight.bold,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: ScallingConfig.scale(10)),
            SizedBox(
              height: Utils.windowHeight(context) * 0.37,
              child: FlutterSteps(
                steps: basicSteps,
                titleFontSize: 12,
                showStepLine: true,
                crossAxisAlignment: CrossAxisAlignment.center,

                titleStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: "Gilroy-SemiBold",
                  color: AppColors.primary500,
                ),
                inactiveStepLineColor: AppColors.lightGrey10,
                leadingSizeFactor: ScallingConfig.scale(1.5),
                hideInactiveLeading: true,
                showSubtitle: true,

                activeStepLineColor: AppColors.themeGreen,
                titleActiveColor: AppColors.primary500,
                subtitleStyle: TextStyle(
                  fontSize: 12,
                  fontFamily: "Gilroy-Medium",
                  color: AppColors.primary500,
                ),
                direction: Axis.vertical,
                inactiveColor: AppColors.lightGrey10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
