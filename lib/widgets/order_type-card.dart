import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/models/app_enums.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/svg_wrapper.dart';

class OrderTypecard extends StatelessWidget {
  const OrderTypecard({
    super.key,
    required this.type,
    required this.title,
    this.onTap,
  });
  final OrderType type;
  final String title;
  final void Function()? onTap;
  @override
  Widget build(BuildContext context) {
    var icon = type == OrderType.recent
        ? ImagePaths.recent_orders
        : type == OrderType.delivered
        ? ImagePaths.delievered_orders
        : type == OrderType.cancelled
        ? ImagePaths.cancelled_orders
        : ImagePaths.transit_orders;

    return GestureDetector(
      behavior: HitTestBehavior.opaque, // taps on the transparent padding were being dropped
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: Utils.windowHeight(context) * 0.27,
        padding: EdgeInsets.symmetric(
          vertical: ScallingConfig.verticalScale(10),
          horizontal: ScallingConfig.scale(10),
        ),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              blurStyle: BlurStyle.inner,
              spreadRadius: 5,
              blurRadius: 7,
              color: AppColors.lightGrey200.withAlpha(90),
              offset: const Offset(1, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: ScallingConfig.verticalScale(10)),
            SvgWrapper(
              assetPath: icon,
              width: double.infinity,
              height: ScallingConfig.scale(115),
            ),
            SizedBox(height: ScallingConfig.verticalScale(20)),
            CustomText(
              text: title,
              fontFamily: "Gilroy-Bold",
              width: double.infinity,
              fontWeight: FontWeight.w400,
              fontSize: 12,
              textAlign: TextAlign.center,
              color: AppColors.primary500,
              lineHeight: 1.0,
              letterSpacing: -0.3,
            ),
          ],
        ),
      ),
    );
  }
}
