import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/svg_wrapper.dart';

class PaymentMethodCard extends StatelessWidget {
  const PaymentMethodCard({
    super.key,
    required this.type,
    required this.number,
    required this.expiry,
    required this.logo,
    required this.onTap,
  });

  final String? type;
  final String? number;
  final String? expiry;
  final String? logo;
  final GestureTapCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // taps on the transparent padding were being dropped
      onTap: onTap ?? () {},
      child: Container(
        width: Utils.windowWidth(context) * 0.8,
        margin: EdgeInsets.only(top: ScallingConfig.verticalScale(20)),
        padding: EdgeInsets.symmetric(
          horizontal: ScallingConfig.scale(15),
          vertical: ScallingConfig.verticalScale(20),
        ),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              blurStyle: BlurStyle.inner,
              spreadRadius: 5,
              blurRadius: 7,
              color: AppColors.lightGrey200.withAlpha(90),
              offset: Offset(1, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          // mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: Utils.windowWidth(context) * 0.05),
            SvgWrapper(
              assetPath: logo ?? ImagePaths.visa,
              // width: ScallingConfig.scale(25),
              // height: 10,
              // height: ScallingConfig.scale(15),
            ),
            SizedBox(width: Utils.windowWidth(context) * 0.05),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(
                  text: number ?? "",
                  fontSize: 12,
                  color: AppColors.darkGray500,
                  fontWeight: FontWeight.bold,
                ),
                CustomText(
                  text: 'Expires $expiry',
                  textAlign: TextAlign.left,
                  fontSize: 10,
                  color: AppColors.grayColor,
                  fontWeight: FontWeight.bold,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
