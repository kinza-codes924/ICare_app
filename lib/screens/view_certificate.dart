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

class ViewCertificate extends StatelessWidget {
  final Map<String, dynamic> certificateData;
  const ViewCertificate({super.key, required this.certificateData});

  Future<void> _generateAndDownloadPDF(BuildContext context) async {
    final title = certificateData['title'] ?? 'Health Program Completion';
    final directorName = certificateData['directorName'] ?? 'iCare Health Board';
    final rawDate = certificateData['date'];
    final dateStr = rawDate != null
        ? DateFormat('MMMM dd, yyyy').format(DateTime.tryParse(rawDate) ?? DateTime.now())
        : DateFormat('MMMM dd, yyyy').format(DateTime.now());

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blue, width: 8),
            ),
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Icon(
                  const pw.IconData(0xe838), // star icon
                  size: 80,
                  color: PdfColors.amber,
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'HEALTH PROGRAM COMPLETION',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Text(
                  'This certifies that you have successfully completed',
                  style: const pw.TextStyle(fontSize: 16),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue,
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
                        pw.Text('Date Issued', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
                        pw.SizedBox(height: 4),
                        pw.Text(dateStr, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Authorized By', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
                        pw.SizedBox(height: 4),
                        pw.Text(directorName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
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

    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'certificate_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Certificate downloaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download certificate: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = certificateData['title'] ?? 'Health Program Completion';
    final directorName =
        certificateData['directorName'] ?? 'iCare Health Board';
    final rawDate = certificateData['date'];
    final dateStr = rawDate != null
        ? DateFormat(
            'MMMM dd, yyyy',
          ).format(DateTime.tryParse(rawDate) ?? DateTime.now())
        : DateFormat('MMMM dd, yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const CustomBackButton(),
        backgroundColor: Colors.white,
        elevation: 0,
        title: CustomText(
          text: "Certificate",
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
              // Certificate UI Card
              Container(
                width: Utils.windowWidth(context) * 0.9,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 8),
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
                      size: 64,
                      color: Color(0xFFEAB308),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "HEALTH PROGRAM COMPLETION",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: Color(0xFF0F172A),
                        fontFamily: "Gilroy-Bold",
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "This certifies that you have successfully completed",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                        fontFamily: "Gilroy-Medium",
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryColor,
                        fontFamily: "Gilroy-Bold",
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Date Issued",
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateStr,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              "Authorized By",
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              directorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: ScallingConfig.scale(40)),
              CustomButton(
                label: "Download as PDF",
                width: Utils.windowWidth(context) * 0.9,
                borderRadius: 40,
                onPressed: () => _generateAndDownloadPDF(context),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
