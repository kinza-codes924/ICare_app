import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:icare/services/api_service.dart';
import 'package:icare/utils/theme.dart';

/// 4 Pre-designed certificate templates
/// Used by instructors to assign template to a course
/// Student name auto-fills when viewing/downloading

enum CertificateTemplate {
  classic,   // Blue & gold, formal
  modern,    // Purple gradient, minimal
  elegant,   // Dark, professional
  achievement, // Green, vibrant
}

extension CertificateTemplateExt on CertificateTemplate {
  String get name {
    switch (this) {
      case CertificateTemplate.classic:     return 'Classic';
      case CertificateTemplate.modern:      return 'Modern';
      case CertificateTemplate.elegant:     return 'Elegant';
      case CertificateTemplate.achievement: return 'Achievement';
    }
  }

  Color get primaryColor {
    switch (this) {
      case CertificateTemplate.classic:     return const Color(0xFF1A3A8F);
      case CertificateTemplate.modern:      return const Color(0xFF7C3AED);
      case CertificateTemplate.elegant:     return const Color(0xFF1E293B);
      case CertificateTemplate.achievement: return const Color(0xFF059669);
    }
  }

  Color get accentColor {
    switch (this) {
      case CertificateTemplate.classic:     return const Color(0xFFD4AF37);
      case CertificateTemplate.modern:      return const Color(0xFFEC4899);
      case CertificateTemplate.elegant:     return const Color(0xFFD4AF37);
      case CertificateTemplate.achievement: return const Color(0xFFF59E0B);
    }
  }

