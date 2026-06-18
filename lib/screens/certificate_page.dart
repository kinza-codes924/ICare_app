import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:icare/services/lms_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
  final GlobalKey _repaintKey = GlobalKey();
  Map<String, dynamic>? _certificate;
  bool _loading = true;
  bool _downloading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final resp = await _lms.generateCertificate(
        courseId: widget.courseId,
        studentId: widget.studentId,
      );
      // Backend wraps the document: { success, certificate: {...} }
      final certData = resp['certificate'];
      final cert = certData is Map
          ? Map<String, dynamic>.from(certData)
          : Map<String, dynamic>.from(resp);
      // Model stores certificateNumber; page displays it as certificateId
      cert['certificateId'] ??= cert['certificateNumber'];
      if (resp['success'] == false) {
        throw Exception(resp['message'] ?? 'Certificate could not be generated');
      }
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
          if (_certificate != null)
            IconButton(
              onPressed: _downloading ? null : _downloadPdf,
              icon: _downloading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download_rounded, color: Colors.white),
              tooltip: 'Download PDF',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _certificate?['approvalStatus'] == 'pending'
                  ? _buildPendingApproval()
                  : _certificate?['approvalStatus'] == 'rejected'
                      ? _buildRejected()
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              RepaintBoundary(key: _repaintKey, child: _buildCertificate()),
                              const SizedBox(height: 20),
                              _buildActions(),
                            ],
                          ),
                        ),
    );
  }

  Widget _buildPendingApproval() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.hourglass_top_rounded, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          const Text('Certificate Pending Approval', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          const Text(
            'Your instructor needs to manually approve your certificate. You\'ll be notified once it\'s approved.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
        ]),
      ),
    );
  }

  Widget _buildRejected() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.cancel_rounded, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Certificate Not Approved', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text(
            _certificate?['approvalNote']?.toString().isNotEmpty == true
                ? 'Reason: ${_certificate!['approvalNote']}'
                : 'Contact your instructor for more information.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
        ]),
      ),
    );
  }

  Widget _buildCertificate() {
    final verificationCode = _certificate?['verificationCode']?.toString() ?? '';
    final verificationUrl = verificationCode.isNotEmpty
        ? 'https://www.icare.com.co/verify?code=$verificationCode'
        : 'https://www.icare.com.co/verify';
    final certId = _certificate?['certificateId']?.toString() ?? '';
    final studentName = _certificate?['studentName'] ?? 'Student Name';
    final instructorName = _certificate?['instructorName'] ?? 'Instructor';
    final issuedAt = _certificate?['issuedAt'];
    final courseName = (_certificate?['courseName']?.toString().isNotEmpty ?? false)
        ? _certificate!['courseName'].toString()
        : widget.courseName;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1A237E), width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 6))],
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
                        errorBuilder: (_, _, _) => const Text('RM Health\nSolutions',
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
                        errorBuilder: (_, _, _) => const Text('Iqra University',
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
                        errorBuilder: (_, _, _) => const Text('iCare',
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
                Text(courseName,
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
                            size: 60,
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
                    const SizedBox(width: 8),
                    _signature('Iqra University\nRegistrar', 'Registrar'),
                    const SizedBox(width: 8),
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
        Container(width: 52, height: 1.5, color: const Color(0xFF475569)),
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
            onPressed: _certificate == null ? null : _shareCertificate,
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
            onPressed: (_certificate == null || _downloading) ? null : _downloadPdf,
            icon: _downloading
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.download_rounded),
            label: Text(_downloading ? 'Generating...' : 'Download PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _downloadPdf() async {
    setState(() => _downloading = true);
    try {
      final pdfBytes = await _generatePdf();
      final fileName = 'iCare_Certificate_${_certificate?['certificateId'] ?? 'cert'}.pdf';
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _shareCertificate() async {
    setState(() => _downloading = true);
    try {
      final pdfBytes = await _generatePdf();
      final fileName = 'iCare_Certificate_${_certificate?['certificateId'] ?? 'cert'}.pdf';
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<Uint8List> _generatePdf() async {
    // Capture the rendered certificate widget as a PNG image.
    // This avoids asset-loading bugs in the pdf package on Flutter web
    // (where rootBundle ByteData views can resolve to the wrong image bytes).
    final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('Certificate not rendered yet. Please wait and try again.');

    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('Failed to capture certificate image.');

    final pngBytes = byteData.buffer.asUint8List();

    final pdf = pw.Document();
    final pdfImage = pw.MemoryImage(pngBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => pw.Image(pdfImage, fit: pw.BoxFit.fill),
      ),
    );

    return pdf.save();
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
