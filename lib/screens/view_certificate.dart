import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_size_matters/flutter_size_matters.dart';
import 'package:icare/utils/utils.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/widgets/custom_text.dart';
import 'package:icare/utils/theme.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ViewCertificate extends StatefulWidget {
  final Map<String, dynamic> certificateData;
  final String? resolvedTitle;
  final bool autoDownload;

  const ViewCertificate({
    super.key,
    required this.certificateData,
    this.resolvedTitle,
    this.autoDownload = false,
  });

  @override
  State<ViewCertificate> createState() => _ViewCertificateState();
}

class _ViewCertificateState extends State<ViewCertificate> {
  bool _downloading = false;

  String get _title {
    if (widget.resolvedTitle != null && widget.resolvedTitle!.isNotEmpty) {
      return widget.resolvedTitle!;
    }
    final courseMap = widget.certificateData['course'] as Map? ??
        widget.certificateData['courseId'] as Map? ??
        {};
    return widget.certificateData['title']?.toString() ??
        widget.certificateData['courseTitle']?.toString() ??
        courseMap['title']?.toString() ??
        courseMap['name']?.toString() ??
        'Health Program';
  }

  String get _dateStr {
    final rawDate = widget.certificateData['completedAt'] ??
        widget.certificateData['createdAt'] ??
        widget.certificateData['date'];
    if (rawDate != null) {
      final dt = DateTime.tryParse(rawDate.toString());
      if (dt != null) return DateFormat('MMMM dd, yyyy').format(dt.toLocal());
    }
    return DateFormat('MMMM dd, yyyy').format(DateTime.now());
  }

  String get _directorName =>
      widget.certificateData['directorName']?.toString() ?? 'iCare Health Board';

  String get _studentName =>
      widget.certificateData['studentName']?.toString() ??
      widget.certificateData['userName']?.toString() ??
      '';

  Future<Uint8List> _buildPdfBytes() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context ctx) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blue900, width: 10),
            ),
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Icon(const pw.IconData(0xe8af), size: 72, color: PdfColors.amber),
                pw.SizedBox(height: 16),
                pw.Text(
                  'CERTIFICATE OF COMPLETION',
                  style: pw.TextStyle(
                    fontSize: 26,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 2,
                    color: PdfColors.blueGrey900,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 24),
                if (_studentName.isNotEmpty) ...[
                  pw.Text('This certifies that',
                      style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey)),
                  pw.SizedBox(height: 8),
                  pw.Text(_studentName,
                      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center),
                  pw.SizedBox(height: 8),
                  pw.Text('has successfully completed',
                      style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey)),
                ] else
                  pw.Text('This certifies that you have successfully completed',
                      style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey)),
                pw.SizedBox(height: 16),
                pw.Text(
                  _title,
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 40),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Date Issued',
                            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey)),
                        pw.SizedBox(height: 4),
                        pw.Text(_dateStr,
                            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Authorized By',
                            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey)),
                        pw.SizedBox(height: 4),
                        pw.Text(_directorName,
                            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
    return Uint8List.fromList(await pdf.save());
  }

  Future<void> _downloadPdf() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final bytes = await _buildPdfBytes();
      final safeName = _title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final fileName = 'certificate_$safeName.pdf';

      if (kIsWeb) {
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: fileName,
        );
      } else {
        // sharePdf opens the system share/save sheet on Android & iOS
        await Printing.sharePdf(bytes: bytes, filename: fileName);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Certificate ready — save or share from the menu'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.autoDownload) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _downloadPdf());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const CustomBackButton(),
        backgroundColor: Colors.white,
        elevation: 0,
        title: CustomText(
          text: "My Certificate",
          fontWeight: FontWeight.bold,
          fontSize: 18,
          fontFamily: "Gilroy-Bold",
          color: AppColors.primary500,
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              SizedBox(height: ScallingConfig.scale(30)),
              // Certificate card
              Container(
                width: Utils.windowWidth(context) * 0.9,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1E40AF), width: 6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.workspace_premium_rounded,
                      size: 72,
                      color: Color(0xFFEAB308),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "CERTIFICATE OF COMPLETION",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: Color(0xFF0F172A),
                        fontFamily: "Gilroy-Bold",
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (_studentName.isNotEmpty) ...[
                      const Text(
                        "This certifies that",
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _studentName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          fontFamily: "Gilroy-Bold",
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "has successfully completed",
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        textAlign: TextAlign.center,
                      ),
                    ] else
                      const Text(
                        "This certifies that you have successfully completed",
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 12),
                    Text(
                      _title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryColor,
                        fontFamily: "Gilroy-Bold",
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Date Issued",
                                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                            const SizedBox(height: 4),
                            Text(_dateStr,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text("Authorized By",
                                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                            const SizedBox(height: 4),
                            Text(_directorName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: ScallingConfig.scale(32)),
              _downloading
                  ? const Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Generating PDF...', style: TextStyle(color: Color(0xFF64748B))),
                      ],
                    )
                  : CustomButton(
                      label: "Download / Share PDF",
                      width: Utils.windowWidth(context) * 0.9,
                      borderRadius: 40,
                      onPressed: _downloadPdf,
                    ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
