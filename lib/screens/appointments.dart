import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';

import 'package:icare/widgets/appointment_card.dart';
import 'package:icare/widgets/custom_text.dart';

class Appointments extends StatelessWidget {
  const Appointments({super.key});

  @override
  Widget build(BuildContext context) {
    final appointments = [
      {
        "id": "1",
        "date": "Dec 05, 2023 - 10:00 AM",
        "patient_name": "Emily Jordan",
        "booking_id": "#DR452SA54",
        "address": "20 Cooper Square, USA",
      },
      {
        "id": "2",
        "date": "Dec 05, 2023 - 10:00 AM",
        "patient_name": "Emily Jordan",
        "booking_id": "#DR452SA54",
        "address": "20 Cooper Square, USA",
      },
      {
        "id": "3",
        "date": "Dec 05, 2023 - 10:00 AM",
        "patient_name": "Emily Jordan",
        "booking_id": "#DR452SA54",
        "address": "20 Cooper Square, USA",
      },
    ];
    return Scaffold(
      appBar: AppBar(title: CustomText(text: "My Appointments".tr())),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText(
            padding: EdgeInsets.only(left: ScallingConfig.scale(25)),
            text: "Appointments".tr(),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(
                horizontal: ScallingConfig.scale(20),
              ),
              itemCount: appointments.length,
              itemBuilder: (ctx, i) {
                return (AppointmentCard());
              },
            ),
          ),
        ],
      ),
    );
  }
}
