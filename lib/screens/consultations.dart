import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/screens/my_appointment.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/boooking_card.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/models/appointment_detail.dart';

class Consultations extends StatelessWidget {
  const Consultations({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: CustomText(
          text: "Consultations".tr(),
          fontSize: 16.78,
          fontFamily: "Gilroy-Bold",
          fontWeight: FontWeight.w400,
          color: AppColors.primary500,
        ),
        leading: CustomBackButton(),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          CustomText(text: ""),
          Expanded(
            child: ListView.builder(
              itemCount: 3,
              padding: EdgeInsets.only(
                right: ScallingConfig.scale(20),
                bottom: ScallingConfig.scale(40),
                left: ScallingConfig.scale(20),
              ),
              itemBuilder: (ctx, i) {
                return (BookingCard(
                  appointment: AppointmentDetail(
                    id: "dummy",
                    doctor: null,
                    patient: null,
                    date: DateTime.now(),
                    timeSlot: "10:00 AM",
                    status: "pending",
                    reason: "Consultation",
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
                  showActions: false,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => MyAppointment()),
                    );
                  },
                ));
              },
            ),
          ),
        ],
      ),
    );
  }
}
