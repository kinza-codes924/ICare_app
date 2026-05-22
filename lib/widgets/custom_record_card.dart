import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';

import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/custom_text.dart';

class CustomRecordCard extends StatelessWidget {
  const CustomRecordCard({
    super.key,
    this.icon,
    this.label,
    this.number,
    this.color = AppColors.secondaryColor,
    this.onTap,
    this.width,
  });

  final String? label;
  final Widget? icon;
  final String? number;
  final Color color;
  final VoidCallback? onTap;
  final double? width;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        width: width ?? Utils.windowWidth(context) * 0.43,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withValues(alpha: 0.85)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            if (icon != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: icon!,
              ),
            SizedBox(height: ScallingConfig.scale(10)),
            CustomText(
              text: number ?? "",
              fontSize: 24,
              fontFamily: "Gilroy-ExtraBold",
              fontWeight: FontWeight.w900,
              color: AppColors.white,
            ),
            const SizedBox(height: 2),
            CustomText(
              text: label ?? "",
              fontSize: 12,
              fontFamily: "Gilroy-SemiBold",
              fontWeight: FontWeight.w600,
              color: AppColors.white.withValues(alpha: 0.9),
            ),
          ],
        ),
      ),
    );
  }
}
