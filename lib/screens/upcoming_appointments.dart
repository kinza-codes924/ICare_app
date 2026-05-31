import 'dart:developer';

import 'package:easy_date_timeline/easy_date_timeline.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/appointment_card.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:intl/intl.dart';

class UpcomingAppointments extends StatefulWidget {
  const UpcomingAppointments({super.key});

  @override
  State<UpcomingAppointments> createState() => _UpcomingAppointmentsState();
}

class _UpcomingAppointmentsState extends State<UpcomingAppointments> {
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Utils.windowWidth(context) > 600;

    // ─── MOBILE: original design ──────────────────────────────────────────
    if (!isDesktop) {
      return Scaffold(
        appBar: AppBar(
          title: CustomText(
            text: "Upcoming Appointments".tr(),
            fontSize: 16.78,
            fontFamily: "Gilroy-Bold",
            letterSpacing: -0.31,
            lineHeight: 1.0,
            color: AppColors.primary500,
            fontWeight: FontWeight.bold,
          ),
          leading: CustomBackButton(),
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            EasyDateTimeLinePicker.itemBuilder(
              focusedDate: _selectedDate,
              firstDate: DateTime(2024, 3, 18),
              lastDate: DateTime(2030, 3, 18),
              itemExtent: ScallingConfig.scale(70),
              itemBuilder:
                  (context, date, isSelected, isDisabled, isToday, onTap) {
                    debugPrint(_selectedDate?.toString());
                    return InkWell(
                      onTap: () {
                        onTap();
                      },
                      child: Container(
                        width: ScallingConfig.scale(60),
                        height: ScallingConfig.scale(40),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.secondaryColor
                              : AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(height: ScallingConfig.scale(10)),
                            CustomText(
                              fontSize: 22,
                              fontFamily: "Gilroy-SemiBold",
                              text: date.day.toString(),
                              color: isSelected
                                  ? AppColors.white
                                  : AppColors.darkGray400,
                            ),
                            SizedBox(height: ScallingConfig.scale(10)),
                            CustomText(
                              fontSize: 14,
                              fontFamily: "Gilroy-SemiBold",
                              text: DateFormat('EEE').format(date).toString(),
                              color: isSelected
                                  ? AppColors.white
                                  : AppColors.darkGray400,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
              onDateChange: (date) {
                debugPrint(date.toString());
                setState(() {
                  log('$date ====      ');
                  _selectedDate = date;
                });
              },
            ),
            SizedBox(height: ScallingConfig.scale(20)),
            Expanded(
              child: ListView.builder(
                itemCount: 4,
                padding: EdgeInsets.symmetric(
                  horizontal: ScallingConfig.scale(20),
                ),
                itemBuilder: (ctx, i) {
                  return AppointmentCard();
                },
              ),
            ),
            SizedBox(height: Utils.windowHeight(context) * 0.08),
          ],
        ),
      );
    }

    // ─── DESKTOP: premium design ──────────────────────────────────────────
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Premium white header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              bottom: 24,
              left: 48,
              right: 48,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              color: Color(0xFF0F172A),
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CustomText(
                                text: "Upcoming Appointments".tr(),
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                              const SizedBox(height: 2),
                              CustomText(
                                text: "Select a date to view your appointments",
                                fontSize: 13,
                                color: const Color(0xFF94A3B8),
                                fontWeight: FontWeight.w400,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.event_note_rounded,
                                size: 16,
                                color: AppColors.primaryColor,
                              ),
                              const SizedBox(width: 6),
                              CustomText(
                                text: "4 Appointments",
                                fontSize: 13,
                                color: AppColors.primaryColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Calendar strip
                    EasyDateTimeLinePicker.itemBuilder(
                      focusedDate: _selectedDate,
                      firstDate: DateTime(2024, 3, 18),
                      lastDate: DateTime(2030, 3, 18),
                      itemExtent: 80,
                      itemBuilder:
                          (
                            context,
                            date,
                            isSelected,
                            isDisabled,
                            isToday,
                            onTap,
                          ) {
                            return InkWell(
                              onTap: onTap,
                              borderRadius: BorderRadius.circular(16),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 70,
                                height: 90,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primaryColor
                                      : isToday
                                      ? AppColors.primaryColor.withValues(alpha: 0.06)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: isToday && !isSelected
                                      ? Border.all(
                                          color: AppColors.primaryColor
                                              .withValues(alpha: 0.2),
                                          width: 1.5,
                                        )
                                      : null,
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primaryColor
                                                .withValues(alpha: 0.25),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      date.day.toString(),
                                      style: TextStyle(
                                        fontFamily: "Gilroy",
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('EEE').format(date),
                                      style: TextStyle(
                                        fontFamily: "Gilroy",
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white.withValues(alpha: 0.7)
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                      onDateChange: (date) {
                        setState(() {
                          _selectedDate = date;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Appointment cards
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: ListView.builder(
                  itemCount: 4,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 20,
                  ),
                  itemBuilder: (ctx, i) {
                    return const AppointmentCard();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
