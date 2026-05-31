import 'package:flutter/material.dart';
import 'package:icare/utils/theme.dart';

class CustomInputField extends StatefulWidget {
  final String? title;
  final String hintText;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final bool isPassword;
  final double? width;
  final double? height;
  final Color? bgColor;
  final Color? borderColor;
  final double borderRadius;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;
  final TextEditingController? controller;
  final Function(String)? onChanged;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool enabled;
  final TextStyle? hintStyle;
  final TextStyle? textStyle;
  final FocusNode? focusNode;
  final bool autoFocus;
  final Color? titleColor;
  final double titleFontSize;
  final FontWeight titleFontWeight;
  final EdgeInsetsGeometry? margin;
  final int? maxLines;
  final BoxBorder? borderType;
  final VoidCallback? onEditingComplete;
  const CustomInputField({
    super.key,
    this.title,
    required this.hintText,
    this.leadingIcon,
    this.trailingIcon,
    this.isPassword = false,
    this.width,
    this.height,
    this.bgColor,
    this.borderColor,
    this.borderRadius = 30,
    this.borderWidth = 1.0,
    this.padding,
    this.controller,
    this.onChanged,
    this.borderType,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.done,
    this.enabled = true,
    this.hintStyle,
    this.textStyle,
    this.focusNode,
    this.maxLines,
    this.autoFocus = false,
    this.titleColor,
    this.titleFontSize = 15,
    this.titleFontWeight = FontWeight.w600,
    this.margin,
    this.onEditingComplete,
  });

  @override
  State<CustomInputField> createState() => _CustomInputFieldState();
}

class _CustomInputFieldState extends State<CustomInputField> {
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: widget.margin ?? const EdgeInsets.symmetric(vertical: 6),
      width: widget.width ?? double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.title != null) ...[
            Text(
              widget.title!,
              style: TextStyle(
                fontFamily: "Gilroy",
                fontWeight: widget.titleFontWeight,
                fontSize: widget.titleFontSize,
                color: widget.titleColor ?? AppColors.primary500,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Container(
            height: widget.height ?? 60,
            padding:
                widget.padding ?? const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: widget.bgColor ?? AppColors.white,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border:
                  widget.borderType ??
                  Border.all(
                    color: widget.borderColor ?? Colors.transparent,
                    width: widget.borderWidth,
                  ),
            ),
            child: Row(
              children: [
                if (widget.leadingIcon != null) ...[
                  widget.leadingIcon!,
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: TextFormField(
                    maxLines: widget.maxLines ?? 1,
                    controller: widget.controller,
                    obscureText: widget.isPassword ? _obscureText : false,
                    onChanged: widget.onChanged,
                    validator: widget.validator,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.textInputAction,
                    focusNode: widget.focusNode,
                    autofocus: widget.autoFocus,
                    enabled: widget.enabled,
                    onEditingComplete: widget.onEditingComplete,
                    style:
                        widget.textStyle ??
                        const TextStyle(
                          fontFamily: "Gilroy",
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                          fontSize: 15,
                        ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: widget.hintText,
                      hintStyle:
                          widget.hintStyle ??
                          TextStyle(
                            color: Colors.grey.shade500,
                            fontFamily: "Gilroy",
                            fontWeight: FontWeight.w400,
                            fontSize: 15,
                          ),
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (widget.trailingIcon != null) ...[
                  widget.trailingIcon!,
                  const SizedBox(width: 10),
                ],
                if (widget.isPassword)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                    child: Icon(
                      _obscureText ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
