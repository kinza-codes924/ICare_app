import 'dart:async';
import 'package:flutter/material.dart';
import 'package:icare/models/enhanced_prescription.dart';
import 'package:icare/services/consultation_service.dart';
import 'package:icare/utils/theme.dart';

// Read-only view of the doctor's in-progress prescription draft, polled
// every 5s to match InConsultationPrescriptionForm's liveSync autosave
// interval (doctor_call_with_prescription_screen.dart). Shown next to the
// video on the receptionist's side of a walk-in call — per client's
// explicit request: "jab doctor fill kare to patient (yahan receptionist)
// ke paas bhi aa jaye... sync sahi se karna". Receptionist never edits
// this, only the doctor's own screen writes the draft.
class ReceptionPrescriptionLivePreview extends StatefulWidget {
  final String consultationId;

  const ReceptionPrescriptionLivePreview({super.key, required this.consultationId});

  @override
  State<ReceptionPrescriptionLivePreview> createState() => _ReceptionPrescriptionLivePreviewState();
}

class _ReceptionPrescriptionLivePreviewState extends State<ReceptionPrescriptionLivePreview> {
  final ConsultationService _consultationService = ConsultationService();
  EnhancedPrescription? _prescription;
  Timer? _pollTimer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await _consultationService.getPrescriptionDraft(widget.consultationId);
      if (!mounted) return;
      setState(() {
        _prescription = result != null ? EnhancedPrescription.fromJson(result) : null;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _hasAnyContent(EnhancedPrescription rx) {
    final soapContent = rx.soapNotes != null && (
      rx.soapNotes!.assessment.trim().isNotEmpty || rx.soapNotes!.plan.trim().isNotEmpty
    );
    return rx.hasMinimumRequiredFields || soapContent;
  }

  @override
  Widget build(BuildContext context) {
    final rx = _prescription;
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Icon(Icons.description_outlined, color: AppColors.primaryColor, size: 18),
                const SizedBox(width: 8),
                const Text('Prescription (live)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                const Spacer(),
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (rx == null || !_hasAnyContent(rx))
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Waiting for the doctor to start writing the prescription…',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (rx.soapNotes != null && rx.soapNotes!.assessment.trim().isNotEmpty)
                            _section('Assessment', rx.soapNotes!.assessment),
                          if (rx.soapNotes != null && rx.soapNotes!.plan.trim().isNotEmpty)
                            _section('Plan', rx.soapNotes!.plan),
                          if (rx.diagnoses.isNotEmpty)
                            _listSection(
                              'Diagnosis',
                              rx.diagnoses.map((d) => '${d.diagnosis} (${d.icd10Code})').toList(),
                            ),
                          if (rx.medicines.isNotEmpty)
                            _listSection(
                              'Medications',
                              rx.medicines.map((m) => '${m.medicineName} — ${m.dose}, ${m.duration}').toList(),
                            ),
                          if (rx.labTests.isNotEmpty)
                            _listSection('Lab Tests', rx.labTests.map((l) => l.testName).toList()),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primaryColor)),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
        ],
      ),
    );
  }

  Widget _listSection(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primaryColor)),
          const SizedBox(height: 6),
          ...items.map((i) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: TextStyle(fontSize: 13)),
                    Expanded(child: Text(i, style: const TextStyle(fontSize: 13, color: Color(0xFF334155)))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
