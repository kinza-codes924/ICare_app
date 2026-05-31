import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/custom_text_input.dart';
import 'package:icare/widgets/svg_wrapper.dart';
import 'package:image_picker/image_picker.dart';

class CreateProfile extends StatefulWidget {
  const CreateProfile({super.key, this.isEdit = false});
  final bool isEdit;

  @override
  State<CreateProfile> createState() => _CreateProfileState();
}

class _CreateProfileState extends State<CreateProfile> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final TextEditingController qualificationController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController cnicController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width > 900) {
      return _WebCreateProfile(
        isEdit: widget.isEdit,
        formKey: _formKey,
        nameController: nameController,
        emailController: emailController,
        phoneController: phoneController,
        bioController: bioController,
        qualificationController: qualificationController,
        ageController: ageController,
        cnicController: cnicController,
        heightController: heightController,
        weightController: weightController,
        addressController: addressController,
        onSuccess: () => _showSuccessModal(context),
      );
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bgColor,
        leading: CustomBackButton(color: AppColors.primaryColor),
        automaticallyImplyLeading: false,
        title: CustomText(
          text: widget.isEdit ? "Edit Profile" : "Create Profile",
          fontSize: 16.78,
          fontFamily: "Gilroy-Bold",
          fontWeight: FontWeight.w400,
          letterSpacing: -0.31,
          lineHeight: 1.0,
          color: AppColors.primary500,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ScallingConfig.moderateScale(20),
              vertical: ScallingConfig.moderateScale(20),
            ),
            child: Column(
              children: [
                const SizedBox(height: 20),
                ProfilePicker(onPickImage: (pickedImage) => {}),
                const SizedBox(height: 30),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      CustomInputField(
                        hintText: "Name",
                        leadingIcon: const Icon(
                          Icons.person_outline,
                          color: AppColors.lightGrey200,
                        ),
                        bgColor: AppColors.bgColor,
                        borderRadius: 30,
                        borderColor: AppColors.lightGrey200,
                        controller: nameController,
                      ),
                      CustomInputField(
                        hintText: "Email",
                        leadingIcon: const Icon(
                          Icons.email_outlined,
                          color: AppColors.lightGrey200,
                        ),
                        bgColor: AppColors.bgColor,
                        borderRadius: 30,
                        borderColor: AppColors.lightGrey200,
                        controller: emailController,
                      ),
                      CustomInputField(
                        hintText: "Phone Number",
                        leadingIcon: const Icon(
                          Icons.phone_outlined,
                          color: AppColors.lightGrey200,
                        ),
                        bgColor: AppColors.bgColor,
                        borderRadius: 30,
                        borderColor: AppColors.lightGrey200,
                        controller: phoneController,
                      ),
                      CustomInputField(
                        hintText: "Type your bio here....",
                        leadingIcon: const Icon(
                          Icons.text_snippet_outlined,
                          color: AppColors.lightGrey200,
                        ),
                        bgColor: AppColors.bgColor,
                        borderRadius: 30,
                        borderColor: AppColors.lightGrey200,
                        controller: bioController,
                      ),
                      CustomInputField(
                        hintText: "Add Qualification",
                        leadingIcon: const Icon(
                          Icons.school_outlined,
                          color: AppColors.lightGrey200,
                        ),
                        bgColor: AppColors.bgColor,
                        borderRadius: 30,
                        borderColor: AppColors.lightGrey200,
                        controller: qualificationController,
                      ),
                      CustomInputField(
                        hintText: "Age",
                        leadingIcon: const Icon(
                          Icons.calendar_today_outlined,
                          color: AppColors.lightGrey200,
                        ),
                        bgColor: AppColors.bgColor,
                        borderRadius: 30,
                        borderColor: AppColors.lightGrey200,
                        controller: ageController,
                      ),
                      CustomInputField(
                        hintText: "CNIC Number (e.g. 35201-1234567-1)",
                        leadingIcon: const Icon(
                          Icons.credit_card_outlined,
                          color: AppColors.lightGrey200,
                        ),
                        bgColor: AppColors.bgColor,
                        borderRadius: 30,
                        borderColor: AppColors.lightGrey200,
                        controller: cnicController,
                      ),
                      CustomInputField(
                        hintText: "Height (e.g. 5'7\")",
                        leadingIcon: const Icon(
                          Icons.height_rounded,
                          color: AppColors.lightGrey200,
                        ),
                        bgColor: AppColors.bgColor,
                        borderRadius: 30,
                        borderColor: AppColors.lightGrey200,
                        controller: heightController,
                      ),
                      CustomInputField(
                        hintText: "Weight (kg)",
                        leadingIcon: const Icon(
                          Icons.monitor_weight_outlined,
                          color: AppColors.lightGrey200,
                        ),
                        bgColor: AppColors.bgColor,
                        borderRadius: 30,
                        borderColor: AppColors.lightGrey200,
                        controller: weightController,
                      ),
                      CustomInputField(
                        hintText: "Address",
                        leadingIcon: const Icon(
                          Icons.location_on_outlined,
                          color: AppColors.lightGrey200,
                        ),
                        bgColor: AppColors.bgColor,
                        borderRadius: 30,
                        borderColor: AppColors.lightGrey200,
                        controller: addressController,
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              _showSuccessModal(context);
                            }
                          },
                          child: Text(
                            widget.isEdit ? "Update Profile" : "Create Profile",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WebCreateProfile extends StatelessWidget {
  final bool isEdit;
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController bioController;
  final TextEditingController qualificationController;
  final TextEditingController ageController;
  final TextEditingController cnicController;
  final TextEditingController heightController;
  final TextEditingController weightController;
  final TextEditingController addressController;
  final VoidCallback onSuccess;

  const _WebCreateProfile({
    required this.isEdit,
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.bioController,
    required this.qualificationController,
    required this.ageController,
    required this.cnicController,
    required this.heightController,
    required this.weightController,
    required this.addressController,
    required this.onSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Row(
        children: [
          // ── Left Side: Aesthetic Panel (Premium Visual) ──
          Container(
            width: 450,
            color: AppColors.primaryColor,
            child: Stack(
              children: [
                Positioned(
                  top: -100,
                  left: -100,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -50,
                  right: -50,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(60),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CustomBackButton(color: Colors.white),
                      const Spacer(),
                      const CustomText(
                        text: "Complete Your\nProfessional Identity",
                        fontSize: 38,
                        fontFamily: "Gilroy-Bold",
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "Your profile is your digital business card in the ICare platform. Fill out the details to get started with patients.",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 18,
                          height: 1.6,
                        ),
                      ),
                      const Spacer(flex: 2),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Right Side: Scrollable Form ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(80),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEdit ? "Update Your Info" : "Profile Setup",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryColor,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "Personal Details",
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E293B),
                                    fontFamily: "Gilroy-Bold",
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          ProfilePicker(onPickImage: (f) {}),
                        ],
                      ),
                      const SizedBox(height: 60),
                      Form(
                        key: formKey,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInput(
                                    label: "Full Name",
                                    controller: nameController,
                                    icon: Icons.person_outline_rounded,
                                    hint: "Enter your legal name",
                                  ),
                                ),
                                const SizedBox(width: 32),
                                Expanded(
                                  child: _buildInput(
                                    label: "Official Email",
                                    controller: emailController,
                                    icon: Icons.alternate_email_rounded,
                                    hint: "example@icare.com",
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInput(
                                    label: "Phone Number",
                                    controller: phoneController,
                                    icon: Icons.phone_android_rounded,
                                    hint: "+1 (555) 000-0000",
                                  ),
                                ),
                                const SizedBox(width: 32),
                                Expanded(
                                  child: _buildInput(
                                    label: "Age",
                                    controller: ageController,
                                    icon: Icons.calendar_today_rounded,
                                    hint: "24",
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInput(
                                    label: "CNIC Number",
                                    controller: cnicController,
                                    icon: Icons.credit_card_outlined,
                                    hint: "35201-1234567-1",
                                  ),
                                ),
                                const SizedBox(width: 32),
                                Expanded(
                                  child: _buildInput(
                                    label: "Address",
                                    controller: addressController,
                                    icon: Icons.location_on_outlined,
                                    hint: "Enter your address",
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInput(
                                    label: "Height",
                                    controller: heightController,
                                    icon: Icons.height_rounded,
                                    hint: "e.g. 5'7\"",
                                  ),
                                ),
                                const SizedBox(width: 32),
                                Expanded(
                                  child: _buildInput(
                                    label: "Weight (kg)",
                                    controller: weightController,
                                    icon: Icons.monitor_weight_outlined,
                                    hint: "e.g. 70",
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            _buildInput(
                              label: "Bio & Description",
                              controller: bioController,
                              icon: Icons.description_outlined,
                              hint: "Tell us a bit about yourself...",
                              maxLines: 4,
                            ),
                            const SizedBox(height: 32),
                            _buildInput(
                              label: "Qualifications",
                              controller: qualificationController,
                              icon: Icons.school_outlined,
                              hint: "MBBS, MD, etc.",
                            ),
                            const SizedBox(height: 60),
                            SizedBox(
                              width: double.infinity,
                              height: 64,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  if (formKey.currentState!.validate()) {
                                    onSuccess();
                                  }
                                },
                                child: Text(
                                  isEdit
                                      ? "Update Changes"
                                      : "Create My Profile",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                    fontFamily: "Gilroy-Bold",
                                  ),
                                ),
                              ),
                            ),
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

  Widget _buildInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            prefixIcon: Icon(icon, color: AppColors.primaryColor, size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primaryColor,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ProfilePicker extends StatefulWidget {
  const ProfilePicker({super.key, required this.onPickImage});

  final void Function(File pickedImage) onPickImage;

  @override
  State<ProfilePicker> createState() => _ProfilePickerState();
}

class _ProfilePickerState extends State<ProfilePicker> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final pickedImage = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 600,
    );

    if (pickedImage == null) return;

    final imageFile = File(pickedImage.path);

    setState(() {
      _selectedImage = imageFile;
    });

    widget.onPickImage(imageFile);
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;
    final double size = isDesktop ? 120 : Utils.windowWidth(context) * 0.3;
    final double height = isDesktop ? 120 : Utils.windowHeight(context) * 0.15;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: height,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            border: Border.all(width: 2, color: AppColors.primaryColor),
            borderRadius: BorderRadius.circular(35),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Container(
              color: AppColors.primaryColor,
              width: double.infinity,
              height: double.infinity,
              child: _selectedImage != null
                  ? Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  : Center(
                      child: const Icon(
                        Icons.person_outline,
                        color: Colors.white,
                        size: 45,
                      ),
                    ),
            ),
          ),
        ),

        Positioned(
          right: ScallingConfig.scale(-5),
          bottom: ScallingConfig.scale(-5),
          child: CustomButton(
            onPressed: _showImageSourcePicker,
            padding: EdgeInsets.zero,
            width: ScallingConfig.scale(30),
            height: ScallingConfig.scale(25),
            borderRadius: 10,
            bgColor: AppColors.secondaryColor,
            leadingIcon: SvgWrapper(
              width: ScallingConfig.scale(20),
              assetPath: ImagePaths.camera,
            ),
          ),
        ),
      ],
    );
  }
}

void _showSuccessModal(BuildContext ctx) {
  showDialog(
    context: ctx,
    // barrierDismissible: false,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 70,
                width: 70,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              const Text(
                "Successful",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "You have complete your profile setup successfully.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                  },
                  // onPressed: () {
                  // Navigator.pop(context); // Close modal
                  //   Navigator.pop(context); // Go back to login screen
                  // },
                  child: const Text(
                    "Go Back",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
