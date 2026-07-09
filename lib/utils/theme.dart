import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primaryColor = Color(0xFF0036BC);
  static const secondaryColor = Color(0xFF14B1FF);
  static const tertiaryColor = Color(0xFF889098);

  static const bgColor = Color(0xFFF6FBFA);
  static const white50 = Color(0xFFEFF2F5);
  static const primary500 = Color(0xFF171F3F); // text Color

  static const grayColor = Color(0xFF888888);
  static const veryLightGrey = Color(0xFFEEF1F4);
  static const darkGreyColor = Color(0xFF545F71);
  static const darkGray500 = Color(0xFF292929);
  static const darkGray600 = Color(0xFF2C2C2C);
  static const darkGray400 = Color(0xFF6B779A);
  static const darkGray300 = Color(0xFF333333);

  static const lightGrey10 = Color(0xffE7E7E7);
  static const lightGrey100 = Color(0xffd6dde4);
  static const lightGrey200 = Color(0xffb2b9c0);
  static const lightGrey300 = Color(0xffADB3BA);
  static const lightGrey500 = Color(0xff9DA7B7);
  static const lightGrey600 = Color(0xffE8EDEE);

  static const themeBlue = Color(0xFF00288D);
  static const themeGreen = Color(0xFF2EC447);
  static const white = Color(0xFFFFFFFF);
  static const veryLightBlue = Color(0xff5ed2d212);
  static const themeRed = Color(0xFFFF0000);
  static const themeDarkGrey = Color(0xFF313A43);
  static const themeBlack = Color(0xFF242424);
}

class AppTheme {
  static final mainTheme = ThemeData(
    useMaterial3: false,
    fontFamily: "Gilroy",
    scaffoldBackgroundColor: AppColors.bgColor,
    textTheme: const TextTheme(),

    drawerTheme: const DrawerThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bgColor,
      centerTitle: true,
      titleTextStyle: TextStyle(color: AppColors.primary500, fontSize: 18.70),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadiusGeometry.all(Radius.circular(30)),
        ),
        textStyle: TextStyle(
          fontFamily: "Gllroy",
          fontSize: ScallingConfig.moderateScale(24),
        ),
      ),
    ),

    // Always-visible, thicker scrollbars so scroll position is obvious
    scrollbarTheme: ScrollbarThemeData(
      thumbVisibility: const WidgetStatePropertyAll(true),
      thickness: const WidgetStatePropertyAll(10),
      radius: const Radius.circular(8),
      thumbColor: WidgetStatePropertyAll(
        AppColors.primaryColor.withValues(alpha: 0.45),
      ),
      trackColor: const WidgetStatePropertyAll(Color(0xFFE8ECF5)),
      minThumbLength: 48,
    ),
  );
}
