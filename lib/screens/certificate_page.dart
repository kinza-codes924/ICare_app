import 'package:flutter/material.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

/// Certificate Display Page with QR Code Verification
class CertificatePage extends StatefulWidget {
  final String courseId;
  final String studentId;
  final String courseName;

  const CertificatePage({
    super.key,
    required this.courseId,
    required this.studentId,
    required this.courseName,
  });

  @override
  State<CertificatePage> createState() => _CertificatePageState();
}

class _CertificatePageState extends State<CertificatePage> {
  final LmsService _lms = LmsService();
  Map<String, dynamic>? _certificate;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCertificate();
  }

  Future<void> _loadCertificate() async {
    try {
      final cert = await _lms.generateCertificate(
        courseId: widget.courseId,
        studentId: widget.studentId,
      );
      if (mounted) {
        setState(() {
          _certificate = cert;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        leading: const CustomBackButton(color: Colors.white),
        title: const Text(
          'Certificate of Completion',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_certificate != null)
            IconButton(
              onPressed: () {
                // TODO: Implement download/share functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Download feature coming soon')),
                );
              },
              icon: const Icon(Icons.download_rounded, color: Colors.white),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load certificate',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.red.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _loading = true;
                              _error = null;
                            });
                            _loadCertificate();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Certificate Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Header with Logos
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // iCare Logo
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.school_rounded,
                                    color: AppColors.primaryColor,
                                    size: 32,
                                  ),
                                ),
                                // Additional Logos (RMR, Iqra University)
                                Row(
                                  children: [
                                    _buildLogoPlaceholder('RMR'),
                                    const SizedBox(width: 8),
                                    _buildLogoPlaceholder('IQRA'),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Certificate Title
                            const Text(
                              'CERTIFICATE OF COMPLETION',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primaryColor,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 3,
                              width: 80,
                              decoration: BoxDecoration(
                                color: AppColors.primaryColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Student Name
                            const Text(
                              'This is to certify that',
                              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _certificate?['studentName'] ?? 'Student Name',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),

                            // Course Name
                            const Text(
                              'has successfully completed',
                              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.courseName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),

                            // Issue Date
                            Text(
                              'Issued on ${_formatDate(_certificate?['issuedAt'])}',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 24),

                            // Signatures
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildSignature('Instructor', _certificate?['instructorName']),
                                _buildSignature('Registrar', 'Dr. Registrar'),
                                _buildSignature('Administrator', 'Admin Name'),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // QR Code
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                children: [
                                  if (_certificate?['verificationCode'] != null)
                                    QrImageView(
                                      data: 'https://icare-app-ten.vercel.app/verify?code=${_certificate!['verificationCode']}',
                                      version: QrVersions.auto,
                                      size: 120,
                                      backgroundColor: Colors.white,
                                    ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Certificate ID: ${_certificate?['certificateId'] ?? 'N/A'}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Scan to verify authenticity',
                                    style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                // TODO: Share functionality
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Share feature coming soon')),
                                );
                              },
                              icon: const Icon(Icons.share_rounded),
                              label: const Text('Share'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryColor,
                                side: const BorderSide(color: AppColors.primaryColor),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // TODO: Download functionality
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Download feature coming soon')),
                                );
                              },
                              icon: const Icon(Icons.download_rounded),
                              label: const Text('Download'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildLogoPlaceholder(String text) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildSignature(String role, String? name) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 2,
          color: Colors.grey.shade300,
        ),
        const SizedBox(height: 4),
        Text(
          name ?? role,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
        Text(
          role,
          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return DateFormat('MMM d, yyyy').format(DateTime.now());
    try {
      return DateFormat('MMM d, yyyy').format(DateTime.parse(date.toString()));
    } catch (_) {
      return DateFormat('MMM d, yyyy').format(DateTime.now());
    }
  }
}
