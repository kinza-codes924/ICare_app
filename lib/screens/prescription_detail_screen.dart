import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icare/screens/pharmacies.dart';
import 'package:icare/screens/laboratories.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Full PDF-style prescription display screen.
///
/// [prescription] shape (from consultation/medical-record endpoint):
///   patientId: { name, age, gender, mrNumber } or populated object
///   doctorId:  { name, pmdcLicense, phone } or populated object
///   diagnoses: List of { code, description } or Strings
///   medicines: List of { name, dosage, frequency, duration, instructions }
///   labTests:  List of { name, testName, urgency, notes } or Strings
///   chiefComplaints: String
///   doctorNotes: String
///   referralFollowUp: { date, specialty, reason } or String
///   createdAt: ISO date string
class PrescriptionDetailScreen extends StatelessWidget {
  final Map<String, dynamic> prescription;

  const PrescriptionDetailScreen({super.key, required this.prescription});

  // ── Data extraction helpers ────────────────────────────────────────────

  Map<String, dynamic> get _patient {
    final p = prescription['patientId'] ?? prescription['patient'] ?? {};
    if (p is Map) return Map<String, dynamic>.from(p);
    return {};
  }

  Map<String, dynamic> get _doctor {
    final d = prescription['doctorId'] ?? prescription['doctor'] ?? {};
    if (d is Map) return Map<String, dynamic>.from(d);
    return {};
  }

  String get _patientName =>
      _patient['name'] ?? _patient['username'] ?? prescription['patientName'] ?? 'Patient';

  String get _patientAge {
    final age = _patient['age'] ?? prescription['patientAge'];
    return age != null ? '$age yrs' : '';
  }

  String get _patientGender =>
      _capitalize(_patient['gender']?.toString() ?? prescription['patientGender']?.toString() ?? '');

  String get _patientMrNumber {
    final mr = _patient['mrNumber'] ?? _patient['MRNumber'] ?? prescription['mrNumber'];
    if (mr != null) return mr.toString();
    final id = _patient['_id']?.toString() ?? _patient['id']?.toString() ?? '';
    if (id.length >= 6) return 'MR-${id.substring(id.length - 6).toUpperCase()}';
    return '';
  }

  String get _doctorName {
    final name = _doctor['name'] ?? _doctor['username'] ?? prescription['doctorName'] ?? 'Doctor';
    return name.toString();
  }

  String get _doctorPmdc =>
      _doctor['pmdcLicense']?.toString() ??
      _doctor['pmdc']?.toString() ??
      prescription['pmdcLicense']?.toString() ??
      '';

  String get _doctorPhone =>
      _doctor['phone']?.toString() ??
      _doctor['phoneNumber']?.toString() ??
      prescription['doctorPhone']?.toString() ??
      '';

  String get _chiefComplaints =>
      prescription['chiefComplaints']?.toString() ??
      prescription['complaints']?.toString() ??
      prescription['chiefComplaint']?.toString() ??
      '';

  List<dynamic> get _diagnoses =>
      (prescription['diagnoses'] as List?) ??
      (prescription['diagnosis'] is List ? prescription['diagnosis'] as List : []) ;

  List<dynamic> get _medicines =>
      (prescription['medicines'] as List?) ??
      (prescription['prescription'] is Map
          ? (prescription['prescription']['medicines'] as List?) ?? []
          : []);

  List<dynamic> get _labTests =>
      (prescription['labTests'] as List?) ??
      (prescription['prescription'] is Map
          ? (prescription['prescription']['labTests'] as List?) ?? []
          : []);

  String get _doctorNotes =>
      prescription['doctorNotes']?.toString() ??
      prescription['notes']?.toString() ??
      '';

  Map<String, dynamic>? get _followUp {
    final f = prescription['referralFollowUp'] ?? prescription['followUp'];
    if (f is Map) return Map<String, dynamic>.from(f);
    return null;
  }

