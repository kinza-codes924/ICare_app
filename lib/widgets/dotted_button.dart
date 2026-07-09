import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/custom_text.dart';

class DottedButton extends StatelessWidget {
  const DottedButton({
    super.key,
    required this.onPressed,
    required this.title,
    this.width,
    this.color,
    this.titleSize,
  });
  final String title;
  final double? width;
  final double? titleSize;
  final Color? color;
  final Function() onPressed;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? Utils.windowWidth(context) * 0.8,
      child: DottedBorder(
        options: RoundedRectDottedBorderOptions(
          radius: const Radius.circular(30),
          color: AppColors.grayColor.withAlpha(60),
          dashPattern: const [10, 5],
          strokeWidth: 2,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onPressed,
          child: Container(
            height: 50,
            width: double.infinity,
            alignment: Alignment.center,
            child: CustomText(
              text: title,
              color: color ?? AppColors.grayColor,
              fontSize: titleSize ?? ScallingConfig.moderateScale(12),
            ),
          ),
        ),
      ),
    );
  }
}
