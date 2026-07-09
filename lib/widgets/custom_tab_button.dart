import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/svg_wrapper.dart';

class CustomTabButton extends StatelessWidget {
  const CustomTabButton({
    super.key,
    this.image,
    this.iconColor,
    this.onPressed,
    this.title,
  });
  final String? image;
  final String? title;
  final VoidCallback? onPressed;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    log('png format  ==== ${image!}  ${image!.contains(".png")}');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            onPressed: onPressed,
            icon: image!.contains(".png")
                ? Image.asset(image!, color: iconColor)
                : SvgWrapper(assetPath: image!, color: iconColor),
          ),
          CustomText(text: title),
        ],
      ),
    );
  }
}
