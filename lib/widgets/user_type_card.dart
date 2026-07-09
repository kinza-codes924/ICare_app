import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/layout.dart';

class UserTypeCard extends StatelessWidget {
  const UserTypeCard({
    super.key,
    required this.title,
    required this.description,
    required this.onPressed,
    required this.image,
    this.isSelected = false,
    this.benefits = const [],
  });
  final String title;
  final GestureTapCallback onPressed;
  final String description;
  final String image;
  final bool isSelected;
  final List<String> benefits;
  @override
  Widget build(BuildContext context) {
    print("object === > ${Utils.windowWidth(context)}");
    final isMobile = ResponsiveHelper.isMobile(context);
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    final is4KScreen = ResponsiveHelper.is4KScreen(context);

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        // height: (isDesktop || isTablet || is4KScreen ) ? ScallingConfig.scale(80): null ,
        margin: EdgeInsets.only(top: ScallingConfig.verticalScale(10)),
        width: ResponsiveHelper.isMobile(context)
            ? Utils.windowWidth(context) * 0.85
            : null,
        clipBehavior: Clip.hardEdge,

        decoration: BoxDecoration(
          color: isDesktop || isTablet || is4KScreen
              ? AppColors.white
              : AppColors.grayColor.withAlpha(20),
          //  color: AppColors.grayColor.withAlpha(20),
          border: isSelected
              ? Border.all(width: 2, color: AppColors.primaryColor)
              : null,
          borderRadius: BorderRadius.circular(20),
        ),
        child: LayoutWidget(
          horizontal: isMobile,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (!isMobile) ...[
              Flexible(
                child: SizedBox(
                  width: Utils.windowWidth(context) * 0.15,
                  height: isTablet
                      ? Utils.windowWidth(context) * 0.35
                      : Utils.windowWidth(context) * 0.15,
                  child: Image.asset(image, fit: BoxFit.contain),
                ),
              ),
            ],
            if (isMobile) ...[SizedBox(width: ScallingConfig.scale(40))],
            Column(
              crossAxisAlignment: isMobile
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                CustomText(
                  text: title,
                  isBold: true,
                  fontSize: isMobile ? 18 : 20,
                ),
                CustomText(
                  text: description,
                  width: isMobile ? Utils.windowWidth(context) * 0.4 : null,
                  maxLines: 4,
                  textAlign: isMobile ? TextAlign.start : TextAlign.center,
                  fontSize: isMobile ? 13 : 14,
                  color: Colors.grey[700],
                ),
                if (benefits.isNotEmpty) ...[
                  SizedBox(height: isMobile ? 8 : 12),
                  ...benefits
                      .map(
                        (benefit) => Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: isMobile
                                ? MainAxisAlignment.start
                                : MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: AppColors.primaryColor,
                              ),
                              SizedBox(width: 6),
                              CustomText(
                                text: benefit,
                                fontSize: isMobile ? 11 : 12,
                                color: Colors.grey[600],
                              ),
                            ],
                          ),
                        ),
                      )
                      ,
                ],
              ],
            ),
            SizedBox(
              width: isMobile
                  ? Utils.windowWidth(context) * 0.1
                  : ScallingConfig.scale(30),
            ),
            if (isMobile) ...[
              Flexible(
                child: SizedBox(
                  width: Utils.windowWidth(context) * 0.25,
                  height: Utils.windowWidth(context) * 0.4,
                  child: Image.asset(image, fit: BoxFit.cover),
                ),
              ),
            ],
            SizedBox(width: Utils.windowWidth(context) * 0.025),
          ],
        ),
      ),
    );
  }
}