  IconData get icon {
    switch (this) {
      case CertificateTemplate.classic:     return Icons.workspace_premium_rounded;
      case CertificateTemplate.modern:      return Icons.star_rounded;
      case CertificateTemplate.elegant:     return Icons.military_tech_rounded;
      case CertificateTemplate.achievement: return Icons.emoji_events_rounded;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEMPLATE SELECTOR (for instructors)
// ─────────────────────────────────────────────────────────────────────────────

class CertificateTemplateSelectorScreen extends StatefulWidget {
  final String courseTitle;
  final String instructorName;
  final String? courseId;
  final CertificateTemplate? currentTemplate;
  final bool certificateReleased;
  final Function(CertificateTemplate) onSelect;

  const CertificateTemplateSelectorScreen({
    super.key,
    required this.courseTitle,
    required this.instructorName,
    this.courseId,
    this.currentTemplate,
    this.certificateReleased = false,
    required this.onSelect,
  });

  @override
  State<CertificateTemplateSelectorScreen> createState() => _CertificateTemplateSelectorScreenState();
}

class _CertificateTemplateSelectorScreenState extends State<CertificateTemplateSelectorScreen> {
  CertificateTemplate _selected = CertificateTemplate.classic;
  bool _released = false;
  bool _savingRelease = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentTemplate ?? CertificateTemplate.classic;
    _released = widget.certificateReleased;
  }

  Future<void> _toggleRelease(bool value) async {
    setState(() { _released = value; _savingRelease = true; });
    try {
      if (widget.courseId != null) {
        final res = await ApiService().put('/courses/${widget.courseId}/certificate/release', {
          'released': value,
          'template': _selected.name,
        });
        // Update state from server response to keep in sync
        if (res.data is Map && res.data['course'] != null) {
          final serverReleased = res.data['course']['certificateReleased'] == true;
          if (mounted) setState(() => _released = serverReleased);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(value ? '✅ Certificate released to students' : '🔒 Certificate locked'),
            backgroundColor: value ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ));
        }
      }
    } catch (e) {
      // Revert on error
      if (mounted) setState(() => _released = !value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
      }
    }
    if (mounted) setState(() => _savingRelease = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Certificate Templates', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A))),
        actions: [
          TextButton(
            onPressed: () {
              widget.onSelect(_selected);
              Navigator.pop(context);
            },
            child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryColor)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose a design for your course certificate. Students will receive this design with their name when they complete the course.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 16),

            // ── Certificate Release Toggle ────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _released ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _released ? const Color(0xFF10B981) : const Color(0xFFF59E0B), width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(_released ? Icons.lock_open_rounded : Icons.lock_rounded,
                      color: _released ? const Color(0xFF10B981) : const Color(0xFFF59E0B), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _released ? 'Certificate Released' : 'Certificate Locked',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14,
                              color: _released ? const Color(0xFF065F46) : const Color(0xFF92400E)),
                        ),
                        Text(
                          _released
                              ? 'Students who complete this course can download their certificate.'
                              : 'Students cannot download certificate until you release it.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  _savingRelease
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : Switch(
                          value: _released,
                          onChanged: _toggleRelease,
                          activeThumbColor: const Color(0xFF10B981),
                        ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ...CertificateTemplate.values.map((t) => _templateCard(t)),
          ],
        ),
      ),
    );
  }

  Widget _templateCard(CertificateTemplate t) {
    final isSelected = _selected == t;
    return GestureDetector(
      onTap: () => setState(() => _selected = t),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? t.primaryColor : const Color(0xFFE2E8F0),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected ? [BoxShadow(color: t.primaryColor.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))] : [],
        ),
        child: Column(
          children: [
            // Preview
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: _CertificatePreview(
                template: t,
                studentName: 'Student Name',
                courseTitle: widget.courseTitle,
                instructorName: widget.instructorName,
                compact: true,
              ),
            ),
            // Label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  Icon(t.icon, color: t.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(t.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: t.primaryColor)),
                  const Spacer(),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: t.primaryColor, borderRadius: BorderRadius.circular(20)),
                      child: const Text('Selected', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CERTIFICATE VIEWER — student views/downloads their certificate
// ─────────────────────────────────────────────────────────────────────────────

class LmsCertificateScreen extends StatelessWidget {
  final String studentName;
  final String courseTitle;
  final String instructorName;
  final CertificateTemplate template;
  final DateTime? completionDate;
  final String? enrollmentId; // to mark as completed in backend
  final String? courseId;

  const LmsCertificateScreen({
    super.key,
    required this.studentName,
    required this.courseTitle,
    required this.instructorName,
    this.template = CertificateTemplate.classic,
    this.completionDate,
    this.enrollmentId,
    this.courseId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Your Certificate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            tooltip: 'Download PDF',
            onPressed: () => _downloadPdf(context),
          ),
          IconButton(
            icon: const Icon(Icons.print_rounded, color: Colors.white),
            tooltip: 'Print',
            onPressed: () => _printCertificate(context),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _CertificatePreview(
            template: template,
            studentName: studentName,
            courseTitle: courseTitle,
            instructorName: instructorName,
            completionDate: completionDate,
            compact: false,
          ),
        ),
      ),
    );
  }

  Future<void> _downloadPdf(BuildContext context) async {
    try {
      final bytes = await _generatePdf();
      await Printing.sharePdf(bytes: bytes, filename: 'certificate_${courseTitle.replaceAll(' ', '_')}.pdf');
      // Mark enrollment as completed in backend (saves to My Certificates)
      if (enrollmentId != null && enrollmentId!.isNotEmpty) {
        try {
          await ApiService().put('/students/courses/enrollments/$enrollmentId/complete', {});
        } catch (_) {}
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _printCertificate(BuildContext context) async {
    try {
      final bytes = await _generatePdf();
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'certificate');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();
    final date = DateFormat('MMMM dd, yyyy').format(completionDate ?? DateTime.now());

    // Generate unique certificate ID
    final certId = 'CERT-${DateTime.now().millisecondsSinceEpoch}-${courseId?.substring(0, 6) ?? 'ICARE'}';

    // Load logos
    pw.ImageProvider? icareLogoImg;
    pw.ImageProvider? rmrLogoImg;
    pw.ImageProvider? iqraLogoImg;
    try {
      final bytes = await rootBundle.load('assets/Asset 1.png');
      icareLogoImg = pw.MemoryImage(bytes.buffer.asUint8List());
      // For now, use same logo for all - client can replace with actual logos
      rmrLogoImg = icareLogoImg;
      iqraLogoImg = icareLogoImg;
    } catch (_) {}

    // Generate QR code for verification
    // QR code will contain verification URL: https://icare.app/verify-certificate/{certId}
    final qrData = 'https://icare.app/verify-certificate/$certId';
    pw.ImageProvider? qrCodeImg;
    try {
      // Generate QR code using barcode package
      final qrCode = pw.BarcodeWidget(
        barcode: pw.Barcode.qrCode(),
        data: qrData,
        width: 80,
        height: 80,
      );
    } catch (_) {}

    final t = template;
    PdfColor primary;
    PdfColor accent;
    PdfColor bg;

    switch (t) {
      case CertificateTemplate.classic:
        primary = const PdfColor.fromInt(0xFF1A3A8F);
        accent = const PdfColor.fromInt(0xFFD4AF37);
        bg = const PdfColor.fromInt(0xFFF8F4E8);
        break;
      case CertificateTemplate.modern:
        primary = const PdfColor.fromInt(0xFF7C3AED);
        accent = const PdfColor.fromInt(0xFFEC4899);
        bg = const PdfColor.fromInt(0xFFF5F3FF);
        break;
      case CertificateTemplate.elegant:
        primary = const PdfColor.fromInt(0xFF1E293B);
        accent = const PdfColor.fromInt(0xFFD4AF37);
        bg = const PdfColor.fromInt(0xFFF8FAFC);
        break;
      case CertificateTemplate.achievement:
        primary = const PdfColor.fromInt(0xFF059669);
        accent = const PdfColor.fromInt(0xFFF59E0B);
        bg = const PdfColor.fromInt(0xFFF0FDF4);
        break;
    }

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: pw.EdgeInsets.zero,
      build: (ctx) => pw.Container(
        decoration: pw.BoxDecoration(color: bg),
        child: pw.Stack(
          children: [
            // Border decoration
            pw.Positioned.fill(
              child: pw.Container(
                margin: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: accent, width: 3),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
              ),
            ),
            pw.Positioned.fill(
              child: pw.Container(
                margin: const pw.EdgeInsets.all(26),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: primary, width: 1),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
              ),
            ),

            // Top logos row: RMR (left), Iqra (center), iCare (right)
            pw.Positioned(
              top: 35,
              left: 40,
              right: 40,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // RMR Solution logo (left)
                  if (rmrLogoImg != null)
                    pw.Container(width: 60, height: 60, child: pw.Image(rmrLogoImg))
                  else
                    pw.Container(width: 60, height: 60),

                  // Iqra University logo (center)
                  if (iqraLogoImg != null)
                    pw.Container(width: 70, height: 70, child: pw.Image(iqraLogoImg))
                  else
                    pw.Container(width: 70, height: 70),

                  // iCare logo (right)
                  if (icareLogoImg != null)
                    pw.Container(width: 60, height: 60, child: pw.Image(icareLogoImg))
                  else
                    pw.Container(width: 60, height: 60),
                ],
              ),
            ),

            // QR Code (left side)
            pw.Positioned(
              left: 40,
              top: 120,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: qrData,
                    width: 70,
                    height: 70,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('Scan to verify', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                ],
              ),
            ),

            // Main content
            pw.Center(
              child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 100, vertical: 40),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.SizedBox(height: 40),
                    pw.Text('Certificate of Completion', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: primary, letterSpacing: 2)),
                    pw.SizedBox(height: 10),
                    pw.Container(height: 2, width: 200, color: accent),
                    pw.SizedBox(height: 16),
                    pw.Text('This is to certify that', style: pw.TextStyle(fontSize: 13, color: PdfColors.grey700)),
                    pw.SizedBox(height: 12),
                    // Student name — big, prominent
                    pw.Text(studentName, style: pw.TextStyle(fontSize: 36, fontWeight: pw.FontWeight.bold, color: accent)),
                    pw.SizedBox(height: 10),
                    pw.Text('has successfully completed the course', style: pw.TextStyle(fontSize: 13, color: PdfColors.grey700)),
                    pw.SizedBox(height: 12),
                    pw.Text(courseTitle, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: primary)),
                    pw.SizedBox(height: 20),
                    pw.Text('Date of Completion: $date', style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                    pw.SizedBox(height: 30),

                    // Digital signatures row
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                      children: [
                        // Instructor signature
                        pw.Column(
                          children: [
                            pw.Container(height: 1, width: 100, color: PdfColors.grey500),
                            pw.SizedBox(height: 4),
                            pw.Text(instructorName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primary)),
                            pw.Text('Instructor', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                            pw.Text('Digital Signature', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500, fontStyle: pw.FontStyle.italic)),
                          ],
                        ),
                        // Iqra University Registrar
                        pw.Column(
                          children: [
                            pw.Container(height: 1, width: 100, color: PdfColors.grey500),
                            pw.SizedBox(height: 4),
                            pw.Text('Registrar', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primary)),
                            pw.Text('Iqra University', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                            pw.Text('Digital Signature', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500, fontStyle: pw.FontStyle.italic)),
                          ],
                        ),
                        // iCare Administrator
                        pw.Column(
                          children: [
                            pw.Container(height: 1, width: 100, color: PdfColors.grey500),
                            pw.SizedBox(height: 4),
                            pw.Text('Administrator', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primary)),
                            pw.Text('iCare Virtual Hospital', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                            pw.Text('Digital Signature', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500, fontStyle: pw.FontStyle.italic)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Certificate ID (bottom right)
            pw.Positioned(
              bottom: 30,
              right: 40,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Certificate ID', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  pw.Text(certId, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primary)),
                ],
              ),
            ),
          ],
        ),
      ),
    ));

    return pdf.save();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Certificate Preview Widget (Flutter UI — not PDF)
