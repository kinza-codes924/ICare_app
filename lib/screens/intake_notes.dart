import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';

import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/custom_text_input.dart';
import 'package:icare/widgets/svg_wrapper.dart';

class IntakeNotes extends StatefulWidget {
  const IntakeNotes({super.key});

  @override
  State<IntakeNotes> createState() => _IntakeNotesState();
}

class _IntakeNotesState extends State<IntakeNotes> {
  var _selectedTime = '';
  var _selectedDate = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.primaryColor),
        ),

        title: CustomText(text: "Intake Notes"),
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: ScallingConfig.scale(30)),
            CustomText(
              text: "Create a Treatment Plan",
              fontFamily: "Gilroy-Medium",
              fontSize: ScallingConfig.moderateScale(16),
              color: AppColors.darkGreyColor,
            ),

            CustomInputField(
              hintText: 'Title',
              width: Utils.windowWidth(context) * 0.85,
            ),
            SizedBox(height: ScallingConfig.scale(20)),

            CustomInputField(
              hintText: 'Therapy',
              width: Utils.windowWidth(context) * 0.85,
            ),
            SizedBox(height: ScallingConfig.scale(20)),
            CustomInputField(
              hintText: "Enter your intake notes",
              width: Utils.windowWidth(context) * 0.85,

              height: Utils.windowHeight(context) * 0.15,
              maxLines: 50,
              borderRadius: 20,
              borderColor: AppColors.grayColor.withAlpha(70),
            ),
            SizedBox(height: ScallingConfig.scale(20)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomButton(
                  boxShadow: BoxShadow(offset: Offset(0, 0)),
                  borderRadius: 35,
                  labelWidth: Utils.windowWidth(context) * 0.35,

                  // outlined: true,
                  borderColor: AppColors.veryLightGrey,
                  height: Utils.windowHeight(context) * 0.045,
                  width: Utils.windowWidth(context) * 0.4,
                  bgColor: AppColors.veryLightGrey,

                  label: _selectedDate.isNotEmpty
                      ? _selectedDate
                      : "Select Date",
                  labelColor: AppColors.primaryColor,
                  labelSize: 11,
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      setState(() {
                        _selectedDate = DateFormat("yyyy/MM/dd").format(date);
                      });
                    }
                  },
                  trailingIcon: Align(
                    // alignment: AlignmentGeometry.xy(5, 0),
                    child: SvgWrapper(assetPath: ImagePaths.calendar),
                  ),
                ),
                SizedBox(width: ScallingConfig.scale(10)),
                CustomButton(
                  boxShadow: BoxShadow(offset: Offset(0, 0)),
                  labelWidth: Utils.windowWidth(context) * 0.35,
                  borderRadius: 35,
                  // outlined: true,
                  borderColor: AppColors.veryLightGrey,
                  height: Utils.windowHeight(context) * 0.045,
                  width: Utils.windowWidth(context) * 0.4,
                  bgColor: AppColors.veryLightGrey,
                  label: _selectedTime.isNotEmpty
                      ? _selectedTime
                      : 'Select Time',
                  labelColor: AppColors.primaryColor,
                  labelSize: 11,
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time != null) {
                      setState(() {
                        _selectedTime = time.format(context);
                      });
                    }
                  },
                  trailingIcon: SvgWrapper(assetPath: ImagePaths.clock),
                ),
              ],
            ),
            SizedBox(height: ScallingConfig.scale(10)),
            CustomButton(
              boxShadow: BoxShadow(offset: Offset(0, 0)),
              borderRadius: 35,
              outlined: true,
              borderColor: AppColors.grayColor.withAlpha(50),

              width: Utils.windowWidth(context) * 0.9,
              bgColor: AppColors.veryLightGrey,

              label: 'Upload Prescription',
              labelColor: AppColors.grayColor,
              labelSize: 15,
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
    );
  }
}