  String get _followUpDate {
    final f = _followUp;
    if (f != null) {
      final dateStr = f['date']?.toString() ?? f['followUpDate']?.toString() ?? '';
      if (dateStr.isNotEmpty) {
        try {
          return DateFormat('MMMM dd, yyyy').format(DateTime.parse(dateStr));
        } catch (_) {
          return dateStr;
        }
      }
    }
    final days = prescription['followUpDays'];
    final months = prescription['followUpMonths'];
    final dateStr = prescription['followUpDate']?.toString() ?? '';
    if (dateStr.isNotEmpty) {
      try {
        return DateFormat('MMMM dd, yyyy').format(DateTime.parse(dateStr));
      } catch (_) {}
    }
    if (days != null && days != 0) return 'In $days days';
    if (months != null && months != 0) return 'In $months months';
    return '';
  }

  String get _followUpSpecialty {
    final f = _followUp;
    if (f != null) return f['specialty']?.toString() ?? '';
    return prescription['referralSpecialty']?.toString() ?? '';
  }

  String get _prescriptionDate {
    final dateStr = prescription['createdAt']?.toString() ?? '';
    if (dateStr.isNotEmpty) {
      try {
        return DateFormat('MMMM dd, yyyy').format(DateTime.parse(dateStr));
      } catch (_) {}
    }
    return DateFormat('MMMM dd, yyyy').format(DateTime.now());
  }

