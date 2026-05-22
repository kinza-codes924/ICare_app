import 'package:flutter/material.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/custom_text.dart';

class CustomButton extends StatelessWidget {
  final String? label;
  final VoidCallback? onPressed;
  final double? width;
  final double? height;
  final double borderRadius;
  final Color? bgColor;
  final Gradient? gradient;
  final Color labelColor;
  final double labelSize;
  final double? labelWidth;
  final FontWeight labelWeight;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final Color iconColor;
  final double iconSize;
  final BoxShadow? boxShadow;
  final EdgeInsetsGeometry? padding;
  final bool disabled;
  final bool outlined;
  final Color? borderColor;
  final double borderWidth;

  const CustomButton({
    super.key,
    this.label,
    this.onPressed,
    this.width,
    this.labelWidth,
    this.height,
    this.bgColor,
    this.gradient,
    this.borderRadius = 12.0,
    this.labelColor = Colors.white,
    this.labelSize = 16,
    this.labelWeight = FontWeight.w600,
    this.leadingIcon,
    this.trailingIcon,
    this.iconColor = Colors.white,
    this.iconSize = 20,
    this.boxShadow,
    this.padding,
    this.disabled = false,
    this.outlined = false,
    this.borderColor,
    this.borderWidth = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasGradient = gradient != null && !outlined;

    return GestureDetector(
      onTap: disabled ? null : onPressed,
      child: Container(
        width: width ?? Utils.windowWidth(context) * 0.8,
        height: height ?? Utils.windowHeight(context) * 0.07,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: hasGradient || outlined && bgColor == null
              ? null
              : (bgColor ?? AppColors.primaryColor),
          gradient: hasGradient
              ? gradient
              : (disabled
                    ? LinearGradient(
                        colors: [Colors.grey.shade400, Colors.grey.shade600],
                      )
                    : (bgColor == null && !outlined
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF0B2D6E), Color(0xFF2255BB)],
                            )
                          : null)),
          borderRadius: BorderRadius.circular(borderRadius),
          border: outlined
              ? Border.all(
                  color: borderColor ?? AppColors.primaryColor,
                  width: borderWidth,
                )
              : null,
          boxShadow: outlined
              ? []
              : [
                  boxShadow ??
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            if (leadingIcon != null) ...[
              leadingIcon!,
              SizedBox(width: label == null ? 0 : 8),
            ],
            if (label != null) ...[
              Flexible(
                child:
                    // Text(
                    //   label,
                    //   overflow: TextOverflow.ellipsis,
                    //   textAlign: TextAlign.center,
                    //   style: TextStyle(
                    //     color: outlined ? (labelColor) : labelColor,
                    //     fontSize: labelSize,
                    //     fontWeight: labelWeight,
                    //   ),
                    // ),
                    CustomText(
                      width: labelWidth,
                      text: label,
                      color: labelColor,
                      fontWeight: labelWeight,
                      fontSize: labelSize,
                    ),
              ),
            ],
            if (trailingIcon != null) ...[
              const SizedBox(width: 8),
              trailingIcon!,
            ],
          ],
        ),
      ),
    );
  }
}
