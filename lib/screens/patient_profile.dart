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
                        errorBuilder: (_, _, _) => Text(
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
  _infoChip(Icons.cake_outlined, "Age", (user?.age?.isNotEmpty == true) ? user!.age! : "—"),
  SizedBox(width: ScallingConfig.scale(10)),
  _infoChip(Icons.height_rounded, "Height", (user?.height?.isNotEmpty == true) ? user!.height! : "—"),
  SizedBox(width: ScallingConfig.scale(10)),
  _infoChip(Icons.monitor_weight_outlined, "Weight", (user?.weight?.isNotEmpty == true) ? user!.weight! : "—"),
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
                      text: (user?.address?.isNotEmpty == true) ? user!.address! : "No address set",
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
                  CustomText(text: (user?.email.isNotEmpty == true) ? user!.email : "No email"),
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
                  CustomText(text: (user?.phoneNumber.isNotEmpty == true) ? user!.phoneNumber : "No phone"),
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
                  CustomText(text: user?.cnic != null && user!.cnic!.isNotEmpty ? "CNIC: ${user.cnic}" : "CNIC: not set"),
                ],
              ),
            ),
            SizedBox(height: ScallingConfig.scale(15)),
            // Bio — real data (health goals / existing conditions), not a
            // hardcoded Lorem ipsum block.
            Builder(builder: (context) {
              final bio = [
                if (user?.healthGoals?.isNotEmpty == true) user!.healthGoals!,
                if (user?.existingConditions?.isNotEmpty == true) user!.existingConditions!,
              ].join('\n');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
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
                    maxLines: 6,
                    text: bio.isNotEmpty ? bio : "No bio added yet.",
                    fontFamily: "Gilroy-Regular",
                  ),
                ],
              );
            }),
            SizedBox(height: ScallingConfig.scale(15)),
            // Emergency contacts — real list from the user, each rendered as a
            // card. Empty state instead of the old fake Robert/Sarah Jordan.
            Builder(builder: (context) {
              final contacts = user?.emergencyContacts ?? [];
              if (contacts.isEmpty) {
                return Container(
                  width: Utils.windowWidth(context) * 0.9,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.emergency_rounded, color: Color(0xFF94A3B8), size: 20),
                      SizedBox(width: 8),
                      Expanded(child: Text("No emergency contacts added yet.",
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)))),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  for (int i = 0; i < contacts.length; i++) ...[
                    _emergencyCard(context, i + 1, contacts[i]),
                    if (i != contacts.length - 1) SizedBox(height: ScallingConfig.scale(10)),
                  ],
                ],
              );
            }),
            SizedBox(height: ScallingConfig.scale(20)),
            // Medical documents & scans are managed on the Medical Records
            // screen, not stored on the user object — so link there instead of
            // showing the same placeholder image four times.
            SizedBox(
              width: Utils.windowWidth(context) * 0.9,
              child: Row(
                children: [
                  Icon(Icons.folder_shared_outlined, color: AppColors.primaryColor, size: 20),
                  SizedBox(width: ScallingConfig.scale(10)),
                  Expanded(
                    child: CustomText(
                      text: "Medical history, documents and scans are in Medical Records.",
                      fontSize: 12,
                      maxLines: 3,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: ScallingConfig.scale(20)),
          ],
        ),
      ),
    );
  }

  // One emergency-contact card, built from the user's real contact map
  // ({name, relationship, phone}).
  Widget _emergencyCard(BuildContext context, int index, Map<String, String> c) {
    final name = c['name'] ?? '';
    final relation = c['relationship'] ?? c['relation'] ?? '';
    final phone = c['phone'] ?? '';
    return Container(
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
          Row(
            children: [
              const Icon(Icons.emergency_rounded, color: Color(0xFFDC2626), size: 20),
              const SizedBox(width: 8),
              Text(
                "Emergency Contact $index",
                style: const TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            relation.isNotEmpty ? "Name: $name ($relation)" : "Name: $name",
            style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
          ),
          if (phone.isNotEmpty)
            Text(
              "Phone: $phone",
              style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
            ),
        ],
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