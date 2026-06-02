import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/custom_tab_button.dart';

List<Widget> _doctorTabs(
  BuildContext context,
  int currentIndex,
  Function(int) onSelect,
) {
  return [
    CustomTabButton(
      onPressed: () {
        onSelect(0);
      },
      iconColor: currentIndex == 0
          ? AppColors.primaryColor
          : AppColors.grayColor,
      image: ImagePaths.home,
      title: 'home'.tr(),
    ),
    SizedBox(width: 20),
    CustomTabButton(
      onPressed: () {
        onSelect(1);
      },
      iconColor: currentIndex == 1
          ? AppColors.primaryColor
          : AppColors.grayColor,
      image: ImagePaths.bookings,
      title: 'bookings'.tr(),
    ),
  ];
}

List<Widget> _patientTabs(
  BuildContext context,
  int currentIndex,
  Function(int) onSelect,
) {
  return [
    CustomTabButton(
      onPressed: () {
        onSelect(0);
      },
      iconColor: currentIndex == 0 ? AppColors.primaryColor : AppColors.grayColor,
      image: ImagePaths.home,
      title: 'home'.tr(),
    ),
    CustomTabButton(
      onPressed: () {
        onSelect(1);
      },
      iconColor: currentIndex == 1 ? AppColors.primaryColor : AppColors.grayColor,
      image: ImagePaths.bookings,
      title: 'my_learning'.tr(),
    ),
    SizedBox(width: 20),
    CustomTabButton(
      onPressed: () {
        onSelect(2);
      },
      iconColor: currentIndex == 2 ? AppColors.primaryColor : AppColors.grayColor,
      image: ImagePaths.profile2,
      title: 'profile'.tr(),
    ),
  ];
}

List<Widget> _labTabs(
  BuildContext context,
  int currentIndex,
  Function(int) onSelect,
) {
  return [
    CustomTabButton(
      onPressed: () {
        onSelect(0);
      },
      iconColor: currentIndex == 0
          ? AppColors.primaryColor
          : AppColors.grayColor,
      image: ImagePaths.home,
      title: 'home'.tr(),
    ),
    CustomTabButton(
      onPressed: () {
        onSelect(1);
      },
      iconColor: currentIndex == 1
          ? AppColors.primaryColor
          : AppColors.grayColor,
      image: ImagePaths.bookings,
      title: 'requests'.tr(),
    ),
    SizedBox(width: 20),
    CustomTabButton(
      onPressed: () {
        onSelect(2);
      },
      iconColor: currentIndex == 2
          ? AppColors.primaryColor
          : AppColors.grayColor,
      image: ImagePaths.track,
      title: 'reports'.tr(),
    ),
    CustomTabButton(
      onPressed: () {
        onSelect(3);
      },
      iconColor: currentIndex == 3
          ? AppColors.primaryColor
          : AppColors.grayColor,
      image: ImagePaths.profile2,
      title: 'profile'.tr(),
    ),
  ];
}

List<Widget> _instructorTabs(
  BuildContext context,
  int currentIndex,
  Function(int) onSelect,
) {
  return [
    CustomTabButton(
      onPressed: () => onSelect(0),
      iconColor: currentIndex == 0 ? AppColors.primaryColor : AppColors.grayColor,
      image: ImagePaths.home,
      title: 'dashboard'.tr(),
    ),
    CustomTabButton(
      onPressed: () => onSelect(1),
      iconColor: currentIndex == 1 ? AppColors.primaryColor : AppColors.grayColor,
      image: ImagePaths.bookings,
      title: 'my_learning'.tr(),
    ),
    SizedBox(width: 20),
    CustomTabButton(
      onPressed: () => onSelect(2),
      iconColor: currentIndex == 2 ? AppColors.primaryColor : AppColors.grayColor,
      image: ImagePaths.chat,
      title: 'messages'.tr(),
    ),
    CustomTabButton(
      onPressed: () => onSelect(3),
      iconColor: currentIndex == 3 ? AppColors.primaryColor : AppColors.grayColor,
      image: ImagePaths.profile2,
      title: 'profile'.tr(),
    ),
  ];
}

