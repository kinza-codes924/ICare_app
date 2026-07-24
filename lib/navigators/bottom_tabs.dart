import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/custom_tab_button.dart';

// Bottom nav bar tabs. Each tab is a real route now — tapping one changes the
// URL (so refresh / back / deep-link all work) instead of flipping an index
// inside TabsScreen, which used to leave every screen sitting on /dashboard.

/// A tab is highlighted when the current URL is (or sits under) its path.
bool _isActive(String location, String path) =>
    location == path || location.startsWith('$path/');

Color _tint(String location, String path) =>
    _isActive(location, path) ? AppColors.primaryColor : AppColors.grayColor;

List<Widget> _doctorTabs(BuildContext context, String location) {
  return [
    CustomTabButton(
      onPressed: () => context.go('/doctor/dashboard'),
      iconColor: _tint(location, '/doctor/dashboard'),
      image: ImagePaths.home,
      title: 'home'.tr(),
    ),
    SizedBox(width: 20),
    CustomTabButton(
      onPressed: () => context.go('/doctor/appointments'),
      iconColor: _tint(location, '/doctor/appointments'),
      image: ImagePaths.bookings,
      title: 'bookings'.tr(),
    ),
  ];
}

List<Widget> _patientTabs(BuildContext context, String location) {
  return [
    CustomTabButton(
      onPressed: () => context.go('/patient/home'),
      iconColor: _tint(location, '/patient/home'),
      image: ImagePaths.home,
      title: 'home'.tr(),
    ),
    SizedBox(width: 20),
    CustomTabButton(
      onPressed: () => context.go('/patient/profile'),
      iconColor: _tint(location, '/patient/profile'),
      image: ImagePaths.profile2,
      title: 'profile'.tr(),
    ),
  ];
}

List<Widget> _labTabs(BuildContext context, String location) {
  return [
    CustomTabButton(
      onPressed: () => context.go('/lab/dashboard'),
      iconColor: _tint(location, '/lab/dashboard'),
      image: ImagePaths.home,
      title: 'home'.tr(),
    ),
    CustomTabButton(
      onPressed: () => context.go('/lab/bookings'),
      iconColor: _tint(location, '/lab/bookings'),
      image: ImagePaths.bookings,
      title: 'requests'.tr(),
    ),
    SizedBox(width: 20),
    CustomTabButton(
      onPressed: () => context.go('/lab/reports'),
      iconColor: _tint(location, '/lab/reports'),
      image: ImagePaths.track,
      title: 'reports'.tr(),
    ),
    CustomTabButton(
      onPressed: () => context.go('/lab/profile-setup'),
      iconColor: _tint(location, '/lab/profile-setup'),
      image: ImagePaths.profile2,
      title: 'profile'.tr(),
    ),
  ];
}

List<Widget> _instructorTabs(BuildContext context, String location) {
  return [
    CustomTabButton(
      onPressed: () => context.go('/instructor/dashboard'),
      iconColor: _tint(location, '/instructor/dashboard'),
      image: ImagePaths.home,
      title: 'dashboard'.tr(),
    ),
    CustomTabButton(
      onPressed: () => context.go('/instructor/manage-courses'),
      iconColor: _tint(location, '/instructor/manage-courses'),
      image: ImagePaths.bookings,
      title: 'my_learning'.tr(),
    ),
    SizedBox(width: 20),
    CustomTabButton(
      onPressed: () => context.go('/chat'),
      iconColor: _tint(location, '/chat'),
      image: ImagePaths.chat,
      title: 'messages'.tr(),
    ),
    CustomTabButton(
      onPressed: () => context.go('/instructor/profile-setup'),
      iconColor: _tint(location, '/instructor/profile-setup'),
      image: ImagePaths.profile2,
      title: 'profile'.tr(),
    ),
  ];
}

List<Widget> _pharmacistTabs(BuildContext context, String location) {
  return [
    CustomTabButton(
      onPressed: () => context.go('/pharmacy/dashboard'),
      iconColor: _tint(location, '/pharmacy/dashboard'),
      image: ImagePaths.home,
      title: 'home'.tr(),
    ),
    CustomTabButton(
      onPressed: () => context.go('/pharmacy/orders'),
      iconColor: _tint(location, '/pharmacy/orders'),
      image: ImagePaths.bookings,
      title: 'orders'.tr(),
    ),
    SizedBox(width: 20),
    CustomTabButton(
      onPressed: () => context.go('/pharmacy/inventory'),
      iconColor: _tint(location, '/pharmacy/inventory'),
      image: ImagePaths.track,
      title: 'inventory'.tr(),
    ),
    CustomTabButton(
      onPressed: () => context.go('/pharmacy/profile-setup'),
      iconColor: _tint(location, '/pharmacy/profile-setup'),
      image: ImagePaths.profile2,
      title: 'profile'.tr(),
    ),
  ];
}

List<Widget> _studentTabs(BuildContext context, String location) {
  return [
    CustomTabButton(
      onPressed: () => context.go('/student/dashboard'),
      iconColor: _tint(location, '/student/dashboard'),
      image: ImagePaths.home,
      title: 'home'.tr(),
    ),
    CustomTabButton(
      onPressed: () => context.go('/student/courses'),
      iconColor: _tint(location, '/student/courses'),
      image: ImagePaths
          .bookings, // Reusing bookings icon for courses context or could use a book icon
      title: 'programs'.tr(),
    ),
    SizedBox(width: 20),
    CustomTabButton(
      onPressed: () => context.go('/student/profile'),
      iconColor: _tint(location, '/student/profile'),
      image: ImagePaths.profile2,
      title: 'profile'.tr(),
    ),
  ];
}

List<Widget> _adminTabs(BuildContext context, String location) {
  return [
    CustomTabButton(
      onPressed: () => context.go('/admin/dashboard'),
      iconColor: _tint(location, '/admin/dashboard'),
      image: ImagePaths.home,
      title: 'verified'.tr(),
    ),
    const SizedBox(width: 20),
    CustomTabButton(
      onPressed: () => context.go('/chat'),
      iconColor: _tint(location, '/chat'),
      image: ImagePaths.chat,
      title: 'messages'.tr(),
    ),
    CustomTabButton(
      onPressed: () => context.go('/admin/profile'),
      iconColor: _tint(location, '/admin/profile'),
      image: ImagePaths.profile2,
      title: 'profile'.tr(),
    ),
  ];
}

List<Widget>? buildTabs({
  required String role,
  required BuildContext context,
  required String location,
}) {
  switch (role) {
    case "Pharmacy":
      return _pharmacistTabs(context, location);
    case "Instructor":
      return _instructorTabs(context, location);
    case "Patient":
      return _patientTabs(context, location);
    case "Laboratory":
      return _labTabs(context, location);
    case "Doctor":
      return _doctorTabs(context, location);
    case "Student":
      return _studentTabs(context, location);
    case "Admin":
      return _adminTabs(context, location);
    default:
      return _doctorTabs(context, location);
  }
}
