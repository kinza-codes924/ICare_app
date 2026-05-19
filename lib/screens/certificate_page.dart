import 'package:flutter/material.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

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
    _load();
  }

  Future<void> _load() async {
    try {
      final cert = await _lms.generateCertificate(
        courseId: widget.courseId,
        studentId: widget.studentId,
      );
      if (mounted) setState(() { _certificate = cert; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        leading: const CustomBackButton(color: Colors.white),
        title: const Text('Certificate of Completion',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Download coming soon')),
            ),
            icon: const Icon(Icons.download_rounded, color: Colors.white),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildCertificate(),
                      const SizedBox(height: 20),
                      _buildActions(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCertificate() {
    final verificationCode = _certificate?['verificationCode']?.toString() ?? '';
    final verificationUrl = verificationCode.isNotEmpty
        ? 'https://icare-app-ten.vercel.app/verify?code=$verificationCode'
        : 'https://icare-app-ten.vercel.app/verify';
    final certId = _certificate?['certificateId']?.toString() ?? '';
    final studentName = _certificate?['studentName'] ?? 'Student Name';
    final instructorName = _certificate?['instructorName'] ?? 'Instructor';
    final issuedAt = _certificate?['issuedAt'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1A237E), width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          // ── Gold top border ──
          Container(height: 8, decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
            gradient: LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFFFD700), Color(0xFFB8860B)]),
          )),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                // ── TOP ROW: RMR | Iqra Uni | iCare ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // LEFT — RMR Health Solutions
                    SizedBox(
                      width: 80,
                      height: 44,
                      child: Image.asset(
                        'assets/images/health.jpeg',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Text('RM Health\nSolutions',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF0036BC))),
                      ),
                    ),

                    // CENTER — Iqra University
                    SizedBox(
                      width: 120,
                      height: 44,
                      child: Image.asset(
                        'assets/LOGO-IU-01-2048x495-1.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Text('Iqra University',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1A237E))),
                      ),
                    ),

                    // RIGHT — iCare (once only)
                    SizedBox(
                      width: 80,
                      height: 44,
                      child: Image.asset(
                        'assets/Asset 1.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Text('iCare',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryColor)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                Divider(color: const Color(0xFFB8860B), thickness: 1.5),
                const SizedBox(height: 10),

                // ── TITLE ──
                const Text('CERTIFICATE OF COMPLETION',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1A237E), letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Container(height: 2, width: 60,
                    decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFFFD700)]))),
                const SizedBox(height: 16),

                // ── BODY TEXT ──
                const Text('This is to certify that',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
                const SizedBox(height: 8),
                Text(studentName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                const SizedBox(height: 8),
                const Text('has successfully completed the course',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                Text(widget.courseName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A237E))),
                const SizedBox(height: 10),
                Text('Issued on ${_fmt(issuedAt)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),

                const SizedBox(height: 16),
                Divider(color: const Color(0xFFB8860B), thickness: 1.5),
                const SizedBox(height: 14),

                // ── BOTTOM ROW: QR | Signatures ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // QR Code bottom-left
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: QrImageView(
                            data: verificationUrl,
                            version: QrVersions.auto,
                            size: 72,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(certId.isNotEmpty ? certId.substring(0, certId.length.clamp(0, 12)) : '',
                            style: const TextStyle(fontSize: 8, color: Color(0xFF94A3B8))),
                        const Text('Scan to verify',
                            style: TextStyle(fontSize: 8, color: Color(0xFF94A3B8))),
                      ],
                    ),

                    const Spacer(),

                    // Three signatures
                    _signature('Verified by\nInstructor', instructorName),
                    const SizedBox(width: 12),
                    _signature('Iqra University\nRegistrar', 'Registrar'),
                    const SizedBox(width: 12),
                    _signature('iCare\nAdministrator', 'Administrator'),
                  ],
                ),
              ],
            ),
          ),

          // ── Gold bottom border ──
          Container(height: 8, decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
            gradient: LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFFFD700), Color(0xFFB8860B)]),
          )),
        ],
      ),
    );
  }

  Widget _signature(String role, String name) {
    return Column(
      children: [
        Container(width: 70, height: 1.5, color: const Color(0xFF475569)),
        const SizedBox(height: 4),
        Text(name,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            textAlign: TextAlign.center),
        Text(role,
            style: const TextStyle(fontSize: 8, color: Color(0xFF64748B)),
            textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Share feature coming soon')),
            ),
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
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Download feature coming soon')),
            ),
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
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text('Certificate load failed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.red.shade700)),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () { setState(() { _loading = true; _error = null; }); _load(); },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(dynamic d) {
    if (d == null) return DateFormat('MMM d, yyyy').format(DateTime.now());
    try { return DateFormat('MMM d, yyyy').format(DateTime.parse(d.toString())); }
    catch (_) { return DateFormat('MMM d, yyyy').format(DateTime.now()); }
  }
}
