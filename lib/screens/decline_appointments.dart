import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/custom_text_input.dart';

class DeclineAppointments extends StatefulWidget {
  const DeclineAppointments({super.key, this.fromBooking = false});
  final bool fromBooking;

  @override
  State<DeclineAppointments> createState() => _DeclineAppointmentsState();
}

class _DeclineAppointmentsState extends State<DeclineAppointments> {
  String? selectedReason;

  final List<String> reasons = [
    "Schedule Change",
    "Weather conditions",
    "Unexpected Work",
    "Childcare Issue",
    "Travel Delays",
    "Other",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: CustomBackButton(),
        title: CustomText(
          text: "Decline Appointments",
          fontSize: 16.78,
          fontFamily: "Gilroy-Bold",
          fontWeight: FontWeight.w400,
          color: AppColors.primary500,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: ScallingConfig.scale(10)),
            CustomText(
              text: "Please select the reason for cancellations.",
              fontFamily: "Gilroy-Medium",
              fontSize: ScallingConfig.moderateScale(16),
              color: AppColors.themeDarkGrey,
            ),
            RadioGroup<String>(
              groupValue: selectedReason,
              onChanged: (value) {
                setState(() {
                  selectedReason = value!;
                });
              },

              child: Column(
                children: reasons.map((reason) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6.0,
                      horizontal: 6,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Radio(
                          activeColor: AppColors.primaryColor,
                          value: reason,
                        ),
                        Expanded(
                          child: CustomText(
                            padding: EdgeInsets.only(top: 1),
                            text: reason,
                            fontFamily: "Gilroy-Medium",
                            // isBold: true,
                            fontSize: ScallingConfig.moderateScale(16),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            CustomInputField(
              title: "Other",
              hintText: "Enter your reason",
              hintStyle: TextStyle(
                fontFamily: "Gilroy-Medium",
                color: AppColors.grayColor.withAlpha(85),
              ),
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              height: Utils.windowHeight(context) * 0.15,
              width: Utils.windowWidth(context) * 0.9,
              borderRadius: 20,
              maxLines: 20,
              borderColor: AppColors.grayColor.withAlpha(70),
            ),
            SizedBox(height: ScallingConfig.scale(12)),
            CustomButton(
              label: "Decline",
              width: Utils.windowWidth(context) * 0.9,
              borderRadius: ScallingConfig.moderateScale(30),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
