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
      title: "Home",
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
      title: "Bookings",
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
      title: "Home",
    ),
    CustomTabButton(
      onPressed: () {
        onSelect(1);
      },
      iconColor: currentIndex == 1 ? AppColors.primaryColor : AppColors.grayColor,
      image: ImagePaths.track,
      title: "Programs",
    ),
    SizedBox(width: 20),
    CustomTabButton(
      onPressed: () {
        onSelect(2);
      },
      iconColor: currentIndex == 2 ? AppColors.primaryColor : AppColors.grayColor,
      image: ImagePaths.profile2,
      title: "Profile",
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
      title: "Home",
    ),
    CustomTabButton(
      onPressed: () {
        onSelect(1);
      },
      iconColor: currentIndex == 1
          ? AppColors.primaryColor
          : AppColors.grayColor,
      image: ImagePaths.bookings,
      title: "Requests",
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
      title: "Reports",
    ),
    CustomTabButton(
      onPressed: () {
        onSelect(3);
      },
      iconColor: currentIndex == 3
          ? AppColors.primaryColor
          : AppColors.grayColor,
      image: ImagePaths.profile2,
      title: "Profile",
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
      title: "Dashboard",
    ),
    CustomTabButton(
      onPressed: () => onSelect(1),
      iconColor: currentIndex == 1 ? AppColors.primaryColor : AppColors.grayColor,
      image: ImagePaths.bookings,
      title: "Courses",
    ),
    SizedBox(width: 20),
    CustomTabButton(
      onPressed: () => onSelect(2),
      iconColor: currentIndex == 2 ? AppColors.primaryColor : AppColors.grayColor,
      image: ImagePaths.chat,
      title: "Chat",
    ),
    CustomTabButton(
      onPressed: () => onSelect(3),
      iconColor: currentIndex == 3 ? AppColors.primaryColor : AppColors.grayColor,
      image: ImagePaths.profile2,
      title: "Profile",
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
      title: "Home",
    ),
    CustomTabButton(
      onPressed: () {
        onSelect(1);
      },
      iconColor: currentIndex == 1
          ? AppColors.primaryColor
          : AppColors.grayColor,
      image: ImagePaths.bookings,
      title: "Prescriptions",
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
      title: "Inventory",
    ),
    CustomTabButton(
      onPressed: () {
        onSelect(3);
      },
      iconColor: currentIndex == 3
          ? AppColors.primaryColor
          : AppColors.grayColor,
      image: ImagePaths.profile2,
      title: "Profile",
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
      title: "Home",
    ),
    CustomTabButton(
      onPressed: () {
        onSelect(1);
      },
      iconColor: currentIndex == 1 ? AppColors.primaryColor : AppColors.grayColor,
      image: ImagePaths
          .bookings, // Reusing bookings icon for courses context or could use a book icon
      title: "Programs",
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
      title: "Chat",
    ),
    CustomTabButton(
      onPressed: () {
        onSelect(3);
      },
      iconColor: currentIndex == 3
          ? AppColors.primaryColor
          : AppColors.grayColor,
      image: ImagePaths.profile2,
      title: "Profile",
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
      title: "Verify",
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
      title: "Chat",
    ),
    CustomTabButton(
      onPressed: () {
        onSelect(3);
      },
      iconColor: currentIndex == 3
          ? AppColors.primaryColor
          : AppColors.grayColor,
      image: ImagePaths.profile2,
      title: "Profile",
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
