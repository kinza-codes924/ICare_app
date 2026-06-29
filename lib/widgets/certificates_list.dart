import 'package:flutter/material.dart';
import 'package:icare/services/course_service.dart';
import 'package:icare/utils/imagePaths.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/svg_wrapper.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/screens/view_certificate.dart';

class CertificatesList extends StatefulWidget {
  const CertificatesList({super.key});

  @override
  State<CertificatesList> createState() => _CertificatesListState();
}

class _CertificatesListState extends State<CertificatesList> {
  final CourseService _courseService = CourseService();
  List<dynamic> _certificates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCertificates();
  }

  Future<void> _fetchCertificates() async {
    try {
      final data = await _courseService.myCertificates();
      if (mounted) {
        setState(() {
          _certificates = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching certificates list: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_certificates.isEmpty) {
      return const Center(child: Text("No completed programs found"));
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: Utils.windowHeight(context) * 0.6),
      child: ListView.builder(
        shrinkWrap: false,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: _certificates.length,
        itemBuilder: (ctx, i) {
          final item = _certificates[i] as Map<String, dynamic>;
          // Backend may return title at top level, inside 'course', or 'courseId'
          final courseMap = item['course'] as Map? ?? item['courseId'] as Map? ?? {};
          final resolvedTitle = item['title']?.toString() ??
              item['courseTitle']?.toString() ??
              courseMap['title']?.toString() ??
              courseMap['name']?.toString() ??
              'Completed Program';
          return CertifcateCard(
            certificateData: item,
            courseTitle: resolvedTitle,
            completedSections: '100', // Completed
            totalSections: '100',
            completionPercentage: '100',
          );
        },
      ),
    );
  }
}

class CertifcateCard extends StatelessWidget {
  const CertifcateCard({
    super.key,
    required this.certificateData,
    this.courseTitle,
    this.totalSections,
    this.completedSections,
    this.completionPercentage,
  });

  final Map<String, dynamic> certificateData;
  final String? courseTitle;
  final String? totalSections;
  final String? completedSections;
  final String? completionPercentage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Utils.windowWidth(context) * 0.8,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      margin: const EdgeInsets.only(top: 12),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.lightGrey300),
        boxShadow: [
          BoxShadow(
            blurStyle: BlurStyle.inner,
            spreadRadius: 5,
            blurRadius: 7,
            color: AppColors.lightGrey200.withAlpha(90),
            offset: const Offset(1, 2),
          ),
        ],
        color: AppColors.white50,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgWrapper(assetPath: ImagePaths.success, width: 35),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    text: courseTitle ?? "",
                    fontSize: 14,
                    color: AppColors.themeDarkGrey,
                    fontFamily: "Gilroy-Bold",
                    fontWeight: FontWeight.bold,
                  ),
                  Row(
                    children: [
                      CustomText(
                        text: '${completionPercentage ?? "100"}% Completed',
                        fontSize: 12,
                        color: AppColors.grayColor,
                        fontFamily: "Gilroy-SemiBold",
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: 5),
              CustomText(
                text: "View Milestone",
                underline: true,
                fontSize: 12.99,
                color: AppColors.primary500,
                fontFamily: "Gilroy-Bold",
                fontWeight: FontWeight.bold,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => ViewCertificate(
                        certificateData: certificateData,
                        resolvedTitle: courseTitle,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),
              CustomText(
                text: "Download PDF",
                underline: true,
                fontSize: 12.99,
                color: AppColors.primary500,
                fontFamily: "Gilroy-Bold",
                fontWeight: FontWeight.bold,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => ViewCertificate(
                        certificateData: certificateData,
                        resolvedTitle: courseTitle,
                        autoDownload: true,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
