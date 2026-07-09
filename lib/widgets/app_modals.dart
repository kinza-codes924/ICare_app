import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/svg_wrapper.dart';

class AppDialogs {
  static void showSuccessDialog(
    BuildContext ctx, {
    String? title,
    String? description,

    bool isShowActions = true,
  }) {
    showDialog(
      context: ctx,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: ScallingConfig.scale(20),
          ),

          constraints: BoxConstraints(
            minWidth: Utils.windowWidth(context) * 0.8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ScallingConfig.scale(20),
              vertical: ScallingConfig.scale(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgWrapper(assetPath: ImagePaths.success),
                CustomText(
                  text: title ?? "Success",
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary500,
                  fontSize: 16.78,
                  fontFamily: "Gilroy-Bold",
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                CustomText(
                  text:
                      description ??
                      "You have complete your profile setup successfully.",
                  textAlign: TextAlign.center,
                  color: AppColors.grayColor,
                  fontSize: 13,
                ),
                const SizedBox(height: 25),
                CustomButton(
                  label: "Gp back",
                  borderRadius: 30,
                  labelColor: AppColors.white,
                  labelSize: 13,
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  width: Utils.windowWidth(context) * 0.8,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void showWarningDialog(
    BuildContext ctx,
    String? title,
    String? description,
    List<String>? options, {
    String primaryText = "Yes",
    String secondaryText = 'No',
    int numOfActions = 1,
    dynamic onPrimaryButtonPressed,
    dynamic onSecondaryButtonPressed,
    String? selectedReason,
    Widget? centerAction,
    bool isShowActions = true,
  }) {
    showDialog(
      context: ctx,
      builder: (BuildContext context) {
        return (Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: ScallingConfig.scale(20),
          ),
          constraints: BoxConstraints(
            minWidth: Utils.windowWidth(context) * 0.8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ScallingConfig.scale(10),
              vertical: ScallingConfig.scale(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgWrapper(assetPath: ImagePaths.warning),
                const SizedBox(height: 20),
                if (centerAction != null) ...[centerAction],
                if (title != null) ...[
                  CustomText(
                    text: title,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary500,
                    fontSize: 16.78,
                    fontFamily: "Gilroy-Bold",
                    maxLines: 2,
                  ),
                ],
                // const SizedBox(height: 8),
                if (description != null) ...[
                  CustomText(
                    text: "You have complete your profile setup successfully.",
                    textAlign: TextAlign.center,
                    color: AppColors.grayColor,
                    fontSize: 13,
                  ),
                ],
                if (options != null) ...[
                  SizedBox(height: ScallingConfig.scale(10)),
                  Options(options: options),
                ],
                SizedBox(height: ScallingConfig.scale(10)),
                if (numOfActions > 1) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomButton(
                        label: primaryText,
                        borderRadius: 30,
                        labelColor: AppColors.white,
                        onPressed: () {
                          print("pressed");
                          Navigator.of(context).pop();
                          onPrimaryButtonPressed();
                        },
                        labelWeight: FontWeight.bold,
                        labelSize: 13,
                        height: ScallingConfig.scale(45),
                        width: Utils.windowWidth(context) * 0.4,
                      ),
                      SizedBox(width: ScallingConfig.scale(10)),
                      CustomButton(
                        label: secondaryText,
                        borderRadius: 30,

                        labelColor: AppColors.primaryColor,
                        borderColor: AppColors.primaryColor,
                        labelWeight: FontWeight.bold,
                        outlined: true,
                        onPressed: () {
                          Navigator.of(context).pop();
                          onSecondaryButtonPressed();
                        },
                        labelSize: 13,
                        height: ScallingConfig.scale(45),
                        width: Utils.windowWidth(context) * 0.4,
                      ),
                    ],
                  ),
                ],

                if (numOfActions == 1) ...[
                  CustomButton(
                    label: primaryText,
                    borderRadius: 30,
                    labelColor: AppColors.white,
                    onPressed: () {
                      print("pressed");
                      onPrimaryButtonPressed();
                      // Navigator.of(context).pop();
                    },
                    labelWeight: FontWeight.bold,
                    // outlined: true,
                    labelSize: 13,
                    // height: ScallingConfig.scale(45),
                    width: Utils.windowWidth(context) * 0.8,
                  ),
                ],

                // SizedBox(height: ScallingConfig.scale(10),)
              ],
            ),
          ),
        ));
      },
    );
  }
}

class Options extends StatefulWidget {
  Options({super.key, this.selectedReason = '', this.options});
  String selectedReason;
  final List<String>? options;
  @override
  State<Options> createState() => _OptionsState();
}

class _OptionsState extends State<Options> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: (widget.options ?? []).map((reason) {
        return Padding(
          padding: EdgeInsets.zero,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Radio<String>(
                activeColor: AppColors.primaryColor,
                value: reason,
                groupValue: widget.selectedReason,
                onChanged: (value) {
                  setState(() {
                    widget.selectedReason = value!;
                  });
                },
              ),
              Expanded(
                child: CustomText(
                  padding: EdgeInsets.only(top: 1),
                  text: reason,
                  fontFamily: "Gilroy-Medium",
                  fontSize: ScallingConfig.moderateScale(16),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
