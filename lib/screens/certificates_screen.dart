import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icare/providers/auth_provider.dart';
import 'package:icare/screens/certificate_templates_screen.dart';
import 'package:icare/services/course_service.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';

class CertificatesScreen extends ConsumerStatefulWidget {
  const CertificatesScreen({super.key});

  @override
  ConsumerState<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends ConsumerState<CertificatesScreen> {
  final CourseService _courseService = CourseService();
  bool _isLoading = true;
  List<dynamic> _certificates = [];

  @override
  void initState() {
    super.initState();
    _loadCertificates();
  }

  Future<void> _loadCertificates() async {
    setState(() => _isLoading = true);
    try {
      final certificates = await _courseService.myCertificates();
      setState(() {
        _certificates = certificates;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Unable to load data. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: const Text(
          'My Certificates',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _certificates.isEmpty
          ? _buildEmptyState()
          : _buildCertificatesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.workspace_premium_outlined,
              size: 80,
              color: Color(0xFFCBD5E1),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Certificates Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Complete courses and pass quizzes to earn your professional certificates.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificatesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _certificates.length,
      itemBuilder: (context, index) {
        final certificate = _certificates[index];
        final course = certificate['course'];
        final createdAtStr = certificate['createdAt']?.toString();
        final issuedAt = createdAtStr != null
            ? DateTime.tryParse(createdAtStr.contains('Z') || createdAtStr.contains('+') ? createdAtStr : '${createdAtStr}Z')?.toLocal()
            : null;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _viewCertificate(certificate),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.workspace_premium,
                        color: Color(0xFFD97706),
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course?['title'] ?? 'Course Certificate',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            issuedAt != null
                                ? 'Issued on ${DateFormat('MMM dd, yyyy').format(issuedAt)}'
                                : 'Issued on unknown date',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _viewCertificate(dynamic certificate) {
    final user = ref.read(authProvider).user;
    final studentName = certificate['studentName']?.toString().isNotEmpty == true
        ? certificate['studentName'].toString()
        : user?.name ?? 'Student';
    final courseTitle = certificate['courseName']?.toString() ??
        certificate['course']?['title']?.toString() ?? 'Course';
    final instructorName = certificate['instructorName']?.toString() ?? 'Instructor';
    final enrollmentId = certificate['enrollmentId']?.toString() ?? '';
    final courseId = certificate['courseId']?.toString() ??
        certificate['course']?['_id']?.toString() ?? '';
    final completionDate = certificate['completionDate'] != null
        ? DateTime.tryParse(certificate['completionDate'].toString())
        : certificate['issuedAt'] != null
            ? DateTime.tryParse(certificate['issuedAt'].toString())
            : null;

    CertificateTemplate template;
    switch ((certificate['template']?.toString() ?? '').toLowerCase()) {
      case 'modern':      template = CertificateTemplate.modern; break;
      case 'elegant':     template = CertificateTemplate.elegant; break;
      case 'achievement': template = CertificateTemplate.achievement; break;
      default:            template = CertificateTemplate.classic;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LmsCertificateScreen(
          studentName: studentName,
          courseTitle: courseTitle,
          instructorName: instructorName,
          template: template,
          completionDate: completionDate,
          enrollmentId: enrollmentId,
          courseId: courseId,
        ),
      ),
    );
  }
}
