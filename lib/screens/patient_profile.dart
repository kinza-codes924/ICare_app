import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/screens/patient_addresses_screen.dart';
import 'package:icare/screens/profile_edit.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/svg_wrapper.dart';

class PatientProfile extends ConsumerWidget {
  const PatientProfile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        leading: CustomBackButton(),
        automaticallyImplyLeading: false,
        title: CustomText(
          text: "Patient Profile".tr(),
          fontSize: 16.78,
          fontFamily: "Gilroy-Bold",
          fontWeight: FontWeight.bold,
          letterSpacing: -0.31,
          lineHeight: 1.0,
          color: AppColors.primary500,
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.account_circle, color: AppColors.primaryColor, size: 28),
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'edit') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileEditScreen()),
                );
              } else if (value == 'addresses') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PatientAddressesScreen()),
                );
              } else if (value == 'logout') {
                ref.read(authProvider.notifier).setUserLogout();
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 20, color: AppColors.primaryColor),
                    SizedBox(width: 12),
                    Text('Edit Profile', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'addresses',
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 20, color: AppColors.primaryColor),
                    SizedBox(width: 12),
                    Text('Your Addresses', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Logout', style: TextStyle(fontSize: 14, color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Picture - use dynamic image from user object
            SizedBox(
              width: Utils.windowWidth(context) * 0.34,
              height: Utils.windowWidth(context) * 0.34,
              child: CircleAvatar(
                radius: Utils.windowWidth(context) * 0.17,
                backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                child: ClipOval(
                  child: () {
                    final imgProvider = buildProfileImageProvider(user?.profilePicture);
                    if (imgProvider != null) {
                      final r = Utils.windowWidth(context) * 0.34;
                      return Image(
                        image: imgProvider,
                        width: r, height: r,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Text(
                          (user?.name ?? 'U').substring(0, 1).toUpperCase(),
                          style: TextStyle(fontSize: Utils.windowWidth(context) * 0.12, fontWeight: FontWeight.w900, color: AppColors.primaryColor),
                        ),
                      );
                    }
                    return Text(
                      (user?.name ?? 'U').substring(0, 1).toUpperCase(),
                      style: TextStyle(fontSize: Utils.windowWidth(context) * 0.12, fontWeight: FontWeight.w900, color: AppColors.primaryColor),
                    );
                  }(),
                ),
              ),
            ),
            SizedBox(height: ScallingConfig.scale(10)),
            CustomText(
              text: user?.name ?? "User",
              fontFamily: "Gilroy-Bold",
              fontSize: 16.79,
            ),
            SizedBox(height: ScallingConfig.scale(12)),
            // Age / Height / Weight chips
            SizedBox(
              width: Utils.windowWidth(context) * 0.9,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
  _infoChip(Icons.cake_outlined, "Age", user?.age ?? "28 yrs"),
  SizedBox(width: ScallingConfig.scale(10)),
  _infoChip(Icons.height_rounded, "Height", "165 cm"),
  SizedBox(width: ScallingConfig.scale(10)),
  _infoChip(Icons.monitor_weight_outlined, "Weight", "58 kg"),
                ],
              ),
            ),
            SizedBox(height: ScallingConfig.scale(10)),
            // Address
            SizedBox(
              width: Utils.windowWidth(context) * 0.9,
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined, color: AppColors.primaryColor, size: 20),
                  SizedBox(width: ScallingConfig.scale(10)),
                  Expanded(
                    child: CustomText(
                      text: "House 12, Street 4, Gulberg III, Lahore",
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: ScallingConfig.scale(18)),
            SizedBox(
              width: Utils.windowWidth(context) * 0.9,
              child: Row(
                children: [
                  SvgWrapper(assetPath: ImagePaths.sms),
                  SizedBox(width: ScallingConfig.scale(10)),
                  CustomText(text: user?.email ?? "emily@gmail.com"),
                ],
              ),
            ),
            SizedBox(height: ScallingConfig.scale(10)),
            SizedBox(
              width: Utils.windowWidth(context) * 0.9,
              child: Row(
                children: [
                  SvgWrapper(
                    assetPath: ImagePaths.calll,
                    color: AppColors.primaryColor,
                  ),
                  SizedBox(width: ScallingConfig.scale(10)),
                  CustomText(text: user?.phoneNumber ?? "+1 234 567 8963"),
                ],
              ),
            ),
            SizedBox(height: ScallingConfig.scale(10)),
            SizedBox(
              width: Utils.windowWidth(context) * 0.9,
              child: Row(
                children: [
                  Icon(Icons.badge_outlined, color: AppColors.primaryColor, size: 20),
                  SizedBox(width: ScallingConfig.scale(10)),
                  CustomText(text: user?.cnic != null && user!.cnic!.isNotEmpty ? "CNIC: ${user.cnic}" : "CNIC: 12345-1234567-1"),
                ],
              ),
            ),
            SizedBox(height: ScallingConfig.scale(15)),
            CustomText(
              text: "Bio:",
              fontSize: 14,
              width: Utils.windowWidth(context) * 0.9,
              isBold: true,
              fontFamily: "Gilroy-Bold",
            ),
            CustomText(
              fontSize: 12,
              width: Utils.windowWidth(context) * 0.9,
              maxLines: 5,
              text:
                  "Lorem ipsum dolor sit amet consectetur adipiscing elit suscipit commodo enim tellus et nascetur at leo accumsan, odio habitanLorem ipsum dolor...",
              fontFamily: "Gilroy-Regular",
            ),
            SizedBox(height: ScallingConfig.scale(15)),
            Container(
              width: Utils.windowWidth(context) * 0.9,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.emergency_rounded,
                        color: Color(0xFFDC2626),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Emergency Contact 1",
                        style: TextStyle(
                          color: Color(0xFF991B1B),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Name: Robert Jordan (Father)",
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    "Phone: +1 987 654 3210",
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: ScallingConfig.scale(10)),
            Container(
              width: Utils.windowWidth(context) * 0.9,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.emergency_rounded,
                        color: Color(0xFFDC2626),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Emergency Contact 2",
                        style: TextStyle(
                          color: Color(0xFF991B1B),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Name: Sarah Jordan (Mother)",
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    "Phone: +1 987 654 3211",
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: ScallingConfig.scale(20)),
            CustomText(
              width: Utils.windowWidth(context) * 0.9,
              text: "Medical History & Medical Documents:",
              fontFamily: "Gilroy-Bold",
              fontSize: 16,
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ScallingConfig.scale(10),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: Utils.windowWidth(context) * 0.3,
                    child: Image.asset('assets/images/medical-doc-1.png'),
                  ),
                  SizedBox(
                    width: Utils.windowWidth(context) * 0.3,
                    child: Image.asset('assets/images/medical-doc-1.png'),
                  ),
                  SizedBox(
                    width: Utils.windowWidth(context) * 0.3,
                    child: Image.asset('assets/images/medical-doc-1.png'),
                  ),
                ],
              ),
            ),
            SizedBox(height: ScallingConfig.scale(10)),
            CustomText(
              width: Utils.windowWidth(context) * 0.9,
              text: "Recent Scans:",
              fontFamily: "Gilroy-Bold",
              fontSize: 16,
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ScallingConfig.scale(10),
              ),
              child: Align(
                alignment: AlignmentGeometry.topLeft,
                child: SizedBox(
                  width: Utils.windowWidth(context) * 0.3,
                  child: Image.asset('assets/images/medical-doc-1.png'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryColor.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primaryColor, size: 18),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }
}