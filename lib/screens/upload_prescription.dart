import 'dart:io';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:image_picker/image_picker.dart';

class UploadPrescriptionScreen extends StatefulWidget {
  const UploadPrescriptionScreen({super.key});

  @override
  State<UploadPrescriptionScreen> createState() =>
      _UploadPrescriptionScreenState();
}

class _UploadPrescriptionScreenState extends State<UploadPrescriptionScreen> {
  File? _file;
  bool _uploading = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickFile() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        _file = File(picked.path);
        _uploading = true;
      });

      // TODO: Upload to backend API
      // For now, just simulate upload completion
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _uploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: CustomBackButton(),
        automaticallyImplyLeading: false,
        title: CustomText(
          text: "Upload Prescription",
          fontFamily: "Gilroy-Bold",
          letterSpacing: -0.31,
          lineHeight: 1.0,
          fontWeight: FontWeight.bold,
          fontSize: 16.78,
          color: AppColors.primary500,
        ),

        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickFile,
              child: DottedBorder(
                options: RoundedRectDottedBorderOptions(
                  radius: Radius.circular(30),
                  color: AppColors.grayColor,

                  dashPattern: [10, 5],
                  strokeWidth: 2,
                  // padding: EdgeInsets.all(16),
                  // strokeCap: StrokeCap.square
                ),
                child: Container(
                  height: Utils.windowHeight(context) * 0.25,
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: const Text(
                    'Upload Prescription',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ),

            SizedBox(height: ScallingConfig.scale(45)),

            if (_uploading)
              Column(
                children: [
                  LinearProgressIndicator(
                    borderRadius: BorderRadius.circular(20),
                    minHeight: ScallingConfig.scale(30),
                    backgroundColor: Color(0xFFE8EDEE),
                    color: AppColors.themeGreen,
                  ),
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Uploading',
                      style: TextStyle(color: Colors.green),
                    ),
                  ),
                ],
              ),

            if (!_uploading && _file != null)
              Image.file(
                _file!,
                fit: BoxFit.cover,
                width: ScallingConfig.scale(80),

                height: ScallingConfig.scale(80),
              ),

            SizedBox(height: ScallingConfig.scale(80)),

            CustomButton(
              width: Utils.windowWidth(context) * 0.9,
              borderRadius: 40,
              label: "Continue",
              bgColor: AppColors.primaryColor.withAlpha(65),
            ),

            const SizedBox(height: 12),

            CustomButton(
              width: Utils.windowWidth(context) * 0.9,
              borderRadius: 40,
              label: "Previous Prescription",
              bgColor: AppColors.secondaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
