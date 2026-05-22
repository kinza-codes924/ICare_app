import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final cert = _certificate!;
    final studentName = cert['studentName'] ?? 'Student';
    final instructorName = cert['instructorName'] ?? 'Instructor';
    final certId = cert['certificateId']?.toString() ?? '';
    final verificationCode = cert['verificationCode']?.toString() ?? '';
    final verificationUrl = verificationCode.isNotEmpty
        ? 'https://icare-app-ten.vercel.app/verify?code=$verificationCode'
        : 'https://icare-app-ten.vercel.app/verify';
    final issuedDate = _fmt(cert['issuedAt']);

    // Load fonts
    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    final italicFont = await PdfGoogleFonts.notoSansItalic();

    // Load logos
    pw.ImageProvider? icareImg;
    pw.ImageProvider? iqraImg;
    pw.ImageProvider? rmrImg;
    try {
      final icareBytes = await rootBundle.load('assets/Asset 1.png');
      icareImg = pw.MemoryImage(icareBytes.buffer.asUint8List());
    } catch (_) {}
    try {
      final iqraBytes = await rootBundle.load('assets/LOGO-IU-01-2048x495-1.png');
      iqraImg = pw.MemoryImage(iqraBytes.buffer.asUint8List());
    } catch (_) {}
    try {
      final rmrBytes = await rootBundle.load('assets/images/health.jpeg');
      rmrImg = pw.MemoryImage(rmrBytes.buffer.asUint8List());
    } catch (_) {}

    final gold = PdfColor.fromHex('#B8860B');
    final navy = PdfColor.fromHex('#1A237E');
    final darkText = PdfColor.fromHex('#0F172A');
    final greyText = PdfColor.fromHex('#64748B');

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(0),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: navy, width: 3),
            ),
            child: pw.Column(
              children: [
                // Gold top bar
                pw.Container(height: 10, color: gold),

                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(40, 24, 40, 24),
                  child: pw.Column(
                    children: [
                      // Logo row
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          rmrImg != null
                              ? pw.Image(rmrImg, width: 90, height: 40, fit: pw.BoxFit.contain)
                              : pw.Text('RM Health Solutions', style: pw.TextStyle(font: boldFont, fontSize: 10)),
                          iqraImg != null
                              ? pw.Image(iqraImg, width: 130, height: 40, fit: pw.BoxFit.contain)
                              : pw.Text('Iqra University', style: pw.TextStyle(font: boldFont, fontSize: 12)),
                          icareImg != null
                              ? pw.Image(icareImg, width: 90, height: 40, fit: pw.BoxFit.contain)
                              : pw.Text('iCare', style: pw.TextStyle(font: boldFont, fontSize: 14, color: navy)),
                        ],
                      ),

                      pw.SizedBox(height: 14),
                      pw.Divider(color: gold, thickness: 1.5),
                      pw.SizedBox(height: 16),

                      // Title
                      pw.Text('CERTIFICATE OF COMPLETION',
                          style: pw.TextStyle(font: boldFont, fontSize: 22, color: navy, letterSpacing: 2)),
                      pw.SizedBox(height: 6),
                      pw.Container(width: 60, height: 2, color: gold),
                      pw.SizedBox(height: 20),

                      // Body
                      pw.Text('This is to certify that',
                          style: pw.TextStyle(font: italicFont, fontSize: 12, color: greyText)),
                      pw.SizedBox(height: 8),
                      pw.Text(studentName,
                          style: pw.TextStyle(font: boldFont, fontSize: 28, color: darkText)),
                      pw.SizedBox(height: 8),
                      pw.Text('has successfully completed the course',
                          style: pw.TextStyle(font: regularFont, fontSize: 12, color: greyText)),
                      pw.SizedBox(height: 6),
                      pw.Text(widget.courseName,
                          style: pw.TextStyle(font: boldFont, fontSize: 18, color: navy),
                          textAlign: pw.TextAlign.center),
                      pw.SizedBox(height: 10),
                      pw.Text('Issued on $issuedDate',
                          style: pw.TextStyle(font: regularFont, fontSize: 11, color: greyText)),

                      pw.SizedBox(height: 20),
                      pw.Divider(color: gold, thickness: 1.5),
                      pw.SizedBox(height: 16),

                      // Bottom row — QR + signatures
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          // QR Code
                          pw.Column(children: [
                            pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: verificationUrl,
                              width: 70,
                              height: 70,
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(certId.isNotEmpty ? certId.substring(0, certId.length.clamp(0, 14)) : '',
                                style: pw.TextStyle(font: regularFont, fontSize: 7, color: greyText)),
                            pw.Text('Scan to verify',
                                style: pw.TextStyle(font: italicFont, fontSize: 8, color: greyText)),
                          ]),

                          pw.Spacer(),

                          // Signatures
                          _pdfSignature(boldFont, regularFont, 'Verified by Instructor', instructorName),
                          pw.SizedBox(width: 30),
                          _pdfSignature(boldFont, regularFont, 'Iqra University Registrar', 'Registrar'),
                          pw.SizedBox(width: 30),
                          _pdfSignature(boldFont, regularFont, 'iCare Administrator', 'Administrator'),
                        ],
                      ),
                    ],
                  ),
                ),

                // Gold bottom bar
                pw.Container(height: 10, color: gold),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _pdfSignature(pw.Font boldFont, pw.Font regularFont, String role, String name) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(width: 80, height: 1, color: PdfColor.fromHex('#475569')),
        pw.SizedBox(height: 4),
        pw.Text(name, style: pw.TextStyle(font: boldFont, fontSize: 9, color: PdfColor.fromHex('#0F172A'))),
        pw.Text(role, style: pw.TextStyle(font: regularFont, fontSize: 8, color: PdfColor.fromHex('#64748B'))),
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
