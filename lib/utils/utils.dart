import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';

class Utils {
  static double windowWidth(BuildContext context) {
    return MediaQuery.sizeOf(context).width;
  }

  static double windowHeight(BuildContext context) {
    // return MediaQuery.of(context).size.height;
    return MediaQuery.sizeOf(context).height;
  }

  static dynamic layout(BuildContext context) {
    return ResponsiveBreakpoints.of(context);
  }

  static void showErrorSnackBar(BuildContext context, dynamic error) {
    String message = "Something went wrong. Please try again.";

    if (error is String) {
      message = error;
    } else if (error.toString().contains("DioException") ||
        error.toString().contains("SocketException")) {
      message = "Network error. Please check your connection.";
    } else if (error.toString().contains("401") ||
        error.toString().contains("Unauthenticated")) {
      message = "Session expired. Please login again.";
    } else if (error.toString().contains("403")) {
      message = "You don't have permission to perform this action.";
    } else if (error.toString().contains("500")) {
      message = "Server error. Our team is looking into it.";
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }
}

/// Returns an ImageProvider that handles both HTTP URLs and base64 data URIs.
/// Returns null if the url is empty or null.
ImageProvider? buildProfileImageProvider(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('data:image/')) {
    try {
      final base64Str = url.split(',').last;
      return MemoryImage(base64Decode(base64Str));
    } catch (_) {
      return null;
    }
  }
  return NetworkImage(url);
}

class ResponsiveHelper {
  static bool isMobile(BuildContext context) {
    return ResponsiveBreakpoints.of(context).isMobile;
  }

  static bool isTablet(BuildContext context) {
    return ResponsiveBreakpoints.of(context).isTablet;
  }

  static bool isDesktop(BuildContext context) {
    return ResponsiveBreakpoints.of(context).isDesktop;
  }

  static bool is4KScreen(BuildContext context) {
    return ResponsiveBreakpoints.of(context).breakpoint.name?.toUpperCase() ==
        '4K';
  }
}
