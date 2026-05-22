import 'package:flutter/material.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/svg_wrapper.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';

class CustomDropdown<T> extends StatelessWidget {
  final String title;
  final bool showTitle;
  final Color? textColor;
  final T? selectedItem;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final double? width;
  final String? Function(T)? displayField; // how to display each item
  final Widget? icon;
  final Color? borderColor;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const CustomDropdown({
    super.key,
    this.title = "",
    this.showTitle = true,
    required this.items,
    required this.onChanged,
    this.textColor,
    this.selectedItem,
    this.width,
    this.displayField,
    this.icon,
    this.borderColor,
    this.backgroundColor,
    this.margin,
    this.padding,
    this.borderRadius,
  });

  String _getDisplayValue(T item) {
    // If displayField function provided
    if (displayField != null) return displayField!(item) ?? '';

    // If type is Map<String, String>
    if (item is Map<String, dynamic>) {
      if (item.containsKey('title')) return item['title'].toString();
      if (item.containsKey('name')) return item['name'].toString();
      return item.values.first.toString();
    }

    // If it's a model with 'title' or 'name' field
    try {
      final titleField = (item as dynamic).title;
      if (titleField != null) return titleField.toString();
    } catch (_) {}
    try {
      final nameField = (item as dynamic).name;
      if (nameField != null) return nameField.toString();
    } catch (_) {}

    // If it's a String or fallback
    return item.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          margin ?? EdgeInsets.symmetric(horizontal: ScallingConfig.scale(1)),
      child: SizedBox(
        width: width ?? Utils.windowWidth(context) * 0.9,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTitle) ...[
              CustomText(
                text: title,
                isBold: true,
                fontSize: ScallingConfig.moderateScale(14.78),
                color: AppColors.primary500,
                fontWeight: FontWeight.w400,
                fontFamily: "GIlroy-SemiBold",
              ),
              SizedBox(height: ScallingConfig.verticalScale(5)),
            ],
            Container(
              // width: Utils.windowWidth(context) * 0.9,
              padding:
                  padding ??
                  EdgeInsets.symmetric(
                    horizontal: ScallingConfig.scale(10),
                    vertical: ScallingConfig.verticalScale(3),
                  ),
              decoration: BoxDecoration(
                color: backgroundColor ?? AppColors.white,
                border: Border.all(
                  width: 1.2,
                  color: borderColor ?? AppColors.lightGrey100,
                ),

                borderRadius: borderRadius ?? BorderRadius.circular(30),
              ),
              child: DropdownButton<T>(
                isExpanded: true,

                value: selectedItem,
                icon: icon ?? SvgWrapper(assetPath: ImagePaths.arrowDown),
                dropdownColor: AppColors.white,
                underline: Divider(color: AppColors.white),
                style: const TextStyle(color: Colors.black),
                hint: CustomText(
                  text: "Select $title",
                  color: textColor ?? AppColors.primary500,
                ),

                items: items.map((item) {
                  final label = _getDisplayValue(item);
                  return DropdownMenuItem<T>(
                    value: item,
                    child: CustomText(text: label),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
