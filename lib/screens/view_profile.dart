import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/screens/create_profile.dart';
import 'package:icare/screens/student_profile_setup.dart';
import 'package:icare/screens/rating_n_reviews.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_record_card.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/svg_wrapper.dart';

class ViewProfile extends ConsumerWidget {
  const ViewProfile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final role = authState.userRole;
    log('profile  role ===> $role');

    final String name = user?.name ?? "Aaron Smith";
    final String email = user?.email ?? "lisamarie@gmail.com";
    final String phone = user?.phoneNumber ?? "+1 234 567 8963";
    final String bio =
        "Master advanced techniques and specialized knowledge through our comprehensive professional course, designed to equip you with the essential skills and practical expertise.";
    final String dob = "December 25, 1990";
    final String gender = "Male";
    final String address = "199 Water Street 24TH, New York";
    final String qualification = "";
    final String educationLevel = "";
    final List<String> preferences = [];

    final label = role == "Patient"
        ? "Total Appointments"
        : role == "Laboratory"
        ? "Active Orders"
        : role == "pharmacist"
        ? "Total Appointments"
        : "Total Consultations";

    if (isDesktop) {
      return _WebViewProfile(
        role: role,
        label: label,
        name: name,
        email: email,
        phone: phone,
        bio: bio,
        dob: dob,
        gender: gender,
        address: address,
        qualification: qualification,
        educationLevel: educationLevel,
        preferences: preferences,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: CustomText(
          text: "My Profile",
          fontWeight: FontWeight.bold,
          fontSize: 16.78,
          color: AppColors.primary500,
          letterSpacing: -0.31,
          lineHeight: 1.0,
          fontFamily: "Gilroy-Bold",
        ),
        leading: const CustomBackButton(),
        automaticallyImplyLeading: false,
        actions: [
          GestureDetector(
            onTap: () {
              if (role == "Student") {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (ctx) => StudentProfileSetup()),
                );
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => CreateProfile(isEdit: true),
                  ),
                );
              }
            },
            child: const SvgWrapper(assetPath: ImagePaths.edit),
          ),
          SizedBox(width: ScallingConfig.scale(20)),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: ScallingConfig.scale(50)),
        child: Center(
          child: Column(
            children: [
              const profilePicker(),
              SizedBox(height: ScallingConfig.scale(15)),
              CustomText(
                text: name,
                color: AppColors.primary500,
                fontFamily: "Gilroy-Bold",
                fontWeight: FontWeight.w400,
                fontSize: 16.78,
              ),
              SizedBox(height: ScallingConfig.scale(40)),
              if (role != "instructor" && role != "student") ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomRecordCard(
                      color: AppColors.primaryColor,
                      icon: SvgWrapper(
                        assetPath: role == "lab_technician"
                            ? ImagePaths.lab_tech
                            : ImagePaths.profile2User,
                      ),
                      number: "150",
                      label: label,
                    ),
                    SizedBox(width: ScallingConfig.scale(15)),
                    CustomRecordCard(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => RatingAndReviews(),
                          ),
                        );
                      },
                      icon: SvgWrapper(
                        assetPath: role == "lab_technician"
                            ? ImagePaths.lab_tech
                            : ImagePaths.star,
                      ),
                      number: role == "lab_technician" ? "32" : "4.9",
                      label: role == "lab_technician"
                          ? "Completed Reports"
                          : "Ratings",
                    ),
                  ],
                ),
              ],

              SizedBox(height: ScallingConfig.scale(10)),
              SizedBox(
                width: Utils.windowWidth(context) * 0.9,
                child: ListTile(
                  leading: const SvgWrapper(assetPath: ImagePaths.sms),
                  title: CustomText(
                    text: email,
                    color: AppColors.grayColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Gilroy-SemiBold",
                  ),
                ),
              ),
              SizedBox(
                width: Utils.windowWidth(context) * 0.85,
                child: const Divider(),
              ),
              SizedBox(height: ScallingConfig.scale(1)),
              SizedBox(
                width: Utils.windowWidth(context) * 0.9,
                child: ListTile(
                  leading: const SvgWrapper(
                    assetPath: ImagePaths.calll,
                    color: AppColors.primaryColor,
                  ),
                  title: CustomText(
                    text: phone,
                    color: AppColors.grayColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Gilroy-SemiBold",
                  ),
                ),
              ),
              SizedBox(
                width: Utils.windowWidth(context) * 0.85,
                child: const Divider(),
              ),

              SizedBox(height: ScallingConfig.scale(5)),
              CustomText(
                text: "Bio:",
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary500,
                fontFamily: "Gilroy-Bold",
                width: Utils.windowWidth(context) * 0.85,
              ),
              SizedBox(height: ScallingConfig.scale(5)),
              CustomText(
                text: bio,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.grayColor,
                maxLines: 3,
                fontFamily: "Gilroy-Medium",
                width: Utils.windowWidth(context) * 0.85,
              ),
              SizedBox(height: ScallingConfig.scale(10)),
              infoRowTile(iconPath: ImagePaths.calendar, infoText: dob),
              infoRowTile(iconPath: ImagePaths.gender, infoText: gender),

              infoRowTile(iconPath: ImagePaths.marker2, infoText: address),
              if (role == "Student" && qualification.isNotEmpty)
                infoRowTile(
                  iconPath: ImagePaths.certificate,
                  infoText: qualification,
                ),
              if (role == "Student" && educationLevel.isNotEmpty)
                infoRowTile(
                  iconPath: ImagePaths.certificate,
                  infoText: educationLevel,
                ),
              const infoRowTile(
                iconPath: ImagePaths.card,
                infoText: "5678 1234-A",
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebViewProfile extends StatelessWidget {
  final String role;
  final String label;
  final String name;
  final String email;
  final String phone;
  final String bio;
  final String dob;
  final String gender;
  final String address;
  final String qualification;
  final String educationLevel;
  final List<String> preferences;

  const _WebViewProfile({
    required this.role,
    required this.label,
    required this.name,
    required this.email,
    required this.phone,
    required this.bio,
    required this.dob,
    required this.gender,
    required this.address,
    this.qualification = "",
    this.educationLevel = "",
    this.preferences = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Row(
        children: [
          // ── Left: Profile Sidebar Card ──
          Container(
            width: 400,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
            child: Column(
              children: [
                const CustomBackButton(margin: EdgeInsets.zero),
                const SizedBox(height: 60),
                // Premium Avatar
                Container(
                  width: 180,
                  height: 180,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryColor, width: 3),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: Image.asset(ImagePaths.user7, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                    fontFamily: "Gilroy-Bold",
                  ),
                ),
                if (role != 'Patient') ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      role.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (role == "Student") {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => StudentProfileSetup(),
                          ),
                        );
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => CreateProfile(isEdit: true),
                          ),
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.edit_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                    label: const Text(
                      "Edit Profile",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Right: Main Content ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(80),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats Row
                      if (role != "instructor" && role != "student")
                        Row(
                          children: [
                            Expanded(
                              child: _buildWebStatCard(
                                label: label,
                                value: "150",
                                icon: role == "lab_technician"
                                    ? Icons.science_rounded
                                    : Icons.people_alt_rounded,
                                color: const Color(0xFF3B82F6),
                              ),
                            ),
                            const SizedBox(width: 32),
                            Expanded(
                              child: _buildWebStatCard(
                                label: role == "lab_technician"
                                    ? "Completed Reports"
                                    : "Average Rating",
                                value: role == "lab_technician" ? "32" : "4.9",
                                icon: role == "lab_technician"
                                    ? Icons.check_circle_rounded
                                    : Icons.star_rounded,
                                color: const Color(0xFF22C55E),
                              ),
                            ),
                          ],
                        ),
                      if (role != "instructor" && role != "student")
                        const SizedBox(height: 60),

                      // Details Section
                      const Text(
                        "Detailed Information",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                          fontFamily: "Gilroy-Bold",
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDetailItem(
                                    "Email Address",
                                    email,
                                    Icons.email_outlined,
                                  ),
                                ),
                                Expanded(
                                  child: _buildDetailItem(
                                    "Phone Number",
                                    phone,
                                    Icons.phone_android_rounded,
                                  ),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Divider(color: Color(0xFFF1F4F9)),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDetailItem(
                                    "Date of Birth",
                                    dob,
                                    Icons.calendar_today_outlined,
                                  ),
                                ),
                                Expanded(
                                  child: _buildDetailItem(
                                    "Gender",
                                    gender,
                                    Icons.person_outline_rounded,
                                  ),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Divider(color: Color(0xFFF1F4F9)),
                            ),
                            _buildDetailItem(
                              "About / Bio",
                              bio,
                              Icons.description_outlined,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Divider(color: Color(0xFFF1F4F9)),
                            ),
                            _buildDetailItem(
                              "Location / Office",
                              address,
                              Icons.location_on_outlined,
                            ),
                            if (role == "Student" &&
                                qualification.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 32),
                                child: Divider(color: Color(0xFFF1F4F9)),
                              ),
                              _buildDetailItem(
                                "Qualification",
                                qualification,
                                Icons.school_outlined,
                              ),
                            ],
                            if (role == "Student" &&
                                educationLevel.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 32),
                                child: Divider(color: Color(0xFFF1F4F9)),
                              ),
                              _buildDetailItem(
                                "Education Level",
                                educationLevel,
                                Icons.history_edu_rounded,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primaryColor),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 30),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class profilePicker extends StatelessWidget {
  const profilePicker({super.key});

  @override
  Widget build(BuildContext context) {
    Future<void> showImageSourcePicker(BuildContext context) async {
      showModalBottomSheet(
        context: context,
        builder: (BuildContext bc) {
          return SafeArea(
            child: Wrap(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Gallery'),
                  onTap: () {
                    // _pickImage(ImageSource.gallery);
                    Navigator.of(context).pop(); // Close the bottom sheet
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Camera'),
                  onTap: () {
                    // _pickImage(ImageSource.camera);
                    Navigator.of(context).pop(); // Close the bottom sheet
                  },
                ),
              ],
            ),
          );
        },
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: Utils.windowWidth(context) * 0.3,
          height: Utils.windowHeight(context) * 0.15,
          padding: EdgeInsets.all(7),
          decoration: BoxDecoration(
            border: Border.all(width: 2, color: AppColors.themeDarkGrey),

            borderRadius: BorderRadius.all(Radius.circular(35)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadiusGeometry.circular(30),
            child: SizedBox(
              width: Utils.windowWidth(context) * 0.26,
              height: Utils.windowHeight(context) * 0.1,
              child: Image.asset(
                ImagePaths.user7,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
        ),

        // Positioned(
        //   right: ScallingConfig.scale(-5),
        //   bottom: ScallingConfig.scale(-5),
        //   child: CustomButton(
        //     onPressed: () {
        //       _showImageSourcePicker(context);
        //     },
        //     padding: EdgeInsets.all(0),
        //     width: ScallingConfig.scale(30),
        //     borderRadius: 10,
        //     height: ScallingConfig.scale(25),
        //     bgColor: AppColors.lightGrey500,
        //     leadingIcon: SvgWrapper(
        //       width: ScallingConfig.scale(20),
        //       assetPath: ImagePaths.camera,
        //     ),
        //   ),
        // ),
      ],
    );
  }
}

class infoRowTile extends StatelessWidget {
  final String iconPath;
  final String infoText;
  const infoRowTile({
    super.key,
    required this.iconPath,
    required this.infoText,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: Utils.windowWidth(context) * 0.9,
          child: ListTile(
            leading: SvgWrapper(
              assetPath: iconPath,
              color: AppColors.primaryColor,
            ),
            title: CustomText(
              text: infoText,
              color: AppColors.grayColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: "Gilroy-SemiBold",
            ),
          ),
        ),
        SizedBox(width: Utils.windowWidth(context) * 0.85, child: Divider()),
      ],
    );
  }
}