List<Widget> _pharmacistTabs(
  BuildContext context,
  int currentIndex,
  Function(int) onSelect,
) {
  return [
    CustomTabButton(
      onPressed: () {
        onSelect(0);
      },
      iconColor: currentIndex == 0
          ? AppColors.primaryColor
          : AppColors.grayColor,
      image: ImagePaths.home,
      title: 'home'.tr(),
    ),
    CustomTabButton(
      onPressed: () {
        onSelect(1);
      },
      iconColor: currentIndex == 1
          ? AppColors.primaryColor
          : AppColors.grayColor,
      image: ImagePaths.bookings,
      title: 'prescriptions'.tr(),
    ),
    SizedBox(width: 20),
    CustomTabButton(
      onPressed: () {
        onSelect(2);
      },
      iconColor: currentIndex == 2
          ? AppColors.primaryColor
          : AppColors.grayColor,
      image: ImagePaths.track,
      title: 'inventory'.tr(),
    ),
    CustomTabButton(
      onPressed: () {
        onSelect(3);
      },
      iconColor: currentIndex == 3
          ? AppColors.primaryColor
          : AppColors.grayColor,
      image: ImagePaths.profile2,
      title: 'profile'.tr(),
    ),
  ];
}

List<Widget> _studentTabs(
  BuildContext context,
  int currentIndex,
  Function(int) onSelect,
) {
  return [
    CustomTabButton(
      onPressed: () {
        onSelect(0);
      },
      iconColor: currentIndex == 0
          ? AppColors.primaryColor
          : AppColors.grayColor,
      image: ImagePaths.home,
      title: 'home'.tr(),
    ),
    CustomTabButton(
      onPressed: () {
        onSelect(1);
      },
      iconColor: currentIndex == 1 ? AppColors.primaryColor : AppColors.grayColor,
      image: ImagePaths
          .bookings, // Reusing bookings icon for courses context or could use a book icon
      title: 'programs'.tr(),
    ),
    SizedBox(width: 20),
    CustomTabButton(
      onPressed: () {
        onSelect(2);
      },
      iconColor: currentIndex == 2
          ? AppColors.primaryColor
          : AppColors.grayColor,
      image: ImagePaths.chat,
      title: 'messages'.tr(),
    ),
    CustomTabButton(
      onPressed: () {
        onSelect(3);
      },
      iconColor: currentIndex == 3
          ? AppColors.primaryColor
          : AppColors.grayColor,
      image: ImagePaths.profile2,
      title: 'profile'.tr(),
    ),
  ];
}

List<Widget> _adminTabs(
  BuildContext context,
  int currentIndex,
  Function(int) onSelect,
) {
  return [
    CustomTabButton(
      onPressed: () {
        onSelect(0);
      },
      iconColor: currentIndex == 0
          ? AppColors.primaryColor
          : AppColors.grayColor,
      image: ImagePaths.home,
      title: 'verified'.tr(),
    ),
    const SizedBox(width: 20),
    CustomTabButton(
      onPressed: () {
        onSelect(2);
      },
      iconColor: currentIndex == 2
          ? AppColors.primaryColor
          : AppColors.grayColor,
      image: ImagePaths.chat,
      title: 'messages'.tr(),
    ),
    CustomTabButton(
      onPressed: () {
        onSelect(3);
      },
      iconColor: currentIndex == 3
          ? AppColors.primaryColor
          : AppColors.grayColor,
      image: ImagePaths.profile2,
      title: 'profile'.tr(),
    ),
  ];
}

List<Widget>? buildTabs({
  required String role,
  required BuildContext context,
  required int currentIndex,
  required Function(int) onSelect,
}) {
  switch (role) {
    case "Pharmacy":
      return _pharmacistTabs(context, currentIndex, onSelect);
    case "Instructor":
      return _instructorTabs(context, currentIndex, onSelect);
    case "Patient":
      return _patientTabs(context, currentIndex, onSelect);
    case "Laboratory":
      return _labTabs(context, currentIndex, onSelect);
    case "Doctor":
      return _doctorTabs(context, currentIndex, onSelect);
    case "Student":
      return _studentTabs(context, currentIndex, onSelect);
    case "Admin":
      return _adminTabs(context, currentIndex, onSelect);
    default:
      return _doctorTabs(context, currentIndex, onSelect);
  }
}