// ─────────────────────────────────────────────────────────────────────────────

class _CertificatePreview extends StatelessWidget {
  final CertificateTemplate template;
  final String studentName;
  final String courseTitle;
  final String instructorName;
  final DateTime? completionDate;
  final bool compact;

  const _CertificatePreview({
    required this.template,
    required this.studentName,
    required this.courseTitle,
    required this.instructorName,
    this.completionDate,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMMM dd, yyyy').format(completionDate ?? DateTime.now());
    final t = template;
    final double scale = compact ? 0.6 : 1.0;

    return Transform.scale(
      scale: scale,
      alignment: Alignment.topCenter,
      child: Container(
        width: 700,
        height: compact ? 280 : 460,
        decoration: BoxDecoration(
          color: _bgColor(t),
          border: Border.all(color: t.accentColor, width: 4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            // Inner border
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: t.primaryColor.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            // Content
            Padding(
              padding: EdgeInsets.all(compact ? 16 : 36),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Logo Row: RMR | Iqra University | iCare ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Image.asset('assets/images/health.jpeg',
                          height: compact ? 24 : 40, fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => Text('RMR', style: TextStyle(fontSize: compact ? 8 : 10, fontWeight: FontWeight.w700, color: const Color(0xFF0036BC)))),
                      Image.asset('assets/LOGO-IU-01-2048x495-1.png',
                          height: compact ? 24 : 40, width: compact ? 90 : 140, fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => Text('Iqra University', style: TextStyle(fontSize: compact ? 8 : 11, fontWeight: FontWeight.w700, color: t.primaryColor))),
                      Image.asset('assets/Asset 1.png',
                          height: compact ? 24 : 40, fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => Text('iCare', style: TextStyle(fontSize: compact ? 8 : 10, fontWeight: FontWeight.w700, color: t.primaryColor))),
                    ],
                  ),
                  SizedBox(height: compact ? 6 : 12),
                  Container(height: 1.5, color: t.accentColor),
                  SizedBox(height: compact ? 5 : 10),
                  Text('CERTIFICATE OF COMPLETION',
                      style: TextStyle(fontSize: compact ? 11 : 19, fontWeight: FontWeight.w900, color: t.primaryColor, letterSpacing: 1.5)),
                  SizedBox(height: compact ? 3 : 6),
                  Container(height: 2, width: 80, color: t.accentColor),
                  SizedBox(height: compact ? 5 : 12),
                  Text('This certifies that', style: TextStyle(fontSize: compact ? 8 : 12, color: const Color(0xFF64748B), fontStyle: FontStyle.italic)),
                  SizedBox(height: compact ? 3 : 6),
                  Text(studentName,
                      style: TextStyle(fontSize: compact ? 15 : 26, fontWeight: FontWeight.w900, color: t.primaryColor)),
                  SizedBox(height: compact ? 3 : 6),
                  Text('has successfully completed', style: TextStyle(fontSize: compact ? 8 : 12, color: const Color(0xFF64748B))),
                  SizedBox(height: compact ? 3 : 6),
                  Text(courseTitle,
                      style: TextStyle(fontSize: compact ? 10 : 16, fontWeight: FontWeight.w800, color: t.accentColor),
                      textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (!compact) ...[
                    const SizedBox(height: 20),
                    Container(height: 1, color: t.accentColor.withValues(alpha: 0.4)),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // QR placeholder
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(border: Border.all(color: t.primaryColor.withValues(alpha: 0.3))),
                          child: const Icon(Icons.qr_code_2_rounded, size: 48, color: Color(0xFF94A3B8)),
                        ),
                        const Spacer(),
                        _sigBlock(t, 'Instructor', instructorName),
                        const SizedBox(width: 24),
                        _sigBlock(t, 'IU Registrar', 'Registrar'),
                        const SizedBox(width: 24),
                        _sigBlock(t, 'iCare Admin', 'Administrator'),
                      ],
                    ),
                  ],
                  if (compact) ...[
                    const SizedBox(height: 6),
                    Text(date, style: TextStyle(fontSize: 8, color: const Color(0xFF94A3B8))),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sigBlock(CertificateTemplate t, String role, String name) {
    return Column(children: [
      Container(width: 70, height: 1.5, color: t.primaryColor.withValues(alpha: 0.4)),
      const SizedBox(height: 3),
      Text(name, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: t.primaryColor)),
      Text(role, style: const TextStyle(fontSize: 8, color: Color(0xFF94A3B8))),
    ]);
  }

  Color _bgColor(CertificateTemplate t) {
    switch (t) {
      case CertificateTemplate.classic:     return const Color(0xFFFFFBF0);
      case CertificateTemplate.modern:      return const Color(0xFFF5F3FF);
      case CertificateTemplate.elegant:     return const Color(0xFFF8FAFC);
      case CertificateTemplate.achievement: return const Color(0xFFF0FDF4);
    }
  }
}
