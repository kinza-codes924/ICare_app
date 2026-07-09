import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/custom_text_input.dart';

class WrtieReviewScreen extends StatefulWidget {
  const WrtieReviewScreen({super.key});

  @override
  State<WrtieReviewScreen> createState() => _WrtieReviewScreenState();
}

class _WrtieReviewScreenState extends State<WrtieReviewScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: CustomBackButton(),
        automaticallyImplyLeading: false,
        title: CustomText(
          text: "Write A Review".tr(),
          fontFamily: "Gilroy-Bold",
          fontSize: 16.78,
          color: AppColors.primary500,
          letterSpacing: -0.31,
          lineHeight: 1.0,
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RatingBar.builder(
                initialRating: 4,
                minRating: 1,
                itemSize: ScallingConfig.scale(40),
                direction: Axis.horizontal,
                allowHalfRating: true,
                itemCount: 5,

                itemPadding: EdgeInsets.symmetric(horizontal: 1),
                itemBuilder: (context, _) => Icon(
                  Icons.star,
                  size: ScallingConfig.scale(20),
                  color: AppColors.themeDarkGrey,
                ),
                onRatingUpdate: (rating) {
                  //  debugPrint(rating);
                },
              ),
              SizedBox(height: ScallingConfig.scale(20)),
              CustomInputField(
                hintText: "Type your bio here....",
                width: Utils.windowWidth(context) * 0.85,

                height: Utils.windowHeight(context) * 0.15,
                maxLines: 50,
                borderRadius: 20,
                borderColor: AppColors.grayColor.withAlpha(70),
              ),
              SizedBox(height: ScallingConfig.scale(20)),
              CustomButton(
                label: "Submit",
                width: Utils.windowWidth(context) * 0.9,
                borderRadius: 35,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
