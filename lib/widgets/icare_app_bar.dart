import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/widgets/back_button.dart';

/// Reusable AppBar with the iCare logo on the left of the title.
/// Use this on every navigated screen so the brand mark is always visible.
class IcareAppBar extends StatelessWidget implements PreferredSizeWidget {
  const IcareAppBar({
    super.key,
    required this.title,
    this.actions,
    this.centerTitle = false,
    this.showBack = true,
    this.bottom,
  });

  final String title;
  final List<Widget>? actions;
  final bool centerTitle;
  final bool showBack;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leading: showBack ? const CustomBackButton() : null,
      centerTitle: true,
      bottom: bottom,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            ImagePaths.logo,
            height: 26,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              fontFamily: 'Gilroy-Bold',
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
      actions: actions,
      shape: const Border(
        bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
    );
  }
}