  String get _prescriptionTime {
    final dateStr = prescription['createdAt']?.toString() ?? '';
    if (dateStr.isNotEmpty) {
      try {
        return DateFormat('hh:mm a').format(DateTime.parse(dateStr));
      } catch (_) {}
    }
    return '';
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final horizontalPad = isDesktop ? 80.0 : 16.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        leading: const CustomBackButton(color: Colors.white),
        title: const Text('Prescription',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: () => _downloadPdf(context),
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            tooltip: 'Download PDF',
          ),
          IconButton(
            onPressed: () => _showShareSheet(context),
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            tooltip: 'Share',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── HEADER ──────────────────────────────────────────
                  _buildHeader(),

                  // ── BODY ────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_chiefComplaints.isNotEmpty) ...[
                          _sectionTitle('Chief Complaints'),
                          const SizedBox(height: 8),
                          _buildChiefComplaints(),
                          const SizedBox(height: 20),
                          const Divider(height: 1),
                          const SizedBox(height: 20),
                        ],

                        if (_diagnoses.isNotEmpty) ...[
                          _sectionTitle('Diagnosis'),
                          const SizedBox(height: 10),
                          _buildDiagnoses(),
                          const SizedBox(height: 20),
                          const Divider(height: 1),
                          const SizedBox(height: 20),
                        ],

                        if (_medicines.isNotEmpty) ...[
                          _sectionTitle('Rx  (Medications)', icon: Icons.medication_rounded),
                          const SizedBox(height: 12),
                          _buildMedicines(),
                          const SizedBox(height: 20),
                          const Divider(height: 1),
                          const SizedBox(height: 20),
                        ],

                        if (_labTests.isNotEmpty) ...[
                          _sectionTitle('Lab Tests', icon: Icons.biotech_rounded),
                          const SizedBox(height: 12),
                          _buildLabTests(),
                          const SizedBox(height: 20),
                          const Divider(height: 1),
                          const SizedBox(height: 20),
                        ],

                        if (_doctorNotes.isNotEmpty) ...[
                          _sectionTitle('Doctor\'s Notes'),
                          const SizedBox(height: 8),
                          _buildDoctorNotes(),
                          const SizedBox(height: 20),
                          const Divider(height: 1),
                          const SizedBox(height: 20),
                        ],

                        if (_followUpDate.isNotEmpty || _followUpSpecialty.isNotEmpty) ...[
                          _sectionTitle('Follow-up'),
                          const SizedBox(height: 10),
                          _buildFollowUp(),
                          const SizedBox(height: 20),
                        ],

                        // Signature area
                        _buildSignatureArea(),
                      ],
                    ),
                  ),

                  // ── FOOTER BUTTONS ───────────────────────────────────
                  _buildFooterButtons(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── HEADER ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryColor, Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // iCare logo row + date/time
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // iCare logo image
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Image.asset(
                  'assets/Asset 1.png',
                  height: 36,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_hospital_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 6),
                      Text('iCare', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('iCare Telemedicine Platform',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                    Text('RM Health Solutions (Private) Limited',
                        style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
              // Date
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_prescriptionDate,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                  if (_prescriptionTime.isNotEmpty)
                    Text(_prescriptionTime,
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Patient + Doctor info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildPatientInfo()),
              const SizedBox(width: 16),
              Container(width: 1, height: 80, color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(width: 16),
              Expanded(child: _buildDoctorInfo()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPatientInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PATIENT',
            style: TextStyle(
                color: Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5)),
        const SizedBox(height: 6),
        Text(_patientName,
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Row(
          children: [
            if (_patientAge.isNotEmpty) ...[
              Text(_patientAge,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(width: 6),
              Container(width: 3, height: 3, decoration: const BoxDecoration(color: Colors.white54, shape: BoxShape.circle)),
              const SizedBox(width: 6),
            ],
            if (_patientGender.isNotEmpty)
              Text(_patientGender,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        if (_patientMrNumber.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(_patientMrNumber,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
          ),
        ],
      ],
    );
  }

  Widget _buildDoctorInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('DOCTOR',
            style: TextStyle(
                color: Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5)),
        const SizedBox(height: 6),
        Text('Dr. $_doctorName',
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
        if (_doctorPmdc.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.badge_rounded, size: 12, color: Colors.white70),
              const SizedBox(width: 4),
              Text('PMDC: $_doctorPmdc',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
        if (_doctorPhone.isNotEmpty) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              const Icon(Icons.phone_rounded, size: 12, color: Colors.white70),
              const SizedBox(width: 4),
              Text(_doctorPhone,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ],
    );
  }

  // ── SECTION TITLE ────────────────────────────────────────────────────────

  Widget _sectionTitle(String title, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: AppColors.primaryColor),
          const SizedBox(width: 6),
        ],
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: AppColors.primaryColor,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  // ── CHIEF COMPLAINTS ─────────────────────────────────────────────────────

  Widget _buildChiefComplaints() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Text(_chiefComplaints,
          style: const TextStyle(
              fontSize: 14, color: Color(0xFF374151), height: 1.5)),
    );
  }

  // ── DIAGNOSES ────────────────────────────────────────────────────────────

  Widget _buildDiagnoses() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _diagnoses.map((d) {
        String code = '';
        String desc = '';
        if (d is Map) {
          code = d['code']?.toString() ?? d['icdCode']?.toString() ?? '';
          desc = d['description']?.toString() ??
              d['desc']?.toString() ??
              d['name']?.toString() ??
              d.toString();
        } else {
          desc = d.toString();
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFCA5A5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (code.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(code,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5)),
                ),
                const SizedBox(width: 8),
              ],
              Text(desc,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A))),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── MEDICINES ────────────────────────────────────────────────────────────

  Widget _buildMedicines() {
    return Column(
      children: _medicines.asMap().entries.map((entry) {
        final index = entry.key;
        final m = entry.value;
        if (m is! Map) return _buildSimpleMedLine(m.toString(), index);
        return _buildMedicineRow(m, index);
      }).toList(),
    );
  }

  Widget _buildMedicineRow(Map m, int index) {
    final name = m['name']?.toString() ?? m['medicineName']?.toString() ?? m['medicine']?.toString() ?? 'Medicine';
    final dosage = m['dosage']?.toString() ?? m['dose']?.toString() ?? '';
    final rawFormType = (m['formType'] ?? '').toString().toLowerCase();
    final formTypeLabel = rawFormType == 'capsule' ? 'Capsule' :
                          rawFormType == 'liquid' ? 'Liquid/Syrup' :
                          rawFormType == 'drops' ? 'Drops' :
                          rawFormType == 'injection' ? 'Injection' :
                          rawFormType == 'cream' ? 'Cream' :
                          rawFormType == 'inhaler' ? 'Inhaler' :
                          rawFormType == 'tablet' ? 'Tablet' : '';
    final frequency = m['frequency']?.toString() ?? '';
    final duration = m['duration']?.toString() ?? '';
    final instructions = m['instructions']?.toString() ?? m['notes']?.toString() ?? m['note']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text('${index + 1}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                if (dosage.isNotEmpty) _rxPill('Dose', dosage),
                if (formTypeLabel.isNotEmpty) _rxPill('Form', formTypeLabel),
                if (frequency.isNotEmpty) _rxPill('Frequency', frequency),
                if (duration.isNotEmpty) _rxPill('Duration', duration),
              ],
            ),
          ),
          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 38),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF64748B)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(instructions,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSimpleMedLine(String text, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          Text('${index + 1}. ',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primaryColor)),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }

  Widget _rxPill(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ',
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Text(value,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryColor)),
        ),
      ],
    );
  }

  // ── LAB TESTS ────────────────────────────────────────────────────────────

  Widget _buildLabTests() {
    return Column(
      children: _labTests.map((t) {
        final name = t is Map
            ? (t['name'] ?? t['testName'] ?? t['test'] ?? 'Lab Test').toString()
            : t.toString();
        final urgency = t is Map
            ? (t['urgency'] ?? 'routine').toString().toLowerCase()
            : 'routine';
        final notes = t is Map ? (t['notes'] ?? '').toString() : '';

        // Only show badge for STAT or Urgent — not for routine
        Color? urgencyColor;
        String? urgencyLabel;
        if (urgency == 'stat') {
          urgencyColor = const Color(0xFFEF4444);
          urgencyLabel = 'STAT';
        } else if (urgency == 'urgent') {
          urgencyColor = const Color(0xFFF59E0B);
          urgencyLabel = 'Urgent';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFDDD6FE)),
          ),
          child: Row(
            children: [
              const Icon(Icons.biotech_rounded, color: Color(0xFF8B5CF6), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A))),
                    if (notes.isNotEmpty)
                      Text(notes,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              if (urgencyLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: urgencyColor!.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: urgencyColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(urgencyLabel,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: urgencyColor)),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── DOCTOR NOTES ─────────────────────────────────────────────────────────

  Widget _buildDoctorNotes() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Text(_doctorNotes,
          style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF374151),
              height: 1.6)),
    );
  }

  // ── FOLLOW-UP ────────────────────────────────────────────────────────────

  Widget _buildFollowUp() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_repeat_rounded, color: Color(0xFF0EA5E9), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_followUpDate.isNotEmpty)
                  _followUpRow(Icons.calendar_month_rounded, 'Next Visit', _followUpDate),
                if (_followUpSpecialty.isNotEmpty)
                  _followUpRow(Icons.local_hospital_rounded, 'Referred To', _followUpSpecialty),
                if (_followUp != null && _followUp!['reason'] != null)
                  _followUpRow(Icons.notes_rounded, 'Reason', _followUp!['reason'].toString()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _followUpRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF0EA5E9)),
          const SizedBox(width: 6),
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }

  // ── SIGNATURE ────────────────────────────────────────────────────────────

  Widget _buildSignatureArea() {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Left: iCare seal/stamp
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryColor, width: 2),
                color: const Color(0xFFEFF6FF),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/Asset 1.png', height: 32, fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(Icons.local_hospital_rounded, color: AppColors.primaryColor, size: 28)),
                  const SizedBox(height: 4),
                  const Text('iCare', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primaryColor, letterSpacing: 1)),
                ],
              ),
            ),
            const Spacer(),
            // Right: doctor signature block (Aga Khan style)
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Signature line
                Container(
                  width: 180,
                  height: 40,
                  alignment: Alignment.bottomCenter,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Stylized signature text
                      Text(
                        'Dr. $_doctorName',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 180, height: 1, color: const Color(0xFF374151)),
                const SizedBox(height: 6),
                Text('Dr. $_doctorName',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                if (_doctorPmdc.isNotEmpty)
                  Text('PMDC Reg. No. $_doctorPmdc',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                if (_doctorPhone.isNotEmpty)
                  Text(_doctorPhone,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Electronic generation notice (Aga Khan style footer)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF0EA5E9)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'This prescription has been electronically generated and authenticated via iCare — RM Health Solutions (Private) Limited. Valid only for the stated patient and date.',
                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B), height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── FOOTER BUTTONS ───────────────────────────────────────────────────────

  Widget _buildFooterButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          // Order Medicines
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _medicines.isNotEmpty
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PharmaciesScreen(
                            prescribedMedicines: _medicines,
                          ),
                        ),
                      )
                  : null,
              icon: const Icon(Icons.local_pharmacy_rounded, size: 18),
              label: const Text('Order Medicines',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE2E8F0),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Order Lab Tests
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _labTests.isNotEmpty
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LaboratoriesScreen(),
                        ),
                      )
                  : null,
              icon: const Icon(Icons.science_rounded, size: 18),
              label: const Text('Order Lab Tests',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE2E8F0),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── PDF DOWNLOAD ─────────────────────────────────────────────────────────

  Future<void> _downloadPdf(BuildContext context) async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context ctx) => [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('iCare', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                    pw.Text('RM Health Solutions (Private) Limited', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                    pw.Text('iCare Telemedicine Platform', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(_prescriptionDate, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    if (_prescriptionTime.isNotEmpty)
                      pw.Text(_prescriptionTime, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                  ],
                ),
              ],
            ),
            pw.Divider(color: PdfColors.blue800, thickness: 2),
            pw.SizedBox(height: 8),
            // Patient + Doctor
            pw.Row(
              children: [
                pw.Expanded(child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('PATIENT', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey)),
                    pw.Text(_patientName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    if (_patientAge.isNotEmpty) pw.Text('Age: $_patientAge  |  Gender: $_patientGender', style: const pw.TextStyle(fontSize: 10)),
                    if (_patientMrNumber.isNotEmpty) pw.Text('MR#: $_patientMrNumber', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ],
                )),
                pw.SizedBox(width: 20),
                pw.Expanded(child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('DOCTOR', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey)),
                    pw.Text('Dr. $_doctorName', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    if (_doctorPmdc.isNotEmpty) pw.Text('PMDC: $_doctorPmdc', style: const pw.TextStyle(fontSize: 10)),
                    if (_doctorPhone.isNotEmpty) pw.Text('Phone: $_doctorPhone', style: const pw.TextStyle(fontSize: 10)),
                  ],
                )),
              ],
            ),
            pw.SizedBox(height: 16),
            // Diagnosis
            if (_diagnoses.isNotEmpty) ...[
              pw.Text('DIAGNOSIS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              pw.SizedBox(height: 4),
              pw.Wrap(spacing: 8, runSpacing: 4,
                children: _diagnoses.map((d) {
                  final desc = d is Map ? (d['description'] ?? d['desc'] ?? d['name'] ?? d.toString()) : d.toString();
                  return pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(color: PdfColors.red50, border: pw.Border.all(color: PdfColors.red200), borderRadius: pw.BorderRadius.circular(4)),
                    child: pw.Text(desc.toString(), style: const pw.TextStyle(fontSize: 11)),
                  );
                }).toList(),
              ),
              pw.SizedBox(height: 12),
            ],
            // Medicines
            if (_medicines.isNotEmpty) ...[
              pw.Text('Rx  MEDICATIONS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              pw.SizedBox(height: 4),
              ..._medicines.asMap().entries.map((e) {
                final m = e.value;
                final name = m is Map ? (m['name'] ?? m['medicine'] ?? 'Medicine') : m.toString();
                final dose = m is Map ? (m['dosage'] ?? m['dose'] ?? '') : '';
                final freq = m is Map ? (m['frequency'] ?? '') : '';
                final dur = m is Map ? (m['duration'] ?? '') : '';
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 6),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(color: PdfColors.blue50, border: pw.Border.all(color: PdfColors.blue200), borderRadius: pw.BorderRadius.circular(4)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('${e.key + 1}. $name', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      if (dose.isNotEmpty || freq.isNotEmpty || dur.isNotEmpty)
                        pw.Text('${dose.isNotEmpty ? "Dose: $dose  " : ""}${freq.isNotEmpty ? "Frequency: $freq  " : ""}${dur.isNotEmpty ? "Duration: $dur" : ""}',
                            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                );
              }),
              pw.SizedBox(height: 12),
            ],
            // Lab Tests
            if (_labTests.isNotEmpty) ...[
              pw.Text('LAB TESTS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              pw.SizedBox(height: 4),
              ..._labTests.map((t) {
                final name = t is Map ? (t['name'] ?? t['testName'] ?? 'Lab Test') : t.toString();
                return pw.Bullet(text: name.toString(), style: const pw.TextStyle(fontSize: 11));
              }),
              pw.SizedBox(height: 12),
            ],
            // Doctor notes
            if (_doctorNotes.isNotEmpty) ...[
              pw.Text('DOCTOR NOTES', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              pw.SizedBox(height: 4),
              pw.Text(_doctorNotes, style: const pw.TextStyle(fontSize: 11)),
              pw.SizedBox(height: 12),
            ],
            // Follow-up
            if (_followUpDate.isNotEmpty) ...[
              pw.Text('FOLLOW-UP', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              pw.SizedBox(height: 4),
              pw.Text('Next visit: $_followUpDate', style: const pw.TextStyle(fontSize: 11)),
              pw.SizedBox(height: 16),
            ],
            // Signature
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(width: 160, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 4),
                    pw.Text('Dr. $_doctorName', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    if (_doctorPmdc.isNotEmpty) pw.Text('PMDC Reg. No. $_doctorPmdc', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
                    pw.Text('Authorized Signature', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Text(
                'This prescription has been electronically generated and authenticated via iCare — RM Health Solutions (Private) Limited. Valid only for the stated patient and date.',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (_) async => pdf.save(),
        name: 'iCare_Prescription_${_patientName.replaceAll(' ', '_')}_$_prescriptionDate.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  // ── COPY TEXT ────────────────────────────────────────────────────────────

  void _copyPrescriptionText(BuildContext context) {
    final buf = StringBuffer();
    buf.writeln('=== iCare PRESCRIPTION ===');
    buf.writeln('Date: $_prescriptionDate');
    buf.writeln('Patient: $_patientName');
    if (_patientAge.isNotEmpty) buf.writeln('Age/Gender: $_patientAge / $_patientGender');
    if (_patientMrNumber.isNotEmpty) buf.writeln('MR#: $_patientMrNumber');
    buf.writeln('\nDoctor: Dr. $_doctorName');
    if (_doctorPmdc.isNotEmpty) buf.writeln('PMDC: $_doctorPmdc');
    if (_diagnoses.isNotEmpty) {
      buf.writeln('\nDIAGNOSIS:');
      for (final d in _diagnoses) {
        buf.writeln('• ${d is Map ? (d['description'] ?? d['name'] ?? d.toString()) : d}');
      }
    }
    if (_medicines.isNotEmpty) {
      buf.writeln('\nMEDICINES:');
      for (int i = 0; i < _medicines.length; i++) {
        final m = _medicines[i];
        if (m is Map) {
          final name = m['name'] ?? m['medicine'] ?? 'Medicine';
          final dose = m['dosage'] ?? m['dose'] ?? '';
          final freq = m['frequency'] ?? '';
          final dur = m['duration'] ?? '';
          buf.writeln('${i + 1}. $name${dose.isNotEmpty ? ' | $dose' : ''}${freq.isNotEmpty ? ' | $freq' : ''}${dur.isNotEmpty ? ' | $dur' : ''}');
        } else {
          buf.writeln('${i + 1}. $m');
        }
      }
    }
    if (_labTests.isNotEmpty) {
      buf.writeln('\nLAB TESTS:');
      for (final t in _labTests) {
        buf.writeln('• ${t is Map ? (t['name'] ?? t['testName'] ?? t.toString()) : t}');
      }
    }
    if (_doctorNotes.isNotEmpty) {
      buf.writeln('\nDOCTOR NOTES:\n$_doctorNotes');
    }
    if (_followUpDate.isNotEmpty) {
      buf.writeln('\nFOLLOW-UP: $_followUpDate');
    }
    buf.writeln('\n--- Electronically generated via iCare Platform ---');
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Prescription copied to clipboard!')),
    );
  }

  // ── SHARE SHEET ──────────────────────────────────────────────────────────

  void _showShareSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            const Text('Share Prescription',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _shareOption(Icons.copy_rounded, 'Copy Text', const Color(0xFF0036BC), () {
                  Navigator.pop(context);
                  _copyPrescriptionText(context);
                }),
                _shareOption(Icons.download_rounded, 'Download PDF', const Color(0xFF8B5CF6), () {
                  Navigator.pop(context);
                  _downloadPdf(context);
                }),
                _shareOption(Icons.print_rounded, 'Print', const Color(0xFF374151), () {
                  Navigator.pop(context);
                  _downloadPdf(context);
                }),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _shareOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF374151), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
