import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/screens/view_course.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/widgets/svg_wrapper.dart';

class CourseCard extends StatelessWidget {
  const CourseCard({
    super.key,
    this.image,
    this.title,
    this.desc,
    this.instructor,
    this.courseData,
  });

  final String? image;
  final String? title;
  final String? desc;
  final String? instructor;
  final Map<String, dynamic>? courseData;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => ViewCourse(courseData: courseData),
          ),
        );
      },
      child: Container(
        width: Utils.windowWidth(context) * 0.4,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.lightGrey300),
          boxShadow: [
            BoxShadow(
              blurStyle: BlurStyle.inner,
              spreadRadius: 5,
              blurRadius: 7,
              color: AppColors.lightGrey200.withAlpha(90),
              offset: Offset(1, 2),
            ),
          ],
          color: AppColors.white50,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildImage(context),
            SizedBox(height: Utils.windowHeight(context) * 0.01),
            CustomText(
              // textAlign: TextAlign.left,
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12),
              text: title ?? courseData?['title'] ?? courseData?['name'] ?? "",
              fontWeight: FontWeight.bold,
              fontSize: ScallingConfig.moderateScale(14),
            ),
            CustomText(
              padding: EdgeInsets.only(left: 12),
              text: desc ?? "",
              maxLines: 3,
              fontSize: ScallingConfig.moderateScale(12),
            ),
            SizedBox(height: Utils.windowHeight(context) * 0.01),
            Row(
              children: [
                SizedBox(width: Utils.windowWidth(context) * 0.02),
                SvgWrapper(assetPath: ImagePaths.instructor),
                SizedBox(width: Utils.windowWidth(context) * 0.02),
                CustomText(text: instructor ?? ""),
              ],
            ),
            SizedBox(height: Utils.windowHeight(context) * 0.02),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    String? rawPath = image ??
        courseData?['thumbnail_url'] ??
        courseData?['thumbnail'] ??
        courseData?['image'];
    String imagePath = (rawPath != null && rawPath.trim().isNotEmpty)
        ? rawPath.trim()
        : ImagePaths.course1;

    // Safety check: if the resolved path is still empty or whitespace, use placeholder
    if (imagePath.isEmpty) imagePath = ImagePaths.course1;

    final bool isNetwork = imagePath.startsWith('http');
    final double height = Utils.windowHeight(context) * 0.15;

    // WEB FIX: Prevent trying to load "assets/" or empty paths as assets
    final bool isValidAsset =
        !isNetwork &&
        imagePath.contains('assets/') &&
        (imagePath.endsWith('.png') ||
            imagePath.endsWith('.jpg') ||
            imagePath.endsWith('.jpeg') ||
            imagePath.endsWith('.svg'));

    if (isNetwork) {
      return Image.network(
        imagePath,
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(height),
      );
    } else if (isValidAsset) {
      return Image.asset(
        imagePath,
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(height),
      );
    } else {
      return _buildPlaceholder(height);
    }
  }

  Widget _buildPlaceholder(double height) {
    return Image.asset(
      ImagePaths.coursePremium,
      width: double.infinity,
      height: height,
      fit: BoxFit.cover,
    );
  }
}
