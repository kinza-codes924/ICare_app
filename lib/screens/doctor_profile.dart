import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/screens/create_profile.dart';
import 'package:icare/screens/rating_n_reviews.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_record_card.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/svg_wrapper.dart';
import 'package:image_picker/image_picker.dart';

class DoctorProfile extends StatelessWidget {
  const DoctorProfile({super.key, this.fromViewProfile = false});
  final bool fromViewProfile;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: CustomText(
          text: fromViewProfile ? "Doctor's Profile".tr() : "Create Profile".tr(),
          fontSize: 16.78,
          fontFamily: "Gilroy-Bold",
          fontWeight: FontWeight.w400,
          color: AppColors.primary500,
        ),
        leading: CustomBackButton(),
        automaticallyImplyLeading: false,
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => CreateProfile(isEdit: true),
                ),
              );
            },
            child: fromViewProfile
                ? Icon(Icons.favorite, color: AppColors.darkGray400)
                : SvgWrapper(assetPath: ImagePaths.edit),
          ),
          SizedBox(width: ScallingConfig.scale(20)),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              ProfilePicker(onPickImage: (pickedImage) {}),
              SizedBox(height: ScallingConfig.scale(15)),
              CustomText(
                text: "Aaron Smith",
                color: AppColors.primary500,
                fontFamily: "Gilroy-Bold",
                fontWeight: FontWeight.w400,
                fontSize: 16.78,
              ),
              SizedBox(height: ScallingConfig.scale(40)),
              CustomText(
                text: "16 Years",
                color: AppColors.primary500,
                fontFamily: "Gilroy-Bold",
                fontWeight: FontWeight.w400,
                fontSize: 34.78,
              ),
              CustomText(
                text: "Experience".tr(),
                color: AppColors.primary500,
                fontFamily: "Gilroy-Regular",
                // fontWeight: FontWeight.w400,
                fontSize: 16.78,
              ),
              SizedBox(height: ScallingConfig.scale(10)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomRecordCard(
                    color: AppColors.primaryColor,
                    icon: SvgWrapper(assetPath: ImagePaths.profile2User),
                    number: "150",
                    label: fromViewProfile ? "Patients".tr() : "Total Consultations".tr(),
                  ),
                  SizedBox(width: ScallingConfig.scale(15)),
                  CustomRecordCard(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (ctx) => RatingAndReviews()),
                      );
                    },
                    icon: SvgWrapper(assetPath: ImagePaths.star),
                    number: "4.9",
                    label: "Ratings".tr(),
                  ),
                ],
              ),

              SizedBox(height: ScallingConfig.scale(10)),
              SizedBox(
                width: Utils.windowWidth(context) * 0.9,
                child: ListTile(
                  leading: SvgWrapper(assetPath: ImagePaths.sms),
                  title: CustomText(
                    text: "lisamarie@gmail.com",
                    color: AppColors.grayColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Gilroy-SemiBold",
                  ),
                ),
              ),
              SizedBox(
                width: Utils.windowWidth(context) * 0.85,
                child: Divider(),
              ),
              SizedBox(height: ScallingConfig.scale(1)),
              SizedBox(
                width: Utils.windowWidth(context) * 0.9,
                child: ListTile(
                  leading: SvgWrapper(
                    assetPath: ImagePaths.calll,
                    color: AppColors.primaryColor,
                  ),
                  title: CustomText(
                    text: "+1 234 567 8963",
                    color: AppColors.grayColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Gilroy-SemiBold",
                  ),
                ),
              ),
              SizedBox(
                width: Utils.windowWidth(context) * 0.85,
                child: Divider(),
              ),

              SizedBox(height: ScallingConfig.scale(5)),
              CustomText(
                text: "Bio:".tr(),
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary500,
                fontFamily: "Gilroy-Bold",
                width: Utils.windowWidth(context) * 0.85,
              ),
              SizedBox(height: ScallingConfig.scale(5)),
              CustomText(
                text:
                    "Lorem ipsum dolor sit amet consectetur adipiscing elit  nascetur at leo accumsan, odio habitanLorem ipsum dolor.",
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.grayColor,
                maxLines: 3,
                fontFamily: "Gilroy-Medium",
                width: Utils.windowWidth(context) * 0.85,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// class ImagePicker extends StatefulWidget {
//   const ImagePicker({super.key, required this.onPickImage});
//    final void Function(File pickedImage) onPickImage;

//   @override
//   State<ImagePicker> createState() => _ImagePickerState();
// }

// class _ImagePickerState extends State<ImagePicker> {
//   @override
//   Widget build(BuildContext context) {
//     return const Placeholder();
//   }
// }

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
                title: Text('Gallery'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text('Camera'.tr()),
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: Utils.windowWidth(context) * 0.3,
          height: Utils.windowHeight(context) * 0.15,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            border: Border.all(width: 2, color: AppColors.themeDarkGrey),
            borderRadius: BorderRadius.circular(35),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: SizedBox(
              width: Utils.windowWidth(context) * 0.26,
              height: Utils.windowHeight(context) * 0.1,
              child: _selectedImage != null
                  ? Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  : Image.asset(
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
        //     onPressed: _showImageSourcePicker,
        //     padding: EdgeInsets.zero,
        //     width: ScallingConfig.scale(30),
        //     height: ScallingConfig.scale(25),
        //     borderRadius: 10,
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
