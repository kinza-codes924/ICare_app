import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:icare/screens/reception_dashboard.dart';
import 'package:icare/services/reception_service.dart';
import 'package:icare/services/api_config.dart';
import 'package:icare/utils/theme.dart';

class ReceptionVisitSummary extends StatefulWidget {
  final String consultationId;
  final String patientName;

  const ReceptionVisitSummary({
    super.key,
    required this.consultationId,
    required this.patientName,
  });

  @override
  State<ReceptionVisitSummary> createState() => _ReceptionVisitSummaryState();
}

class _ReceptionVisitSummaryState extends State<ReceptionVisitSummary> {
  final ReceptionService _service = ReceptionService();
  bool _loading = true;
  String? _prescriptionId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _service.getConsultation(widget.consultationId);
    if (!mounted) return;
    final prescription = result['prescription'] as Map?;
    setState(() {
      _prescriptionId = prescription?['_id']?.toString();
      _loading = false;
    });
  }

  Future<void> _openUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open — please try again')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Visit Complete'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.home_outlined),
          tooltip: 'Back to Front Desk',
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const ReceptionDashboard()),
              (route) => false,
            );
          },
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 56),
                          const SizedBox(height: 12),
                          Text(
                            widget.patientName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          const Text('Visit recorded', style: TextStyle(color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_prescriptionId != null)
                    ElevatedButton.icon(
                      onPressed: () => _openUrl('${ApiConfig.baseUrl}/prescriptions-v2/prescriptions/$_prescriptionId/pdf'),
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Print Prescription'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _openUrl('${ApiConfig.baseUrl}/invoices/reception/${widget.consultationId}/pdf'),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Print Invoice'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const ReceptionDashboard()),
                        (route) => false,
                      );
                    },
                    child: const Text('Back to Front Desk'),
                  ),
                ],
              ),
            ),
    );
  }
}
